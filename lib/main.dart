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
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If the message has data but no notification payload on Android, show local notification
  if (message.notification == null && message.data.isNotEmpty) {
    await NotificationService.instance.init();
    await NotificationService.instance.showFromRemoteMessage(message);
  }
}

/// Safely attempts to fetch FCM token on startup and on token refresh.
void _initFCMToken() {
  FirebaseMessaging.instance.getToken().then((String? token) {
    // ignore: avoid_print
    print('🔑 FCM Token: $token');
    if (token != null && token.isNotEmpty) {
      NotificationService.instance.updateFcmToken(token);
    }
  }).catchError((Object error) {
    // ignore: avoid_print
    print('ℹ️ APNS/FCM token pending or running on iOS Simulator: $error');
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
    // ignore: avoid_print
    print('🔄 Refreshed FCM Token: $token');
    if (token.isNotEmpty) {
      NotificationService.instance.updateFcmToken(token);
    }
  });
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

  // Request notification permissions (iOS / macOS / Android 13+).
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Safely retrieve & print FCM token asynchronously
    _initFCMToken();
  } catch (e) {
    // ignore: avoid_print
    print('⚠️ Firebase Messaging Permission/Init Error: $e');
  }

  // ── App dependencies ────────────────────────────────────────────────────
  await AppDependencies.init();

  // ── FCM foreground listeners ────────────────────────────────────────────
  // When a push arrives in foreground: show notification in mobile system tray & refresh list
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService.instance.showFromRemoteMessage(message);
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().fetchNotifications(refresh: true);
    }
  });

  // When user taps a notification and app is in background (not terminated).
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().fetchNotifications(refresh: true);
    }
    // Check if this is a call invite signal in the data payload
    final String msgText = (message.data['message'] ?? '').toString();
    if (msgText.startsWith('[CALL_INVITE:') || msgText.startsWith('[CALL_DECLINED:')) {
      // Show incoming call overlay directly
      NotificationService.instance.showFromRemoteMessage(message);
      return;
    }
    NotificationService.instance.handleRemoteMessageTap(message);
  });


  // When app is launched from a terminated state via notification tap.
  final RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.handleRemoteMessageTap(initialMessage);
    });
  }


  runApp(const HamQadamApp());
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
