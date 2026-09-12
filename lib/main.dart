import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'constants/app_strings.dart';
import 'controllers/notification_controller.dart';
import 'controllers/theme_controller.dart';
import 'core/dependency/app_dependencies.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/services/call_window_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/permissions_service.dart';
import 'core/services/push_token_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'features/chat/views/incoming_call_screen.dart';
import 'firebase_options.dart';

/// Background message handler — must be a top-level function.
///
/// Runs in its own isolate, with no GetX container, no session and no UI. It is
/// the *only* code that runs when a push arrives at a killed or backgrounded
/// app, so what it does or does not do decides whether the phone rings.
///
/// It used to be gated on `message.notification == null`, and the server sends
/// every push with a notification block — so this handler did nothing at all,
/// ever. That is why a closed app never rang for a call.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Already initialised for this isolate.
  }

  // This isolate is by definition not in front of the user, so the tray is
  // what has to make the noise.
  NotificationService.instance.appInForeground = false;
  await NotificationService.instance.init();

  final String type = (message.data['type'] ?? '').toString().toLowerCase();
  // Proof, readable on any tester's release build, that the push reached a
  // closed app — the step everyone assumed was broken.
  AppLogger.push(
    'background isolate woke: type="$type" '
    'notification=${message.notification != null} '
    'data=${message.data.keys.toList()}',
  );

  // A call has to be handled here whatever else is in the payload: only our own
  // notification carries the Accept / Decline actions and the full-screen
  // intent that rings a locked phone.
  if (type.startsWith('call')) {
    await NotificationService.instance.showFromRemoteMessage(message);
    return;
  }

  // For anything else, a push that carries a `notification` block is displayed
  // by the system itself — showing a second copy would double every alert.
  if (message.notification == null && message.data.isNotEmpty) {
    await NotificationService.instance.showFromRemoteMessage(message);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ────────────────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Channels and the tap handler only — deliberately NO permission prompts.
  //
  // Every prompt used to happen here, before `runApp()`, and that is what made
  // a freshly installed app unreachable while it was closed. Measured on a
  // clean install (Infinix X6853, Android 15, release build): the process came
  // up, and for the next 20+ seconds the member looked at a **black window
  // with an app icon** — no Flutter UI, because `runApp()` had not been
  // reached — while six system dialogs queued up in front of it, one after
  // another: notifications, camera, microphone, photos, videos, contacts.
  //
  // Three separate defects came out of that one ordering mistake:
  //
  //  * **Push died for the whole install.** The very first dialog is
  //    POST_NOTIFICATIONS, thrown at somebody who has not yet seen a single
  //    screen of the app. "Don't allow" there is the natural answer, and it is
  //    permanent: Android then drops every tray notification, so messages and
  //    calls arrive only while the app is open and the Pusher socket is
  //    carrying them. That is exactly the reported symptom — "sirf foreground
  //    me" on every new device — and it looked like a server bug for weeks.
  //  * **Back closed the app.** There is no route behind those dialogs, so
  //    dismissing one exits the process.
  //  * **The screen looked dead / switched off.** 20 s of black window.
  //
  // The old test device hid all of it: Transsion's OEM layer auto-answers
  // permission prompts (and auto-adds the battery exemption), so on that one
  // phone everything was granted without anyone tapping "Allow". That is the
  // whole reason this "worked when it was set up" and never worked again.
  //
  // So: nothing that can show UI runs before `runApp()`. Permissions are asked
  // after the first frame, with the app behind them — see [_requestStartupPermissions].
  await NotificationService.instance.init();

  // Register background message handler.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── App dependencies ────────────────────────────────────────────────────
  // Everything below needs the container, so nothing touches a controller
  // before this line — which is exactly the race that used to leave the
  // backend without this device's push token on a warm start.
  await AppDependencies.init();

  // ── Where a live call goes when the member looks away ───────────────────
  // Listens for the two things the platform reports back: Android putting the
  // app into its picture-in-picture window, and "End call" tapped on the
  // ongoing-call notification. Registered after the container so the handler
  // can reach CallController.
  CallWindowService.instance.init();

  // ── Did a call wake this process up? ────────────────────────────────────
  // FIRST, before any service starts. `AppLifecycleService.start()` below runs
  // a recovery pass that calls `takePendingIncomingCall()`, and that *consumes*
  // the record — so asking after it always came back empty, and the ringing
  // screen could never be the initial route. Measured: every cold start logged
  // "pending-call check: none" while the push isolate had written the record a
  // second earlier.
  //
  // The answer decides the app's *initial* route. A call arriving at a killed
  // app used to boot the normal way — splash for 1.4 s, then `Get.offAllNamed`
  // to Discover — with the ringing screen pushed somewhere in the middle of
  // that, so `offAllNamed` tore it straight back down: the member watched a
  // splash, landed on Discover, and heard the tray ringing beside them with no
  // way to answer. Now the ring is a route, and when one is pending it is the
  // first thing built — no splash, Accept and Decline on the first frame.
  final PendingCall? pendingCall =
      await NotificationService.instance.peekPendingIncomingCall();
  AppLogger.push('startup pending-call check: '
      '${pendingCall == null ? 'none' : 'call ${pendingCall.callId}'}');
  if (pendingCall != null) {
    IncomingCallScreen.launchArguments = <String, dynamic>{
      'callId': pendingCall.callId,
      'callerName': pendingCall.callerName,
      'isVideoCall': pendingCall.isVideo,
      'launchedTheApp': true,
    };
  }

  // ── Push token ──────────────────────────────────────────────────────────
  // Started after the container exists, and it retries until FCM (and, on iOS,
  // APNs) actually hands one over.
  Get.find<PushTokenService>().start();

  // ── Foreground / resume recovery ────────────────────────────────────────
  Get.find<AppLifecycleService>().start();

  // ── FCM foreground listeners ────────────────────────────────────────────
  // A push that arrives while the app is open goes through the same de-duplicated
  // path as the socket event for the same thing, so only one of them shows.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService.instance.showFromRemoteMessage(message);
  });

  // When user taps a notification and app is in background (not terminated).
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().fetchNotifications(refresh: true);
    }
    // A call push must ring, not route: `showFromRemoteMessage` re-reads the
    // call and puts the incoming screen up if it is still live.
    if ((message.data['type'] ?? '').toString().toLowerCase().startsWith('call')) {
      NotificationService.instance.showFromRemoteMessage(message);
      return;
    }
    NotificationService.instance.handleRemoteMessageTap(message);
  });

  // When app is launched from a terminated state via notification tap.
  final RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  runApp(HamQadamApp(
    initialRoute:
        pendingCall != null ? AppRoutes.incomingCall : AppRoutes.splash,
  ));

  // Deferred to the first frame so the navigator exists before anything tries
  // to route or open a dialog.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (initialMessage != null) {
      NotificationService.instance.handleRemoteMessageTap(initialMessage);
    }
    // Accept / Decline tapped on a ringing notification for an app that was
    // not running: the plugin's response callback never fires for that launch,
    // so the action has to be replayed from the launch details or the answer is
    // silently dropped.
    NotificationService.instance.handleLaunchDetails();

    // Last, and not awaited by anything above: the one prompt push actually
    // depends on, now that there is a frame behind it to dismiss back onto.
    _requestStartupPermissions();
  });
}

