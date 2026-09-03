// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../controllers/call_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/notification_controller.dart';
import '../routes/app_routes.dart';
import '../network/network_info.dart';
import '../utils/app_logger.dart';
import 'notification_service.dart';
import 'push_token_service.dart';
import 'pusher_chat_service.dart';

/// Keeps realtime honest across the two events that used to break it silently:
/// the app going to the background, and the network changing.
///
/// Both Android and iOS suspend or kill a WebSocket while the app is not in
/// front of the user. Nothing in the app noticed: the service still held
/// `_connected = true` from before the pause, so on the way back in it neither
/// reconnected nor fetched what it had missed. Anything sent during those
/// minutes simply never appeared — the "kabhi aate hi nahin" case — until
/// something unrelated happened to trigger a refresh.
///
/// On every resume this now:
///
/// 1. marks the app foreground, so notifications stop double-ringing;
/// 2. re-establishes the socket if the platform dropped it;
/// 3. fetches the gap (inbox + the open conversation), because events that
///    happened while the socket was down were never delivered to anyone;
/// 4. re-registers the FCM token, which is what lets a *closed* app be reached;
/// 5. picks up a call that rang while the app was not running — Android's
///    full-screen intent launches the app for one, but that launch carries no
///    notification payload, so without this the app came up on its last screen
///    while the tray rang on beside it.
///
/// The same recovery runs when connectivity returns, since a wifi-to-mobile
/// handover produces no lifecycle event at all.
class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService({
    required PusherChatService realtime,
    required PushTokenService pushTokens,
    required NetworkInfo network,
  })  : _realtime = realtime,
        _pushTokens = pushTokens,
        _network = network;

  final PusherChatService _realtime;
  final PushTokenService _pushTokens;
  final NetworkInfo _network;

  StreamSubscription<bool>? _connectivitySub;
  bool _started = false;

  /// Guards against the recovery pass running several times over when a resume
  /// and a connectivity change land together.
  DateTime? _lastRecovery;
  static const Duration _recoveryDebounce = Duration(seconds: 2);

  void start() {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.appInForeground = true;

    _connectivitySub = _network.onStatusChange.listen((bool online) {
      AppLogger.i('Connectivity changed: online=$online');
      if (online) _recover(reason: 'network returned');
    });

    // The first pass also covers a cold start with a restored session.
    _recover(reason: 'startup');
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        NotificationService.instance.appInForeground = true;
        _recover(reason: 'resumed');
      case AppLifecycleState.inactive:
        // Transient (a system dialog, the app switcher); not worth reacting to
        // — treating it as backgrounded would flap the foreground flag every
        // time a permission sheet appears.
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        NotificationService.instance.appInForeground = false;
        if (Get.isRegistered<ChatController>()) {
          Get.find<ChatController>().onAppBackgrounded();
        }
    }
  }

  Future<void> _recover({required String reason}) async {
    final DateTime? last = _lastRecovery;
    if (last != null && DateTime.now().difference(last) < _recoveryDebounce) {
      return;
    }
    _lastRecovery = DateTime.now();
    AppLogger.i('Realtime recovery pass ($reason).');

    // Not awaited: this may have to sit out the splash (see below), and the
    // socket has no reason to wait for it. `ringFromPush` re-reads the call and
    // stays quiet if the offer is already over, so a stale record costs one
    // request and nothing else.
    unawaited(_ringPendingCall());

    // The socket first: if it comes straight back, `onReconnected` does the
    // catch-up and the explicit sync below is a cheap no-op.
    await _realtime.ensureConnected();

    if (Get.isRegistered<ChatController>()) {
      Get.find<ChatController>().onAppResumed();
    }
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().fetchNotifications(refresh: true);
    }

    // Last, because it is the slowest and nothing else waits on it.
    await _pushTokens.ensureSynced();
  }

  /// Rings for a call the FCM background isolate wrote down while the app was
  /// not running.
  Future<void> _ringPendingCall() async {
    if (!Get.isRegistered<CallController>()) return;

    final int? callId =
        await NotificationService.instance.takePendingIncomingCall();
    if (callId == null) return;

    await _waitForFirstRoute();

    AppLogger.i('Picking up call $callId left by the push isolate.');
    await Get.find<CallController>().ringFromPush(callId);
  }

  /// Holds off until the app has left the splash.
  ///
  /// The splash routes on with `Get.offAllNamed`, which tears down every route
  /// on the stack — and the incoming-call screen is a dialog route, so it went
  /// with it. The screen appeared and was swallowed a frame later, leaving the
  /// member looking at Discover with the tray ringing beside them. On a resume
  /// there is no splash and this returns almost immediately.
  Future<void> _waitForFirstRoute() async {
    const Duration step = Duration(milliseconds: 200);
    // Comfortably longer than the splash, and bounded so a stuck route can
    // never hold a ring forever.
    const int maxSteps = 50;

    for (int i = 0; i < maxSteps; i++) {
      if (Get.currentRoute != AppRoutes.splash) break;
      await Future<void>.delayed(step);
    }

    // One more beat, so whatever replaced the splash has finished building
    // before a dialog is pushed on top of it.
    await Future<void>.delayed(step);
  }
}
