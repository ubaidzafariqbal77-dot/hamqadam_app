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
import 'core/services/notification_service.dart';
import 'core/services/permissions_service.dart';
import 'core/services/push_token_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
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

  // Initialize Local Notifications (Channel, Permissions, Tray display)
  await NotificationService.instance.init();

  // Register background message handler.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request ALL permissions at app start (camera, mic, photos, notifications, contacts)
  // so the user is never prompted mid-action.
  await PermissionsService.instance.requestAll();

  // Also request Firebase-specific notification permissions (iOS / macOS).
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    AppLogger.w('Firebase Messaging permission request failed: $e');
  }

  // ── App dependencies ────────────────────────────────────────────────────
  // Everything below needs the container, so nothing touches a controller
  // before this line — which is exactly the race that used to leave the
  // backend without this device's push token on a warm start.
  await AppDependencies.init();

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

  runApp(const HamQadamApp());

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
  });
}

class HamQadamApp extends StatelessWidget {
  const HamQadamApp({super.key});

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
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        defaultTransition: Transition.cupertino,
      ),
    );
  }
}
