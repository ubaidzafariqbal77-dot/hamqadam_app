import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../../controllers/call_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/interest_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/profile_view_controller.dart';
import '../../controllers/proposal_controller.dart';
import '../../features/chat/views/chat_conversation_view.dart';
import '../../features/chat/views/chat_inbox_view.dart';
import '../../features/interests/views/interests_view.dart';

import '../../features/notifications/views/notifications_view.dart';
import '../../features/payments/views/coin_usage_view.dart';
import '../../features/payments/views/membership_plans_view.dart';
import '../../features/profile_views/views/profile_views_view.dart';
import '../../features/proposals/views/proposals_view.dart';
import '../../models/chat_model.dart';
import '../utils/app_logger.dart';

/// Central service for displaying local and push notifications in the device tray.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications like messages, interests, and proposals.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Calls get their own channel: a ringtone instead of a message ping, and
  /// `Importance.max` so Android is allowed to raise the full-screen intent
  /// that turns a push into a ringing screen on a locked device.
  ///
  /// The sound is set via the AndroidManifest to use the device's default
  /// ringtone (not a bundled notification sound), so the phone rings exactly
  /// like an incoming phone call.
  static final AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
    'calls',
    'Incoming Calls',
    description: 'Ringing notifications for incoming audio and video calls.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: const RawResourceAndroidNotificationSound('ringtone'),
  );

  /// Action ids on the incoming-call notification. Matched in the tap handler,
  /// so they must stay in step with what [showIncomingCall] registers.
  static const String callAcceptAction = 'call_accept';
  static const String callRejectAction = 'call_reject';

  /// Notification ids are per-call so a second call cannot replace the first
  /// one's tray entry, and so [cancelIncomingCall] can dismiss exactly one.
  static int _callNotificationId(int callId) => 900000 + (callId % 90000);

  bool _isInitialized = false;
  String? cachedFcmToken;

  /// Audio player for in-app call ringtone.
  AudioPlayer? _ringtonePlayer;

  void updateFcmToken(String token) {
    if (token.isEmpty) return;
    cachedFcmToken = token;
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().syncPushToken(token);
    }
  }

  /// Initializes local notifications plugin and creates Android notification channels.
  Future<void> init() async {

    if (_isInitialized) return;

    try {
      // 1. Android channel creation
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_channel);
        await androidImplementation.createNotificationChannel(_callChannel);
        await androidImplementation.requestNotificationsPermission();
      }

      // 2. Initialization settings for Android and iOS
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // 3. Initialize plugin with click callback
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Accept / Decline on a call notification are actions, not taps —
          // they must not fall through to the routing logic.
          if (_handleCallAction(response)) return;
          _handleNotificationPayload(response.payload);
        },
      );

      _isInitialized = true;
      AppLogger.i('NotificationService initialized successfully');
    } catch (e) {
      AppLogger.w('NotificationService init error: $e');
    }
  }

  /// Displays a local notification in the device notification tray.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }  // ---- Incoming calls -------------------------------------------------------

  /// Rings [callId] in the tray with Accept and Decline buttons.
  ///
  /// This is what the member sees when a call arrives while the app is not in
  /// front of them. Both buttons set `showsUserInterface`, so Android brings
  /// the app forward and the action is handled by [CallController] on the main
  /// isolate — the same path a tap on the in-app incoming screen takes. Doing
  /// the decline silently from the notification isolate would need its own HTTP
  /// client and a second copy of the auth token, for a saving of one frame.
  Future<void> showIncomingCall({
    required int callId,
    required String callerName,
    required bool isVideo,
  }) async {
    await init();

    // Play ringtone in-app
    playRingtone();

    final String body = isVideo ? 'Incoming video call' : 'Incoming voice call';
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      _callChannel.id,
      _callChannel.name,
      channelDescription: _callChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: true,
      timeoutAfter: 60000,
      icon: '@mipmap/ic_launcher',
      sound: const RawResourceAndroidNotificationSound('ringtone'),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          callRejectAction,
          'Decline',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          callAcceptAction,
          'Accept',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    try {
      await _localNotifications.show(
        _callNotificationId(callId),
        callerName,
        body,
        NotificationDetails(android: android, iOS: ios),
        payload: jsonEncode(<String, dynamic>{
          'type': 'call_incoming',
          'call_id': callId,
        }),
      );
    } catch (e) {
      AppLogger.w('Could not show the incoming-call notification: $e');
    }
  }

  /// Clears the ringing notification once the call is answered, declined or
  /// gone. Safe to call for a call that was never shown.
  Future<void> cancelIncomingCall(int callId) async {
    try {
      await _localNotifications.cancel(_callNotificationId(callId));
    } catch (_) {
      // Nothing to dismiss.
    }
    stopRingtone();
  }

  /// Plays the ringtone in a loop for incoming calls.
  void playRingtone() {
    try {
      stopRingtone();
      _ringtonePlayer = AudioPlayer();
      _ringtonePlayer!.setReleaseMode(ReleaseMode.loop);
      _ringtonePlayer!.play(AssetSource('ringtone.wav'), volume: 1.0);
    } catch (e) {
      AppLogger.w('Could not play ringtone: $e');
    }
  }

  /// Stops the ringtone playback.
  void stopRingtone() {
    try {
      _ringtonePlayer?.stop();
      _ringtonePlayer?.dispose();
    } catch (_) {}
    _ringtonePlayer = null;
  }

  /// Routes Accept / Decline taps. Returns true when [response] was a call
  /// action and has been dealt with.
  bool _handleCallAction(NotificationResponse response) {
    final String? action = response.actionId;
    if (action != callAcceptAction && action != callRejectAction) return false;

    final int? callId = _callIdFrom(response.payload);
    if (callId == null) return true; // it was ours; nothing usable in it

    if (!Get.isRegistered<CallController>()) {
      AppLogger.w('Call action $action arrived with no CallController.');
      return true;
    }
    final CallController calls = Get.find<CallController>();
    if (action == callAcceptAction) {
      calls.acceptIncoming(callId);
    } else {
      calls.rejectIncoming(callId);
    }
    return true;
  }

  int? _callIdFrom(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return int.tryParse((decoded['call_id'] ?? '').toString());
      }
    } catch (_) {
      // Not JSON — nothing to route on.
    }
    return null;
  }

  /// Extracts information from an FCM [RemoteMessage] and displays it in the system tray,
  /// while triggering appropriate background controller refreshes.
  Future<void> showFromRemoteMessage(RemoteMessage message) async {
    // ── Incoming call pushed while the socket was down ──────────────────────
    // CRITICAL: Check for call signals FIRST, before the body-empty check.
    // FCM call pushes are data-only (no notification.body), so the old code
    // returned early and silently dropped every call push when the app was
    // backgrounded or killed.
    if ((message.data['type'] ?? '').toString().toLowerCase() == 'call_incoming') {
      final int? callId = int.tryParse((message.data['call_id'] ?? '').toString());
      if (callId != null) {
        await _ringFromPush(callId);
        return;
      }
    }

    final String title = message.notification?.title ??
        message.data['title']?.toString() ??
        'HamQadam';

    final String? body = message.notification?.body ?? message.data['message']?.toString() ?? message.data['body']?.toString();

    if (body == null || body.isEmpty) return;

    final int id = message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final String payload = jsonEncode(message.data);

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );

    // Trigger realtime UI / State refreshes based on notification type
    _refreshCorrespondingController(message.data);
  }

  /// Rings for a call the app learned about from a push rather than from the
  /// live socket.
  ///
  /// The push carries only the id: pushes can be delayed by Doze for minutes,
  /// and a notification that rang for a call the caller had already given up on
  /// would be worse than none. `GET /calls/{id}` settles whether it is still
  /// worth ringing.
  Future<void> _ringFromPush(int callId) async {
    if (!Get.isRegistered<CallController>()) return;
    await Get.find<CallController>().ringFromPush(callId);
  }

  void _refreshCorrespondingController(Map<String, dynamic> data) {
    final String type = (data['type'] ?? '').toString().toLowerCase();

    // 1. Notifications list & badge refresh (always)
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().fetchNotifications(refresh: true);
    }

    // 2. Chat messages
    if (type.contains('message') || type.contains('chat')) {
      if (Get.isRegistered<ChatController>()) {
        Get.find<ChatController>().loadThreads(silent: true);
      }
    }


    // 3. Proposals
    if (type.contains('proposal')) {
      if (Get.isRegistered<ProposalController>()) {
        Get.find<ProposalController>().loadProposals(silent: true);
      }
    }

    // 4. Interests
    if (type.contains('interest')) {
      if (Get.isRegistered<InterestController>()) {
        Get.find<InterestController>().refreshAll();
      }
    }

    // 5. Profile views
    if (type.contains('view')) {
      if (Get.isRegistered<ProfileViewController>()) {
        Get.find<ProfileViewController>().loadAll();
      }
    }

    // 6. Coins / Payments
    if (type.contains('coin') || type.contains('package') || type.contains('payment')) {
      if (Get.isRegistered<PaymentController>()) {
        Get.find<PaymentController>().loadCurrentPackage(silent: true);
      }
    }
  }

  /// Handles routing when a user taps on a notification in the tray.
  void _handleNotificationPayload(String? payloadStr) {
    if (payloadStr == null || payloadStr.isEmpty) {
      Get.to(() => const NotificationsView());
      return;
    }

    try {
      final Map<String, dynamic> data =
          jsonDecode(payloadStr) as Map<String, dynamic>;
      final String type = (data['type'] ?? '').toString().toLowerCase();
      final int? notifyBy = int.tryParse(data['notify_by']?.toString() ?? '');
      final int? infoId = int.tryParse(data['info_id']?.toString() ?? '');
      // 0. Incoming Call Invitation

      if (type == 'call_incoming' || type == 'call_invite') {
        final int? callId = int.tryParse((data['call_id'] ?? '').toString());
        if (callId != null) {
          _ringFromPush(callId);
          return;
        }
      }

      // 1. Chat messages
      if (type.contains('message') || type.contains('chat')) {

        if (Get.isRegistered<ChatController>()) {
          final ChatController chatCtrl = Get.find<ChatController>();
          final List<ChatThread> threads =
              chatCtrl.threadsState.value.data ?? <ChatThread>[];

          ChatThread? thread;
          if (infoId != null && infoId > 0) {
            thread = threads.cast<ChatThread?>().firstWhere(
                  (ChatThread? t) => t?.id == infoId,
                  orElse: () => null,
                );
          }
          if (thread == null && notifyBy != null && notifyBy > 0) {
            thread = threads.cast<ChatThread?>().firstWhere(
                  (ChatThread? t) => t?.participant.id == notifyBy,
                  orElse: () => null,
                );
          }

          if (thread != null) {
            ChatConversationView.open(thread);
            return;
          }
        }
        Get.to(() => const ChatInboxView());
        return;
      }

      // 2. Proposals
      if (type.contains('proposal')) {
        Get.to(() => const ProposalsView());
        return;
      }

      // 3. Interests
      if (type.contains('interest')) {
        Get.to(() => const InterestsView());
        return;
      }

      // 4. Profile Views
      if (type.contains('profile_view') || type.contains('view_profile')) {
        Get.to(() => const ProfileViewsView());
        return;
      }

      // 5. Coins / Free Coins Bonus
      if (type.contains('coin') || type.contains('bonus') || type.contains('credit')) {
        Get.to(() => const CoinUsageView());
        return;
      }

      // 6. Payments / Package Membership
      if (type.contains('payment') || type.contains('package') || type.contains('plan') || type.contains('subscription')) {
        Get.to(() => const MembershipPlansView());
        return;
      }

      // Default: Navigate to Notifications View
      Get.to(() => const NotificationsView());
    } catch (e) {
      AppLogger.w('Failed to parse notification payload: $e');
      Get.to(() => const NotificationsView());
    }
  }

  /// Handles tap on an FCM RemoteMessage when app is opened from background or terminated state.
  void handleRemoteMessageTap(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      _handleNotificationPayload(jsonEncode(message.data));
    } else {
      Get.to(() => const NotificationsView());
    }
  }
}