/// Asks for notification permission once the UI is up.
///
/// Only notifications, and only here. The rest of what [PermissionsService]
/// used to request at launch was either redundant or unused:
///
/// * camera and microphone are requested by `video_call_screen.dart` when a
///   call actually starts, which is where the member can see why they are
///   being asked;
/// * photos and videos are requested by `image_picker` / `file_picker` when a
///   picker is opened — see `MediaPickerHelper`;
/// * contacts was requested for a feature that does not exist. Nothing in the
///   app reads a contact, and `READ_CONTACTS` is not even in the manifest, so
///   the prompt could never be granted. It bought one more dialog in front of
///   a black screen, and on a store submission it buys a policy question.
///
/// Notifications are different: nothing else in the app can ask for them, and
/// without them a closed app is unreachable — so this one is asked up front,
/// and [PermissionsService.notificationsBlocked] lets the UI explain itself
/// later if the answer was no.
Future<void> _requestStartupPermissions() async {
  await PermissionsService.instance.requestNotifications();

  // iOS/macOS route notification permission through APNs rather than a
  // runtime permission, so this is the call that matters there. On Android it
  // is a no-op once POST_NOTIFICATIONS has been answered above.
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    AppLogger.w('Firebase Messaging permission request failed: $e');
  }
}

class HamQadamApp extends StatelessWidget {
  const HamQadamApp({required this.initialRoute, super.key});

  /// Normally the splash; the ringing screen when a call woke the process.
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = Get.find<ThemeController>();
    // Reactive themeMode: switching in the drawer rebuilds MaterialApp with the
    // new mode. The navigator is preserved (stable GetX key), so routes/state
    // are not lost. All colours come from AppTheme.light / AppTheme.dark.
    return Obx(
      () => GetMaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: theme.mode.value,
        initialRoute: initialRoute,
        getPages: AppPages.pages,
        defaultTransition: Transition.cupertino,
      ),
    );
  }
}
