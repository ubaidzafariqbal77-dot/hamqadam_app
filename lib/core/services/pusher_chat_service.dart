// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../../constants/app_constants.dart';
import '../../repositories/bridge_repository.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';

/// Where the realtime socket stands right now.
///
/// The app reads this to decide whether it has to fall back to polling. Every
/// value except [connected] means "events are not arriving, go and fetch".
enum RealtimeStatus {
  /// Nothing has been started yet (no session).
  idle,

  /// Connecting or re-connecting; treat as offline until proven otherwise.
  connecting,

  /// Socket is up AND at least the user channel is subscribed.
  connected,

  /// Socket dropped; a backoff retry is scheduled.
  disconnected,

  /// Realtime cannot work at all for this install — no Pusher key from the
  /// bridge, or `/broadcasting/auth` rejects our bearer token on every known
  /// path. Polling is the only option until something changes, so this is
  /// re-tested on resume and on the slow retry timer rather than being final.
  unavailable,
}

/// Dynamic Pusher configuration fetched from the backend bridge endpoint.
class PusherBridgeConfig {
  const PusherBridgeConfig({
    required this.appKey,
    required this.cluster,
    this.appId = '',
    this.host = '',
    this.port = '443',
    this.scheme = 'https',
  });

  final String appKey;
  final String cluster;
  final String appId;
  final String host;
  final String port;
  final String scheme;

  bool get isValid => appKey.isNotEmpty && appKey != 'YOUR_PUSHER_APP_KEY';

  /// Fallback config using hardcoded values if bridge endpoint fails.
  ///
  /// The cluster is `ap2` because that is what the production website boots
  /// Echo with. It used to be `mt1`, which is Pusher's default rather than this
  /// deployment's — connecting to the wrong cluster fails silently, so a bridge
  /// response with a blank cluster would have left realtime dead with nothing
  /// in the log to say why.
  static const PusherBridgeConfig fallback = PusherBridgeConfig(
    appKey: 'YOUR_PUSHER_APP_KEY',
    cluster: 'ap2',
  );

  @override
  bool operator ==(Object other) =>
      other is PusherBridgeConfig &&
      other.appKey == appKey &&
      other.cluster == cluster &&
      other.host == host &&
      other.port == port &&
      other.scheme == scheme;

  @override
  int get hashCode => Object.hash(appKey, cluster, host, port, scheme);
}

/// Realtime Pusher service for Chat, calls and notification streams.
///
/// Broadcast channels — these must match what Laravel actually publishes on.
/// Every backend event uses `PrivateChannel`, which Pusher exposes with a
/// `private-` prefix, and the website subscribes accordingly
/// (`Echo.private('App.User.{id}')`). The app used to subscribe WITHOUT the
/// prefix, i.e. to public channels nobody publishes to, so no event ever
/// arrived and `onAuthorizer` below was never even called — Pusher only
/// authorizes `private-` / `presence-` channels.
///
/// - `private-App.User.{userId}` — inbox previews, unread counts, and every
///   call signal aimed at this member.
/// - `private-chat-thread.{threadId}` — the open conversation: messages,
///   typing, moderation, and call signals for that thread.
///
/// Event names are the backend's `broadcastAs()` values verbatim:
/// `message-sent`, `message-read`, `message-deleted`, `typing`, and
/// `call-incoming` / `call-accepted` / `call-rejected` / `call-cancelled` /
/// `call-ended` / `call-busy` / `call-missed`.
///
/// ## Why this class is shaped the way it is
///
/// Three things used to make realtime "sometimes work":
///
/// 1. **The bearer token was captured once.** `onAuthorizer` closed over the
///    token read at `init()` time. Start the app logged out, log in, and every
///    private subscription was signed with `null` — a permanent 403 with the
///    socket showing CONNECTED, which is indistinguishable from a quiet server.
///    The token is now read fresh inside the authorizer, on every call.
///
/// 2. **Nothing ever retried.** `init()` set `_initialized = true` and returned
///    early forever, including after it had failed, and a dropped socket was
///    only recorded in a bool. There is now a backoff reconnect loop, and the
///    desired channel set is re-subscribed on every CONNECTED transition.
///
/// 3. **"Subscribed" was recorded before the subscribe succeeded**, so one
///    thrown subscribe wedged the channel as done-and-dusted for the rest of
///    the process. [_live] is only written from `onSubscriptionSucceeded` now.
class PusherChatService {
  PusherChatService({
    required SecureStorageService storage,
    required BridgeRepository bridgeRepository,
  })  : _storage = storage,
        _bridgeRepo = bridgeRepository;

