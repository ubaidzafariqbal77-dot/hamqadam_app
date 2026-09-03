import 'dart:collection';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
///
/// ## The de-duplication gate
///
/// The same message can reach this class from four directions at once: the
/// Pusher thread channel, the Pusher user channel, an FCM push, and the
/// notifications poller. Each used to call straight through, so one message
/// produced up to four tray entries and four buzzes.
///
/// Everything now funnels through [claim]: the first caller to claim a key gets
/// to show the notification and the rest are dropped. Keys are derived from
/// server ids (message id, notification id, call id), so all four paths
/// naturally agree on the same key without knowing about each other.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// The incoming-call ringtone, used for audio and video calls alike.
  ///
  /// It exists twice on purpose, and both copies have to stay in step:
  ///
  /// * `assets/ringtone.mp3` — the Flutter asset [playRingtone] loops while the
  ///   app is open and the incoming-call screen is up;
  /// * `android/app/src/main/res/raw/ringtone.mp3` — the Android raw resource
  ///   the `calls` notification channel rings with when the app is not open.
  ///   Android resolves it by resource *name*, so the `.mp3` and the `.wav`
  ///   this replaced would both be `R.raw.ringtone`; only one of them may exist
  ///   in `res/raw` or the build fails on a duplicate resource. Because the name
  ///   did not change, the channel's stored sound URI did not either, so
  ///   installs that already created the channel pick the new audio up without
  ///   needing a new channel id.
  static const String ringtoneAsset = 'ringtone.mp3';

  /// The `res/raw` resource name — deliberately without the extension.
  static const String _ringtoneRawResource = 'ringtone';

  /// Messages and everything else that is not a call.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Messages & Activity',
    description:
        'This channel is used for important notifications like messages, interests, and proposals.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Calls get their own channel: a ringtone instead of a message ping, and
  /// `Importance.max` so Android is allowed to raise the full-screen intent
  /// that turns a push into a ringing screen on a locked device.
  static const AndroidNotificationChannel _callChannel =
      AndroidNotificationChannel(
    'calls',
    'Incoming Calls',
    description: 'Ringing notifications for incoming audio and video calls.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound(_ringtoneRawResource),
  );

  /// The same call notification, without a sound of its own.
  ///
  /// On Android 8+ the sound belongs to the channel, not the notification, so a
  /// `playSound: false` on the details is ignored. Two channels is the only way
  /// to have the tray ring when the app is in the background and stay quiet
  /// when the in-app incoming-call screen is already ringing — which is why the
  /// phone used to ring three times over for one call (channel + the service's
  /// own player + the call screen's player).
  static const AndroidNotificationChannel _callChannelSilent =
      AndroidNotificationChannel(
    'calls_silent',
    'Incoming Calls (in app)',
    description:
        'Shown instead of the ringing channel while the app is open and already ringing.',
    importance: Importance.max,
    playSound: false,
    enableVibration: false,
  );

  /// Action ids on the incoming-call notification. Matched in the tap handler,
  /// so they must stay in step with what [showIncomingCall] registers.
  static const String callAcceptAction = 'call_accept';
  static const String callRejectAction = 'call_reject';

  /// Where a ringing call is left for the app to pick up.
  ///
  /// The FCM background isolate is the only thing running when a call arrives
  /// at a killed app. It raises the tray notification, and Android's
  /// full-screen intent then launches the app - but that launch is not a
  /// notification *tap*, so `getInitialMessage` and the plugin's launch details
  /// are both empty and the main isolate has no idea a call is ringing. It used
  /// to come up on whatever screen it was last on while the tray rang on
  /// beside it. The isolate writes the call here instead, and
  /// [takePendingIncomingCall] hands it over on the way in.
  static const String _pendingCallKey = 'pending_incoming_call_v1';

  /// How long a written-down ring stays worth acting on. A little over the
  /// longest ring window, so a stale record can never ring for a call that is
  /// certainly over; [CallController.ringFromPush] re-reads the call anyway.
  static const Duration _pendingCallTtl = Duration(seconds: 90);

  // ---- Notification id space -----------------------------------------------
  // Stable, per-entity ids so re-showing the same thing replaces its tray entry
  // instead of stacking another copy. The ranges must not overlap.

  static int _messageNotificationId(int messageId) =>
      200000 + (messageId.abs() % 400000);
  static int _threadSummaryId(int threadId) => 700000 + (threadId.abs() % 90000);
  static int _activityNotificationId(int notificationId) =>
      800000 + (notificationId.abs() % 90000);
  static int _callNotificationId(int callId) => 900000 + (callId.abs() % 90000);

  static String _threadGroupKey(int threadId) => 'com.app.hamqadam.THREAD_$threadId';

  bool _isInitialized = false;
  String? cachedFcmToken;

  /// Whether the UI is in front of the user right now.
  ///
  /// Set by [AppLifecycleService]. It decides two things: whether the tray
  /// notification should make a sound (the in-app UI does it instead), and
  /// whether a chat notification is worth showing at all. Defaults to false so
  /// the FCM background isolate — which builds its own instance of this
  /// singleton and never sees a lifecycle callback — behaves like a closed app.
  bool appInForeground = false;

  /// Audio player for in-app call ringtone.
  AudioPlayer? _ringtonePlayer;

  /// Recently claimed notification keys, oldest first, with the time they were
  /// claimed. A [LinkedHashMap] keeps insertion order so pruning is cheap.
  final LinkedHashMap<String, DateTime> _claimed =
      LinkedHashMap<String, DateTime>();
  static const Duration _claimTtl = Duration(minutes: 3);
  static const int _claimCap = 300;

  /// Tray entries currently showing per thread, so opening a conversation can
  /// clear exactly that conversation's notifications — the way WhatsApp does —
  /// without touching calls or other activity.
  final Map<int, Set<int>> _threadNotificationIds = <int, Set<int>>{};

  /// Last few message previews per thread, for the grouped summary line.
  final Map<int, List<String>> _threadLines = <int, List<String>>{};

  void updateFcmToken(String token) {
    if (token.isEmpty) return;
    if (cachedFcmToken == token) return;
    cachedFcmToken = token;
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().syncPushToken(token);
    }
  }

  // ---- De-duplication ------------------------------------------------------

  /// Claims [key] for whoever calls first. Returns false if it was already
  /// claimed inside the TTL, meaning somebody else is already showing it.
  ///
  /// Callers should claim BEFORE doing any work, and use the most specific
  /// server id available so the socket path and the push path collide on
  /// purpose.
  ///
  /// [ttl] shortens the window for a key that is derived from content rather
  /// than an id — see [chatContentKey].
  bool claim(String key, {Duration? ttl}) {
    final DateTime now = DateTime.now();
    _claimed.removeWhere(
      (String _, DateTime at) => now.difference(at) > _claimTtl,
    );
    while (_claimed.length > _claimCap) {
      _claimed.remove(_claimed.keys.first);
    }
    final DateTime? at = _claimed[key];
    if (at != null && now.difference(at) <= (ttl ?? _claimTtl)) return false;
    _claimed[key] = now;
    return true;
  }

  /// Forgets a claim so the same notification may be shown again — used when a
  /// call is re-offered, or after the tray entry has been cancelled.
  void releaseClaim(String key) => _claimed.remove(key);

  /// The key every path uses for one non-chat activity notification.
  ///
  /// The server's activity pushes carry `type`, `notify_by` and `info_id` but
  /// **no** notification-row id, while the notifications poller has the row.
  /// Keying on the three fields both of them do have is what lets the push and
  /// the poller collide — otherwise one interest showed up twice, once from
  /// each.
  static String activityKey({
    required String type,
    int? notifyBy,
    int? infoId,
  }) =>
      'act:${type.toLowerCase()}:${notifyBy ?? 0}:${infoId ?? 0}';

  /// The content key for one chat message, for the paths that do not know its
  /// id.
  ///
  /// The backend sends **two** pushes per message — `ChatApiService` sends one
  /// with `message_id`, and `NotificationHelper::chatMessage` sends another
  /// with only `notify_by` / `info_id` — and also writes a notification row the
  /// poller will find. Only the first of those three carries an id, so the
  /// other two are collapsed on the conversation plus the text.
  ///
  /// Claimed with a short TTL: the cost of a content key is that the same
  /// person sending the identical text twice inside the window only notifies
  /// once, and a few seconds is enough to catch the duplicates while making
  /// that almost impossible to hit by accident.
  static String chatContentKey(int threadId, String body) =>
      'chat:$threadId:${body.trim().hashCode}';

  static const Duration contentClaimTtl = Duration(seconds: 20);

  // ---- Setup ---------------------------------------------------------------

  /// Brings up the local-notifications plugin: callbacks first, then channels,
  /// then permissions.
  ///
  /// **The order matters and is not cosmetic.** This used to do all three in one
  /// `try`, with the permission requests first, and on a real device that meant
  /// notifications were half-initialised:
  ///
  /// ```
  /// NotificationService init error: PlatformException(
  ///   NullPointerException: Context.checkPermission on a null object reference
  ///   at FlutterLocalNotificationsPlugin.requestNotificationsPermission(:1816))
  /// ```
  ///
  /// `requestNotificationsPermission()` needs an Activity, and the FCM
  /// background isolate has none — so it threw, took the rest of the method
  /// with it, and `initialize()` never ran. Notifications still *appeared*
  /// (channels had been created, and `show` does not require `initialize`), but
  /// `onDidReceiveNotificationResponse` was never registered, so **tapping a
  /// notification did nothing and Accept / Decline on a call did nothing** —
  /// and `_isInitialized` stayed false, so every later call retried and threw
  /// again.
  ///
  /// Now `initialize()` runs first and on its own, and each best-effort step
  /// after it is isolated so it cannot take the others down.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Initialization settings for Android and iOS
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Not const: `DarwinNotificationAction.plain` is a factory.
      final DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: <DarwinNotificationCategory>[
          // iOS needs the Accept / Decline pair declared up front; a category
          // that is not registered here shows as a plain alert with no buttons.
          DarwinNotificationCategory(
            'hamqadam_call',
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                callAcceptAction,
                'Accept',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                callRejectAction,
                'Decline',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.destructive,
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
            options: <DarwinNotificationCategoryOption>{
              DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            },
          ),
        ],
      );

      final InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // 2. Register the plugin and its callbacks. This is the step that must
      //    not be skipped: it is what routes a tap and the call actions.
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
      AppLogger.w('NotificationService initialize failed: $e');
      // Deliberately not returning: the channels below are what make a
      // notification ring at all, and they are worth creating even if the
      // callback registration failed.
    }

    await _createChannels();
    await _requestPermissionsQuietly();
  }

  /// Creates the Android channels. Safe to repeat — Android treats a second
  /// create of the same id as a no-op (except for name/description updates).
  Future<void> _createChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    for (final AndroidNotificationChannel channel in <AndroidNotificationChannel>[
      _channel,
      _callChannel,
      _callChannelSilent,
    ]) {
      try {
        await android.createNotificationChannel(channel);
      } catch (e) {
        AppLogger.w('Could not create the ${channel.id} channel: $e');
      }
    }
  }

  /// Asks for the notification permissions, each independently.
  ///
  /// Both of these need an Activity, so both throw in the FCM background
  /// isolate — where they are also pointless, since nothing there can show a
  /// system prompt. They are attempted anyway rather than gated on a guess
  /// about which isolate we are in, and each failure is swallowed on its own.
  Future<void> _requestPermissionsQuietly() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    try {
      await android.requestNotificationsPermission();
    } catch (e) {
      AppLogger.d('Notification permission request skipped: $e');
    }

    try {
      // Without this, `fullScreenIntent` is downgraded to a heads-up banner on
      // Android 14+, so a call cannot wake a locked phone.
      await android.requestFullScreenIntentPermission();
    } catch (e) {
      AppLogger.d('Full-screen-intent permission request skipped: $e');
    }
  }

  /// Replays the notification that launched the app from cold.
  ///
  /// `onDidReceiveNotificationResponse` only fires while the engine is running.
  /// Tapping Accept on a ringing call for a killed app starts the process, and
  /// without this the app would open on the splash screen having silently
  /// swallowed the answer.
  Future<void> handleLaunchDetails() async {
    try {
      final NotificationAppLaunchDetails? details =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return;
      final NotificationResponse? response = details.notificationResponse;
      if (response == null) return;
      if (_handleCallAction(response)) return;
      _handleNotificationPayload(response.payload);
    } catch (e) {
      AppLogger.w('Could not read notification launch details: $e');
    }
  }

  // ---- Generic notifications -----------------------------------------------

  /// Displays a local notification in the device notification tray.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? groupKey,
    int? badgeCount,
  }) async {
    await init();

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      groupKey: groupKey,
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
      number: badgeCount,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: badgeCount,
      threadIdentifier: groupKey,
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
  }

  // ---- Chat messages -------------------------------------------------------

  /// One incoming chat message, grouped under its conversation.
  ///
  /// Android stacks entries that share a `groupKey` behind a summary, which is
  /// what stops five quick messages from filling the shade with five separate
  /// cards. [cancelThreadNotifications] clears the stack when the member opens
  /// the conversation, so the tray never shows something already read.
  Future<void> showMessageNotification({
    required int messageId,
    required int threadId,
    required int senderId,
    required String senderName,
    required String body,
  }) async {
    if (!claim('msg:$messageId')) return;
    // The same message also arrives without an id — a second server push and a
    // notification row — so stake the content key too.
    claim(chatContentKey(threadId, body), ttl: contentClaimTtl);
    await init();

    final int id = _messageNotificationId(messageId);
    final String group = _threadGroupKey(threadId);

    final List<String> lines = _threadLines.putIfAbsent(threadId, () => <String>[]);
    lines.add(body);
    if (lines.length > 6) lines.removeAt(0);

    final String payload = jsonEncode(<String, dynamic>{
      'type': 'chat_message',
      'thread_id': threadId,
      'info_id': threadId,
      'notify_by': senderId,
      'message_id': messageId,
    });

    final AndroidNotificationDetails android = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.message,
      groupKey: group,
      styleInformation: BigTextStyleInformation(body, contentTitle: senderName),
      // A per-conversation shortcut id lets the launcher badge the right chat
      // and lets Android collapse our entries the way a messaging app's are.
      when: DateTime.now().millisecondsSinceEpoch,
    );

    final DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: group,
    );

    try {
      await _localNotifications.show(
        id,
        senderName,
        body,
        NotificationDetails(android: android, iOS: ios),
        payload: payload,
      );
      (_threadNotificationIds[threadId] ??= <int>{}).add(id);

      // The summary is what the member actually sees once there is more than
      // one message waiting.
      if (lines.length > 1) {
        final int summaryId = _threadSummaryId(threadId);
        await _localNotifications.show(
          summaryId,
          senderName,
          '${lines.length} new messages',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
              // The summary must not ring again for a message that already did.
              playSound: false,
              silent: true,
              icon: '@mipmap/ic_launcher',
              groupKey: group,
              setAsGroupSummary: true,
              styleInformation: InboxStyleInformation(
                List<String>.from(lines),
                contentTitle: senderName,
                summaryText: '${lines.length} new messages',
              ),
            ),
          ),
          payload: payload,
        );
        _threadNotificationIds[threadId]!.add(summaryId);
      }
    } catch (e) {
      AppLogger.w('Could not show the message notification: $e');
    }
  }

  /// Clears every tray entry belonging to [threadId]. Called when the member
  /// opens or reads the conversation.
  Future<void> cancelThreadNotifications(int threadId) async {
    final Set<int>? ids = _threadNotificationIds.remove(threadId);
    _threadLines.remove(threadId);
    if (ids == null || ids.isEmpty) return;
    for (final int id in ids) {
      try {
        await _localNotifications.cancel(id);
      } catch (_) {
        // Already dismissed by the member.
      }
    }
  }

  // ---- Incoming calls -------------------------------------------------------

  /// Rings [callId] in the tray with Accept and Decline buttons.
  ///
  /// This is what the member sees when a call arrives while the app is not in
  /// front of them. Both buttons set `showsUserInterface`, so Android brings
  /// the app forward and the action is handled by [CallController] on the main
  /// isolate — the same path a tap on the in-app incoming screen takes. Doing
  /// the decline silently from the notification isolate would need its own HTTP
  /// client and a second copy of the auth token, for a saving of one frame.
  ///
  /// The sound comes from the channel, and which channel is chosen depends on
  /// whether the in-app screen is already ringing — see [_callChannelSilent].
  Future<void> showIncomingCall({
    required int callId,
    required String callerName,
    required bool isVideo,
    int ringSeconds = 60,
  }) async {
    await init();

    final bool ringInTray = !appInForeground;
    final AndroidNotificationChannel channel =
        ringInTray ? _callChannel : _callChannelSilent;

    final String body = isVideo ? 'Incoming video call' : 'Incoming voice call';
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: true,
      // A ring that outlives the server's ring window is a notification for a
      // call nobody is on any more.
      timeoutAfter: (ringSeconds.clamp(15, 180)) * 1000,
      icon: '@mipmap/ic_launcher',
      playSound: ringInTray,
      silent: !ringInTray,
      sound: ringInTray
          ? const RawResourceAndroidNotificationSound(_ringtoneRawResource)
          : null,
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
      presentSound: ringInTray,
      sound: 'default',
      categoryIdentifier: 'hamqadam_call',
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
          'caller_name': callerName,
          'is_video': isVideo,
        }),
      );
      await _rememberPendingCall(callId);
    } catch (e) {
      AppLogger.w('Could not show the incoming-call notification: $e');
    }
  }

  /// Notes that [callId] is ringing, for an app that is not running yet.
  Future<void> _rememberPendingCall(int callId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingCallKey,
        jsonEncode(<String, dynamic>{
          'call_id': callId,
          'at': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      AppLogger.d('Could not record the pending call: $e');
    }
  }

  /// Reads and clears the ring left behind by the background isolate.
  ///
  /// Returns the call id only while it is still fresh enough to be worth
  /// re-reading. Clearing on the way out is what stops one ring being replayed
  /// on every later resume.
  Future<int?> takePendingIncomingCall() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // The record was written by a different isolate, so this isolate's cache
      // does not have it yet.
      await prefs.reload();

      final String? raw = prefs.getString(_pendingCallKey);
      if (raw == null || raw.isEmpty) return null;
      await prefs.remove(_pendingCallKey);

      final Map<String, dynamic> data =
          jsonDecode(raw) as Map<String, dynamic>;
      final int? callId = int.tryParse((data['call_id'] ?? '').toString());
      final int at = int.tryParse((data['at'] ?? '').toString()) ?? 0;
      if (callId == null) return null;

      final Duration age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(at));
      if (age > _pendingCallTtl) return null;

      return callId;
    } catch (e) {
      AppLogger.d('Could not read the pending call: $e');
      return null;
    }
  }

  /// Forgets a ring that has been dealt with, so the app does not pick it up
  /// again on its next start.
  Future<void> _forgetPendingCall() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingCallKey);
    } catch (_) {
      // Nothing recorded.
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
    // A later call with the same id is a different offer and must be allowed
    // to ring again.
    releaseClaim('call:$callId');
    stopRingtone();
    await _forgetPendingCall();
  }

  /// Plays the ringtone in a loop for incoming calls.
  ///
  /// Single point of control for in-app ringing, and it deliberately does
  /// nothing while the app is not in front of the user: the `calls` channel is
  /// already ringing the tray notification in that case. Without this guard the
  /// two overlap and the phone rings twice over, which is what it used to do —
  /// three times, in fact, because the service rang as well as the call screen.
  void playRingtone() {
    if (!appInForeground) return;
    try {
      stopRingtone();
      _ringtonePlayer = AudioPlayer();
      _ringtonePlayer!.setReleaseMode(ReleaseMode.loop);
      _ringtonePlayer!.play(AssetSource(ringtoneAsset), volume: 1.0);
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

  // ---- FCM -----------------------------------------------------------------

  /// Extracts information from an FCM [RemoteMessage] and displays it in the system tray,
  /// while triggering appropriate background controller refreshes.
  ///
  /// Runs on the main isolate for foreground pushes and on the FCM background
  /// isolate for everything else, so nothing here may assume a controller
  /// exists — [_ringFromPush] and [_refreshCorrespondingController] both check.
  Future<void> showFromRemoteMessage(RemoteMessage message) async {
    await init();
    final Map<String, dynamic> data = message.data;
    final String type = (data['type'] ?? '').toString().toLowerCase();

    // ── Incoming call pushed while the socket was down ──────────────────────
    // CRITICAL: Check for call signals FIRST, before the body-empty check.
    // FCM call pushes may be data-only (no notification.body), and the old code
    // returned early and silently dropped every call push when the app was
    // backgrounded or killed.
    if (type == 'call_incoming' || type == 'call_invite') {
      final int? callId = int.tryParse((data['call_id'] ?? '').toString());
      if (callId != null) {
        await _ringFromPush(
          callId,
          callerName: (data['caller_name'] ??
                  message.notification?.title ??
                  data['title'] ??
                  'HamQadam Member')
              .toString(),
          isVideo: (data['call_type'] ?? data['is_video'] ?? '')
              .toString()
              .toLowerCase()
              .contains('video'),
        );
        return;
      }
    }

    // A call that has stopped ringing should take its notification with it,
    // even when the app is asleep — otherwise the tray keeps ringing for a
    // call the caller has already given up on.
    if (type.startsWith('call_') && type != 'call_incoming') {
      final int? callId = int.tryParse((data['call_id'] ?? '').toString());
      if (callId != null) {
        await cancelIncomingCall(callId);
        if (type == 'call_ended' || type == 'call_cancelled') return;
      }
    }

    final String title = message.notification?.title ??
        data['title']?.toString() ??
        'HamQadam';

    final String? body = message.notification?.body ??
        data['message']?.toString() ??
        data['body']?.toString();

    if (body == null || body.isEmpty) {
      _refreshCorrespondingController(data);
      return;
    }

    // ── Chat messages ──────────────────────────────────────────────────────
    // Routed through the grouped, de-duplicated message path so a push and a
    // socket event for the same message cannot both ring.
    final int? messageId = int.tryParse(
      (data['message_id'] ?? data['chat_id'] ?? '').toString(),
    );
    final int? threadId = int.tryParse(
      (data['thread_id'] ?? data['info_id'] ?? '').toString(),
    );
    // `ChatApiService` sends `sender_id`; `NotificationHelper` sends
    // `notify_by`. Both mean the same thing and both arrive for one message.
    final int senderId = int.tryParse(
          (data['sender_id'] ?? data['notify_by'] ?? '').toString(),
        ) ??
        0;

    if ((type.contains('message') || type.contains('chat')) && threadId != null) {
      // The member is already looking at this conversation; the message is on
      // screen and a tray entry would be noise.
      if (_isViewingThread(threadId)) {
        _refreshCorrespondingController(data);
        return;
      }

      if (messageId != null) {
        await showMessageNotification(
          messageId: messageId,
          threadId: threadId,
          senderId: senderId,
          senderName: title,
          body: body,
        );
      } else if (claim(chatContentKey(threadId, body), ttl: contentClaimTtl)) {
        // The second push the server sends for the same message carries no
        // id — it only gets through when the id-carrying one has not arrived,
        // which happens when the pushes are delivered out of order.
        await showMessageNotification(
          // No server id: derive a stable-enough one from the conversation and
          // the text so re-delivery replaces rather than stacks.
          messageId: chatContentKey(threadId, body).hashCode,
          threadId: threadId,
          senderId: senderId,
          senderName: title,
          body: body,
        );
      }
      _refreshCorrespondingController(data);
      return;
    }

    // Everything else. The server's activity pushes carry no notification-row
    // id, so the key is built from the fields the push and the poller share —
    // see [activityKey].
    final int? serverNotificationId = int.tryParse(
      (data['notification_id'] ?? data['id'] ?? '').toString(),
    );
    final int? infoId = int.tryParse((data['info_id'] ?? '').toString());
    final String key = serverNotificationId != null
        ? 'notif:$serverNotificationId'
        : activityKey(type: type, notifyBy: senderId, infoId: infoId);
    if (!claim(key)) return;

    await showNotification(
      id: _activityNotificationId(serverNotificationId ?? key.hashCode),
      title: title,
      body: body,
      payload: jsonEncode(data),
    );

    // Trigger realtime UI / State refreshes based on notification type
    _refreshCorrespondingController(data);
  }

  bool _isViewingThread(int threadId) {
    if (!appInForeground) return false;
    if (!Get.isRegistered<ChatController>()) return false;
    return Get.find<ChatController>().activeThread.value?.id == threadId;
  }

  /// Rings for a call the app learned about from a push rather than from the
  /// live socket.
  ///
  /// On the main isolate the call is re-read first: pushes can be delayed by
  /// Doze for minutes, and a notification that rang for a call the caller had
  /// already given up on would be worse than none.
  ///
  /// On the FCM background isolate there is no GetX container and no session,
  /// so nothing can be re-read — and returning early there is exactly why a
  /// closed app never rang. It rings straight from the payload instead; the
  /// notification's own `timeoutAfter` retires a stale one, and the call screen
  /// checks the call is still live before joining.
  Future<void> _ringFromPush(
    int callId, {
    required String callerName,
    required bool isVideo,
  }) async {
    if (!claim('call:$callId')) return;

    if (Get.isRegistered<CallController>()) {
      await Get.find<CallController>().ringFromPush(callId);
      return;
    }

    AppLogger.i('Ringing call $callId straight from the push (no app isolate).');
    await showIncomingCall(
      callId: callId,
      callerName: callerName,
      isVideo: isVideo,
    );
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
        Get.find<ChatController>().syncFromPush(
          threadId: int.tryParse(
            (data['thread_id'] ?? data['info_id'] ?? '').toString(),
          ),
        );
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

  // ---- Tap routing ---------------------------------------------------------

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
      // `sender_id` from the chat push, `notify_by` from the activity push and
      // the notification row — the same person under two names.
      final int? notifyBy =
          int.tryParse((data['sender_id'] ?? data['notify_by'] ?? '').toString());
      final int? infoId = int.tryParse(data['info_id']?.toString() ?? '');
      final int? threadId =
          int.tryParse(data['thread_id']?.toString() ?? '') ?? infoId;

      // 0. Incoming Call Invitation
      if (type == 'call_incoming' || type == 'call_invite') {
        final int? callId = int.tryParse((data['call_id'] ?? '').toString());
        if (callId != null) {
          _ringFromPush(
            callId,
            callerName: (data['caller_name'] ?? 'HamQadam Member').toString(),
            isVideo: (data['is_video'] ?? data['call_type'] ?? '')
                .toString()
                .toLowerCase()
                .contains(RegExp(r'video|true')),
          );
          return;
        }
      }

      // 1. Chat messages
      if (type.contains('message') || type.contains('chat')) {
        if (threadId != null && threadId > 0) {
          cancelThreadNotifications(threadId);
        }

        if (Get.isRegistered<ChatController>()) {
          final ChatController chatCtrl = Get.find<ChatController>();
          final List<ChatThread> threads =
              chatCtrl.threadsState.value.data ?? <ChatThread>[];

          ChatThread? thread;
          if (threadId != null && threadId > 0) {
            thread = threads.cast<ChatThread?>().firstWhere(
                  (ChatThread? t) => t?.id == threadId,
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
          // The thread is not in the cached inbox yet — this is the first
          // message from someone new. Refresh, then open it if it shows up.
          if (threadId != null && threadId > 0) {
            chatCtrl.openThreadById(threadId, participantId: notifyBy);
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
