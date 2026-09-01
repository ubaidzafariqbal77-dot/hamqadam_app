// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../../constants/app_constants.dart';
import '../../repositories/bridge_repository.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';

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
}

/// Realtime Pusher service for Chat and notification streams.
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
class PusherChatService {
  PusherChatService({
    required SecureStorageService storage,
    required BridgeRepository bridgeRepository,
  })  : _storage = storage,
        _bridgeRepo = bridgeRepository;

  final SecureStorageService _storage;
  final BridgeRepository _bridgeRepo;
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  bool _initialized = false;
  bool _connected = false;
  String? _currentUserChannel;
  String? _currentThreadChannel;
  PusherBridgeConfig _config = PusherBridgeConfig.fallback;

  // Callbacks
  void Function(Map<String, dynamic> data)? onUserEvent;
  void Function(Map<String, dynamic> data)? onThreadMessage;
  void Function(Map<String, dynamic> data)? onThreadTyping;
  void Function(Map<String, dynamic> data)? onThreadUpdated;

  /// Every `call-*` event, with the bare event name (`call-incoming`, …) and
  /// the `{call, rtc}` payload. Kept separate from [onUserEvent] because those
  /// arrive on the same channel and are indistinguishable without the name.
  void Function(String event, Map<String, dynamic> data)? onCallEvent;

  /// Laravel's `PrivateChannel('App.User.{id}')`.
  static String userChannel(int userId) => 'private-App.User.$userId';

  /// Laravel's `PrivateChannel('chat-thread.{id}')`.
  static String threadChannel(int threadId) => 'private-chat-thread.$threadId';

  bool get isConnected => _connected;
  PusherBridgeConfig get config => _config;

