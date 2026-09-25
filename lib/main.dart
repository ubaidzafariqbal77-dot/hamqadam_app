import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'constants/app_strings.dart';
import 'controllers/notification_controller.dart';
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

 
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Already initialised for this isolate.
  }

 
  NotificationService.instance.appInForeground = false;
  await NotificationService.instance.init();

  final String type = (message.data['type'] ?? '').toString().toLowerCase();
 
  AppLogger.push(
    'background isolate woke: type="$type" '
    'notification=${message.notification != null} '
    'data=${message.data.keys.toList()}',
  );

 
  if (type.startsWith('call')) {
    await NotificationService.instance.showFromRemoteMessage(message);
    return;
  }

 
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
 
  await NotificationService.instance.init();

  // Register background message handler.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

 
  await AppDependencies.init();

 
  CallWindowService.instance.init();

 
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
 
    NotificationService.instance.handleLaunchDetails();

 
    _requestStartupPermissions();
  });
}

  
/// and [PermissionsService.notificationsBlocked] lets the UI explain itself
 
Future<void> _requestStartupPermissions() async {
  await PermissionsService.instance.requestNotifications();

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
    // Light theme only, and no `themeMode`: the app has no dark theme to fall
    // back to, so a device set to dark still opens the rose canvas.
    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: initialRoute,
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
    );
  }
}
