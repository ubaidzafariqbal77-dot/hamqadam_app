import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';
import '../../features/chat/views/chat_conversation_view.dart';
import '../../features/chat/views/chat_inbox_view.dart';
import '../../features/notifications/views/notifications_view.dart';
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

  bool _isInitialized = false;

  /// Initializes local notifications plugin and creates Android notification channels.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Android channel creation
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_channel);
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
  }

  /// Extracts information from an FCM [RemoteMessage] and displays it in the system tray.
  Future<void> showFromRemoteMessage(RemoteMessage message) async {
    final String title = message.notification?.title ??
        message.data['title']?.toString() ??
        'HamQadam';

    final String? body = message.notification?.body ??
        message.data['message']?.toString() ??
        message.data['body']?.toString();

    if (body == null || body.isEmpty) return;

    final int id = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final String payload = jsonEncode(message.data);

    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Handles routing when a user taps on a notification in the tray.
  void _handleNotificationPayload(String? payloadStr) {
    if (payloadStr == null || payloadStr.isEmpty) {
      Get.to(() => const NotificationsView());
      return;
    }

    try {
      final Map<String, dynamic> data = jsonDecode(payloadStr) as Map<String, dynamic>;
      final String? type = data['type']?.toString();
      final int? notifyBy = int.tryParse(data['notify_by']?.toString() ?? '');
      final int? infoId = int.tryParse(data['info_id']?.toString() ?? '');

      if (type == 'new_message' || type == 'chat_message' || type == 'message') {
        if (Get.isRegistered<ChatController>()) {
          final ChatController chatCtrl = Get.find<ChatController>();
          final List<ChatThread> threads = chatCtrl.threadsState.value.data ?? <ChatThread>[];

          ChatThread? thread;
          if (infoId != null && infoId > 0) {
            thread = threads.cast<ChatThread?>().firstWhere((t) => t?.id == infoId, orElse: () => null);
          }
          if (thread == null && notifyBy != null && notifyBy > 0) {
            thread = threads.cast<ChatThread?>().firstWhere((t) => t?.participant.id == notifyBy, orElse: () => null);
          }

          if (thread != null) {
            ChatConversationView.open(thread);
            return;
          }
        }
        Get.to(() => const ChatInboxView());
        return;
      }

      // Default: Navigate to Notifications View
      Get.to(() => const NotificationsView());
    } catch (e) {
      AppLogger.w('Failed to parse notification payload: $e');
      Get.to(() => const NotificationsView());
    }
  }
}