  /// Fetches Pusher config from the backend bridge endpoint, then connects.
  ///
  /// Call this once after authentication (when a bearer token exists).
  /// Falls back to the hardcoded config if the bridge endpoint fails.
  Future<void> init() async {
    if (_initialized) return;

    // 1. Fetch dynamic config from backend
    await _loadConfig();

    final String key = _config.appKey;
    if (key.isEmpty || key == 'YOUR_PUSHER_APP_KEY') {
      AppLogger.i('Pusher key not set; realtime using smart heartbeat polling.');
      return;
    }

    // 2. Connect to Pusher with the fetched config
    try {
      final String? token = _storage.cachedToken;
      await _pusher.init(
        apiKey: key,
        cluster: _config.cluster,
        authEndpoint: PusherConfig.authEndpoint,
        onConnectionStateChange: (dynamic currentState, dynamic previousState) {
          AppLogger.i('Pusher state: $previousState -> $currentState');
          _connected = currentState == 'CONNECTED';
        },
        onError: (String message, int? code, dynamic e) {
          AppLogger.w('Pusher error: $message (code: $code, err: $e)');
        },
        onSubscriptionSucceeded: (String channelName, dynamic data) {
          AppLogger.i('Pusher subscribed to: $channelName');
        },
        onEvent: (PusherEvent event) {
          _handlePusherEvent(event);
        },
        onAuthorizer: (String channelName, String socketId, dynamic options) async {
          // POST to /broadcasting/auth with socket_id + channel_name
          // and the user's Bearer token for authentication.
          try {
            final Uri uri = Uri.parse(PusherConfig.authEndpoint);
            final http.Response response = await http.post(
              uri,
              headers: <String, String>{
                'Accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: <String, String>{
                'socket_id': socketId,
                'channel_name': channelName,
              },
            );

            if (response.statusCode == 200) {
              final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
              return body; // { 'auth': 'key:signature' }
            } else {
              AppLogger.w('Pusher auth failed (${response.statusCode}): ${response.body}');
              return <String, dynamic>{'error': 'Auth failed'};
            }
          } catch (e) {
            AppLogger.w('Pusher auth error: $e');
            return <String, dynamic>{'error': 'Auth error'};
          }
        },
      );

      await _pusher.connect();
      _initialized = true;
      AppLogger.i('✅ Pusher connected: key=${key.substring(0, 8)}... cluster=${_config.cluster} auth=${PusherConfig.authEndpoint}');
    } catch (e, st) {
      AppLogger.w('❌ Pusher initialization error: $e\n$st');
    }
  }

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
          AppLogger.i('Bridge Connector A is disabled; using fallback config.');
          return;
        }
        final Map<String, dynamic> public = data['public'] ?? <String, dynamic>{};
        _config = PusherBridgeConfig(
          appKey: (public['app_key'] ?? '').toString(),
          cluster: _clusterOf(public),
          appId: (public['app_id'] ?? '').toString(),
          host: (public['host'] ?? '').toString(),
          port: (public['port'] ?? '443').toString(),
          scheme: (public['scheme'] ?? 'https').toString(),
        );
        AppLogger.i('✅ Bridge config loaded: key=${_config.appKey.substring(0, 8)}... cluster=${_config.cluster} host=${_config.host}');
      }
    } catch (e) {
      AppLogger.w('Failed to load bridge config, using fallback: $e');
      _config = PusherBridgeConfig.fallback;
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

  /// Subscribe to the user's inbox channel: `App.User.{userId}`.
  Future<void> subscribeToUserChannel(int userId) async {
    if (!_initialized) await init();
    if (!_initialized) return;

    final String channelName = userChannel(userId);
    if (_currentUserChannel == channelName) return;

    if (_currentUserChannel != null) {
      await _pusher.unsubscribe(channelName: _currentUserChannel!);
    }

    _currentUserChannel = channelName;
    try {
      await _pusher.subscribe(channelName: channelName);
    } catch (e) {
      AppLogger.w('Failed to subscribe to $channelName: $e');
    }
  }

  /// Unsubscribe from user channel (e.g. on logout).
  Future<void> unsubscribeUserChannel() async {
    if (_currentUserChannel != null) {
      try {
        await _pusher.unsubscribe(channelName: _currentUserChannel!);
      } catch (_) {}
      _currentUserChannel = null;
    }
  }

  /// Subscribe to active conversation thread channel: `chat-thread.{threadId}`.
  Future<void> subscribeToThreadChannel(int threadId) async {
    if (!_initialized) await init();
    if (!_initialized) return;

    final String channelName = threadChannel(threadId);
    if (_currentThreadChannel == channelName) return;

    if (_currentThreadChannel != null) {
      await _pusher.unsubscribe(channelName: _currentThreadChannel!);
    }

    _currentThreadChannel = channelName;
    try {
      await _pusher.subscribe(channelName: channelName);
    } catch (e) {
      AppLogger.w('Failed to subscribe to $channelName: $e');
    }
  }

  /// Unsubscribe from active conversation thread channel.
  Future<void> unsubscribeThreadChannel() async {
    if (_currentThreadChannel != null) {
      try {
        await _pusher.unsubscribe(channelName: _currentThreadChannel!);
      } catch (_) {}
      _currentThreadChannel = null;
    }
  }

  /// Disconnect on app close / logout.
  Future<void> disconnect() async {
    try {
      await unsubscribeThreadChannel();
      await unsubscribeUserChannel();
      if (_connected) {
        await _pusher.disconnect();
      }
    } catch (_) {}
    _connected = false;
    _initialized = false;
  }

  void _handlePusherEvent(PusherEvent event) {
    if (event.eventName.startsWith('pusher:') || event.eventName.startsWith('pusher_internal:')) {
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
    final String evName = event.eventName.toLowerCase().replaceFirst(RegExp(r'^\.'), '');

    // Call signals ride BOTH the user channel and the thread channel, so they
    // are matched on the event name before anything looks at the channel —
    // otherwise `call-incoming` on the user channel would be mistaken for an
    // inbox update and the call would be silently dropped.
    if (evName.startsWith('call-')) {
      onCallEvent?.call(evName, data);
      return;
    }

    if (channel.contains('App.User')) {
      onUserEvent?.call(data);
    } else if (channel.contains('chat-thread')) {
      if (evName.contains('typing')) {
        onThreadTyping?.call(data);
      } else if (evName.contains('block') ||
          evName.contains('unblock') ||
          evName.contains('clear') ||
          evName.contains('report')) {
        onThreadUpdated?.call(data);
      } else {
        onThreadMessage?.call(data);
      }
    }
  }
}