  final SecureStorageService _storage;
  final BridgeRepository _bridgeRepo;
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  /// Channels we want to be on. The socket is told to match this set every
  /// time it (re)connects, which is what makes a reconnect self-healing.
  final Set<String> _desired = <String>{};

  /// Channels Pusher has confirmed. Written only by `onSubscriptionSucceeded`.
  final Set<String> _live = <String>{};

  /// Channels that were confirmed at least once in this socket's lifetime.
  ///
  /// The plugin records a channel in its own register the moment `subscribe`
  /// is dispatched, before authorization has answered — so its register alone
  /// cannot distinguish "the native client is holding this and will re-subscribe
  /// it" from "we asked and were refused". This set is the difference.
  final Set<String> _confirmedOnce = <String>{};

  /// Subscribe calls already in flight, so a burst of `ensure…` calls does not
  /// send the same subscription several times.
  final Set<String> _inFlight = <String>{};

  /// `/broadcasting/auth` candidates, tried in order.
  ///
  /// Laravel registers this route under `web` by default. A deployment that
  /// wants token auth normally exposes it under the `api` group as well, and
  /// which one is live is not something the app can know in advance — so it
  /// tries, remembers the one that answered 200, and keeps using it.
  static final List<String> _authEndpoints = <String>[
    PusherConfig.authEndpoint,
    '${ApiConfig.assetBaseUrl}/api/broadcasting/auth',
    '${ApiConfig.baseUrl}/broadcasting/auth',
  ];
  int _authEndpointIndex = 0;

  /// Consecutive authorizer rejections. Past [_authFailureLimit] we stop
  /// pretending realtime works and let the app fall back to polling.
  int _authFailures = 0;
  static const int _authFailureLimit = 3;

  bool _pluginConfigured = false;
  Future<void>? _starting;
  Timer? _reconnectTimer;
  Timer? _revivalTimer;
  int _reconnectAttempt = 0;

  RealtimeStatus _status = RealtimeStatus.idle;
  PusherBridgeConfig _config = PusherBridgeConfig.fallback;

  final StreamController<RealtimeStatus> _statusController =
      StreamController<RealtimeStatus>.broadcast();

  // Callbacks
  void Function(Map<String, dynamic> data)? onUserEvent;
  void Function(Map<String, dynamic> data)? onThreadMessage;
  void Function(Map<String, dynamic> data)? onThreadTyping;
  void Function(Map<String, dynamic> data)? onThreadUpdated;

  /// Every `call-*` event, with the bare event name (`call-incoming`, …) and
  /// the `{call, rtc}` payload. Kept separate from [onUserEvent] because those
  /// arrive on the same channel and are indistinguishable without the name.
  void Function(String event, Map<String, dynamic> data)? onCallEvent;

  /// Fires once per successful (re)connect, after the channels are re-armed.
  ///
  /// Anything that happened while the socket was down was never broadcast to
  /// us, so this is the app's cue to go and fetch the gap — without it, a
  /// message sent during a two-second network blip stays invisible until
  /// something else happens to trigger a refresh.
  void Function()? onReconnected;

  /// Laravel's `PrivateChannel('App.User.{id}')`.
  static String userChannel(int userId) => 'private-App.User.$userId';

  /// Laravel's `PrivateChannel('chat-thread.{id}')`.
  static String threadChannel(int threadId) => 'private-chat-thread.$threadId';

  // ---- State ---------------------------------------------------------------

  RealtimeStatus get status => _status;
  Stream<RealtimeStatus> get statusStream => _statusController.stream;
  PusherBridgeConfig get config => _config;

  /// True only when events can actually be expected to arrive: socket up AND
  /// the user channel authorized. Callers use this to decide whether they must
  /// poll, so "socket connected but every channel 403" must read as false.
  bool get isConnected =>
      _status == RealtimeStatus.connected && _live.isNotEmpty;

  /// Realtime is known not to work for this install; polling is the only path.
  bool get isUnavailable => _status == RealtimeStatus.unavailable;

  void _setStatus(RealtimeStatus next) {
    if (_status == next) return;
    _status = next;
    AppLogger.i('Realtime status: $next');
    if (!_statusController.isClosed) _statusController.add(next);
  }

  // ---- Start / stop --------------------------------------------------------

  /// Brings the socket up, fetching the bridge config first. Idempotent, and —
  /// unlike the old `init()` — retryable: a failed attempt leaves nothing
  /// latched, so the next call tries again.
  ///
  /// Concurrent callers share one attempt instead of racing two `init()`s
  /// through the plugin.
  Future<void> init() {
    final Future<void>? running = _starting;
    if (running != null) return running;
    if (_pluginConfigured && _status == RealtimeStatus.connected) {
      return Future<void>.value();
    }
    final Future<void> attempt = _start();
    _starting = attempt;
    return attempt.whenComplete(() {
      if (identical(_starting, attempt)) _starting = null;
    });
  }

  Future<void> _start() async {
    // No session means no private channel can ever be authorized; don't burn a
    // connection on it. `ensureConnected` is called again after login.
    if (!_storage.hasToken) {
      AppLogger.i('Realtime: no session yet; deferring connect.');
      _setStatus(RealtimeStatus.idle);
      return;
    }

    _setStatus(RealtimeStatus.connecting);
    await _loadConfig();

    if (!_config.isValid) {
      // Either the bridge is off or `pusher_app_key` is unset in the admin
      // settings. Say so once, loudly, and let the app poll.
      AppLogger.w(
        'Realtime unavailable: the bridge did not return a usable Pusher key. '
        'Check chat_realtime_enabled and pusher_app_key in the admin settings. '
        'Falling back to polling.',
      );
      _setStatus(RealtimeStatus.unavailable);
      _scheduleRevival();
      return;
    }

    try {
      if (!_pluginConfigured) {
        await _pusher.init(
          apiKey: _config.appKey,
          cluster: _config.cluster,
          // A shorter activity timeout than the 120s default: a phone that
          // loses the network silently (walking out of wifi) otherwise sits on
          // a dead socket for two minutes believing it is connected.
          activityTimeout: 30000,
          pongTimeout: 10000,
          maxReconnectionAttempts: 12,
          maxReconnectGapInSeconds: 30,
          onConnectionStateChange: _onConnectionStateChange,
          onError: (String message, int? code, dynamic e) {
            AppLogger.w('Pusher error: $message (code: $code, err: $e)');
          },
          onSubscriptionSucceeded: (String channelName, dynamic data) {
            _inFlight.remove(channelName);
            _live.add(channelName);
            _confirmedOnce.add(channelName);
            _authFailures = 0;
            AppLogger.i('Pusher subscribed to: $channelName');
            // The first confirmed channel is what turns "socket open" into
            // "events will arrive", so re-publish the status to wake up
            // anything waiting to stop polling.
            if (_status == RealtimeStatus.connected && !_statusController.isClosed) {
              _statusController.add(RealtimeStatus.connected);
            }
          },
          onSubscriptionError: (String message, dynamic e) {
            AppLogger.w('Pusher subscription error: $message ($e)');
            // Which channel failed is not reported, so clear the whole
            // in-flight set and let the next flush retry.
            _inFlight.clear();
          },
          onEvent: _handlePusherEvent,
          onAuthorizer: _authorize,
        );
        _pluginConfigured = true;
      }

      await _pusher.connect();
      AppLogger.i(
        '✅ Pusher connecting: key=$_maskedKey cluster=${_config.cluster} '
        'auth=${_authEndpoints[_authEndpointIndex]}',
      );
    } catch (e, st) {
      AppLogger.w('❌ Pusher connect failed: $e\n$st');
      _setStatus(RealtimeStatus.disconnected);
      _scheduleReconnect();
    }
  }

  String get _maskedKey => _config.appKey.length > 8
      ? '${_config.appKey.substring(0, 8)}…'
      : _config.appKey;

  /// Called whenever the app comes back to the foreground, and after login.
  ///
  /// Android and iOS both freeze or kill the socket in the background; on the
  /// way back in, "connected" from before the pause means nothing, so the
  /// plugin's own view of the connection is what decides.
  Future<void> ensureConnected() async {
    if (!_storage.hasToken) return;

    if (_status == RealtimeStatus.unavailable) {
      // Re-test rather than staying dead forever: the admin may have switched
      // the bridge on, or the auth route may have been fixed, since we gave up.
      _reset();
      await init();
      return;
    }

    if (!_pluginConfigured) {
      await init();
      return;
    }

    if (_isSocketUp()) {
      // Connected — but a channel may have been dropped while we were away.
      await _flushDesired();
      return;
    }

    _setStatus(RealtimeStatus.connecting);
    try {
      await _pusher.connect();
    } catch (e) {
      AppLogger.w('Realtime reconnect attempt failed: $e');
      _scheduleReconnect();
    }
  }

  bool _isSocketUp() => _pusher.connectionState.toUpperCase() == 'CONNECTED';

  void _onConnectionStateChange(dynamic currentState, dynamic previousState) {
    final String state = (currentState ?? '').toString().toUpperCase();
    AppLogger.i('Pusher state: $previousState -> $currentState');

    switch (state) {
      case 'CONNECTED':
        _reconnectAttempt = 0;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _setStatus(RealtimeStatus.connected);
        // Re-arm the channels first, then let the app fetch whatever it missed
        // while the socket was down.
        _flushDesired().then((_) => onReconnected?.call());
      case 'CONNECTING':
      case 'RECONNECTING':
        _setStatus(RealtimeStatus.connecting);
      case 'DISCONNECTED':
      case 'DISCONNECTING':
      case 'FAILED':
        // Pusher's own reconnection gives up eventually; ours does not, so the
        // app recovers from a long outage without needing to be restarted.
        _live.clear();
        _inFlight.clear();
        _setStatus(RealtimeStatus.disconnected);
        _scheduleReconnect();
      default:
        AppLogger.d('Unhandled Pusher connection state: $state');
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;
    if (!_storage.hasToken) return;

    // 2s, 4s, 8s, 16s, 30s, 30s… Fast enough that a lift-lobby blackspot is
    // invisible, slow enough that a down server is not hammered.
    final int seconds = <int>[2, 4, 8, 16, 30][
        _reconnectAttempt.clamp(0, 4)];
    _reconnectAttempt++;
    AppLogger.i('Realtime: reconnecting in ${seconds}s (attempt $_reconnectAttempt)');

    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      _reconnectTimer = null;
      if (!_storage.hasToken) return;
      try {
        if (_pluginConfigured) {
          await _pusher.connect();
        } else {
          await init();
        }
      } catch (e) {
        AppLogger.w('Realtime reconnect failed: $e');
        _scheduleReconnect();
      }
    });
  }

  /// Re-tests a realtime setup we had written off, every few minutes.
  void _scheduleRevival() {
    _revivalTimer?.cancel();
    _revivalTimer = Timer(const Duration(minutes: 5), () async {
      _revivalTimer = null;
      if (_status != RealtimeStatus.unavailable) return;
      if (!_storage.hasToken) return;
      AppLogger.i('Realtime: re-testing the setup we gave up on.');
      _reset();
      await init();
    });
  }

  void _reset() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _revivalTimer?.cancel();
    _revivalTimer = null;
    _reconnectAttempt = 0;
    _authFailures = 0;
    _authEndpointIndex = 0;
    _live.clear();
    _confirmedOnce.clear();
    _inFlight.clear();
    _setStatus(RealtimeStatus.idle);
  }

  // ---- Channel authorization ----------------------------------------------

  /// Signs one private-channel subscription.
  ///
  /// The token is read here, not captured at init: it may not have existed when
  /// the socket was built, and it changes on every re-login.
  Future<Map<String, dynamic>> _authorize(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    final String? token = _storage.cachedToken;
    if (token == null || token.isEmpty) {
      AppLogger.w('Realtime auth for $channelName skipped: no bearer token.');
      return <String, dynamic>{'error': 'No session'};
    }

    // Try the remembered endpoint first, then the alternatives — once. A 403
    // here is the single most common reason mobile realtime is dead (the route
    // sits behind `web`/session middleware), and it is worth being sure which
    // path answers before falling back to polling.
    for (int offset = 0; offset < _authEndpoints.length; offset++) {
      final int index = (_authEndpointIndex + offset) % _authEndpoints.length;
      final String endpoint = _authEndpoints[index];
      try {
        final http.Response response = await http
            .post(
              Uri.parse(endpoint),
              headers: <String, String>{
                'Accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': 'Bearer $token',
              },
              body: <String, String>{
                'socket_id': socketId,
                'channel_name': channelName,
              },
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['auth'] != null) {
            if (_authEndpointIndex != index) {
              AppLogger.i('Realtime auth endpoint settled on $endpoint');
              _authEndpointIndex = index;
            }
            _authFailures = 0;
            return decoded;
          }
          AppLogger.w('Realtime auth 200 without an `auth` key from $endpoint.');
          continue;
        }

        AppLogger.w(
          'Realtime auth ${response.statusCode} from $endpoint for $channelName'
          '${response.statusCode == 403 || response.statusCode == 401 ? ' — the route is probably behind session middleware; see backend_patches/README.md' : ''}',
        );
      } catch (e) {
        AppLogger.w('Realtime auth error against $endpoint: $e');
      }
    }

    // Drop the plugin's optimistic register entry for this channel: it was
    // added when `subscribe` was dispatched, and leaving it there would make a
    // later retry look unnecessary.
    _pusher.channels.remove(channelName);
    _live.remove(channelName);
    _inFlight.remove(channelName);

    _authFailures++;
    if (_authFailures >= _authFailureLimit) {
      AppLogger.w(
        'Realtime giving up after $_authFailures channel-auth failures; the app '
        'will poll instead. /broadcasting/auth must accept the app bearer token.',
      );
      _setStatus(RealtimeStatus.unavailable);
      _scheduleRevival();
    }
    return <String, dynamic>{'error': 'Auth failed'};
  }

  // ---- Config --------------------------------------------------------------

  /// Loads Pusher config from the backend bridge endpoint.
  /// Connector A is Pusher-compatible; Connector B is an alternative.
  Future<void> _loadConfig() async {
    try {
      final dynamic res = await _bridgeRepo.getConnectorA();
      if (res.success && res.data != null) {
        final Map<String, dynamic> data = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : <String, dynamic>{};
        final bool enabled = data['enabled'] ?? false;
        if (!enabled) {
          AppLogger.w(
            'Bridge Connector A reports enabled:false — realtime is switched '
            'off server-side (chat_realtime_enabled). Falling back to polling.',
          );
          return;
        }
        final Map<String, dynamic> public = data['public'] ?? <String, dynamic>{};
        final PusherBridgeConfig next = PusherBridgeConfig(
          appKey: (public['app_key'] ?? '').toString(),
          cluster: _clusterOf(public),
          appId: (public['app_id'] ?? '').toString(),
          host: (public['host'] ?? '').toString(),
          port: (public['port'] ?? '443').toString(),
          scheme: (public['scheme'] ?? 'https').toString(),
        );
        if (_pluginConfigured && next != _config && next.isValid) {
          // The Pusher app itself changed under us. The plugin holds the key
          // from its one `init`, so the socket has to be torn down before the
          // new credentials can take effect.
          AppLogger.i('Bridge returned new Pusher credentials; rebuilding socket.');
          await _teardownPlugin();
        }
        if (next.isValid) {
          _config = next;
          AppLogger.i(
            '✅ Bridge config loaded: key=$_maskedKey cluster=${_config.cluster} '
            'host=${_config.host}',
          );
        }
      }
    } catch (e) {
      AppLogger.w('Failed to load bridge config, using fallback: $e');
    }
  }

  /// The cluster the bridge reported, or the production default with a loud
  /// note when the admin setting is blank — a wrong cluster is indistinguishable
  /// from a network problem once Pusher starts retrying.
  static String _clusterOf(Map<String, dynamic> public) {
    final String cluster = (public['cluster'] ?? '').toString().trim();
    if (cluster.isNotEmpty) return cluster;
    AppLogger.w(
      'Bridge returned no Pusher cluster — set pusher_app_cluster in the admin '
      'settings. Falling back to ${PusherBridgeConfig.fallback.cluster}.',
    );
    return PusherBridgeConfig.fallback.cluster;
  }

  // ---- Subscriptions -------------------------------------------------------

  /// Subscribe to the user's inbox channel: `App.User.{userId}`.
  ///
  /// Everything aimed at this member rides here — inbox previews, unread
  /// counts, and every incoming call — so this subscription is the one that
  /// has to survive backgrounding, network changes and re-login.
  Future<void> subscribeToUserChannel(int userId) async {
    if (userId <= 0) return;
    final String channelName = userChannel(userId);

    // Only one user channel at a time: switching accounts must not leave the
    // previous member's channel live.
    final List<String> stale = _desired
        .where((String c) => c.startsWith('private-App.User.') && c != channelName)
        .toList();
    for (final String c in stale) {
      await _unsubscribe(c);
    }

    _desired.add(channelName);
    await init();
    await _flushDesired();
  }

  /// Unsubscribe from user channel (e.g. on logout).
  Future<void> unsubscribeUserChannel() async {
    final List<String> channels = _desired
        .where((String c) => c.startsWith('private-App.User.'))
        .toList();
    for (final String c in channels) {
      await _unsubscribe(c);
    }
  }

  /// Subscribe to active conversation thread channel: `chat-thread.{threadId}`.
  Future<void> subscribeToThreadChannel(int threadId) async {
    if (threadId <= 0) return;
    final String channelName = threadChannel(threadId);
    if (_desired.contains(channelName) && _live.contains(channelName)) return;

    final List<String> stale = _desired
        .where((String c) => c.startsWith('private-chat-thread.') && c != channelName)
        .toList();
    for (final String c in stale) {
      await _unsubscribe(c);
    }

    _desired.add(channelName);
    await init();
    await _flushDesired();
  }

  /// Unsubscribe from active conversation thread channel.
  Future<void> unsubscribeThreadChannel() async {
    final List<String> channels = _desired
        .where((String c) => c.startsWith('private-chat-thread.'))
        .toList();
    for (final String c in channels) {
      await _unsubscribe(c);
    }
  }

  /// Sends a subscription for every wanted channel that is not confirmed yet.
  /// Called on connect, on reconnect, and whenever the wanted set changes.
  Future<void> _flushDesired() async {
    if (!_isSocketUp()) return;
    for (final String channel in _desired.toList()) {
      if (_live.contains(channel) || _inFlight.contains(channel)) continue;

      // The native Pusher client re-subscribes its own channels on reconnect,
      // and asking it to subscribe to one it already holds throws. Trusting its
      // register instead means a reconnect does not read as "socket up but no
      // channels", which would have us polling while events were arriving fine.
      if (_confirmedOnce.contains(channel) &&
          _pusher.channels.containsKey(channel)) {
        _live.add(channel);
        continue;
      }

      _inFlight.add(channel);
      try {
        await _pusher.subscribe(channelName: channel);
      } catch (e) {
        _inFlight.remove(channel);
        AppLogger.w('Failed to subscribe to $channel: $e');
      }
    }
  }

  Future<void> _unsubscribe(String channel) async {
    _desired.remove(channel);
    _live.remove(channel);
    _confirmedOnce.remove(channel);
    _inFlight.remove(channel);
    try {
      await _pusher.unsubscribe(channelName: channel);
    } catch (_) {
      // Already gone, or the socket is down — either way there is nothing left
      // to leave.
    }
  }

  // ---- Shutdown ------------------------------------------------------------

  /// Drops everything: used on logout, so the next member does not inherit
  /// this one's channels.
  Future<void> disconnect() async {
    _desired.clear();
    await _teardownPlugin();
    _reset();
  }

  Future<void> _teardownPlugin() async {
    for (final String channel in _live.toList()) {
      try {
        await _pusher.unsubscribe(channelName: channel);
      } catch (_) {}
    }
    _live.clear();
    _confirmedOnce.clear();
    _inFlight.clear();
    try {
      await _pusher.disconnect();
    } catch (_) {}
    _pluginConfigured = false;
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _revivalTimer?.cancel();
    _statusController.close();
  }

  // ---- Event routing -------------------------------------------------------

  void _handlePusherEvent(PusherEvent event) {
    if (event.eventName.startsWith('pusher:') ||
        event.eventName.startsWith('pusher_internal:')) {
      return;
    }

    AppLogger.i('Pusher event received: ${event.eventName} on ${event.channelName}');
    Map<String, dynamic> data = <String, dynamic>{};
    if (event.data != null) {
      try {
        final dynamic decoded = jsonDecode(event.data.toString());
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = <String, dynamic>{'raw': event.data};
      }
    }

    final String channel = event.channelName;
    // Laravel Echo writes `.call-incoming` to mean "no namespace"; over the raw
    // Pusher protocol the name arrives without that dot. Strip it either way so
    // one comparison covers both.
    final String evName =
        event.eventName.toLowerCase().replaceFirst(RegExp(r'^\.'), '');

    // The event name travels in the payload too, so downstream handlers can
    // tell a message from a read receipt without being passed it separately.
    data['__event'] = evName;
    data['__channel'] = channel;

    // Call signals ride BOTH the user channel and the thread channel, so they
    // are matched on the event name before anything looks at the channel —
    // otherwise `call-incoming` on the user channel would be mistaken for an
    // inbox update and the call would be silently dropped.
    if (evName.startsWith('call-')) {
      _safely(() => onCallEvent?.call(evName, data), evName);
      return;
    }

    if (channel.contains('App.User')) {
      _safely(() => onUserEvent?.call(data), evName);
    } else if (channel.contains('chat-thread')) {
      if (evName.contains('typing')) {
        _safely(() => onThreadTyping?.call(data), evName);
      } else if (evName.contains('block') ||
          evName.contains('unblock') ||
          evName.contains('clear') ||
          evName.contains('report')) {
        _safely(() => onThreadUpdated?.call(data), evName);
      } else {
        _safely(() => onThreadMessage?.call(data), evName);
      }
    }
  }

  /// A handler that throws must not take the socket with it — an unhandled
  /// error out of a plugin callback can tear down the event stream, which would
  /// turn one malformed payload into "realtime stopped working".
  void _safely(void Function() body, String event) {
    try {
      body();
    } catch (e, st) {
      AppLogger.w('Realtime handler for $event threw: $e\n$st');
    }
  }
}
