import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

import '../core/services/notification_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/app_logger.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationController extends GetxController {
  final NotificationRepository _repository;

  NotificationController(this._repository);

  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxInt unreadCount = 0.obs;

  dynamic _pushTokenRecordId;

  int _currentPage = 1;
  int _lastPage = 1;

  /// Set of notification IDs already shown in the device tray, so we never
  /// ring the same notification twice.
  final Set<int> _shownInTray = <int>{};

  /// Polls the backend every 15 seconds and shows new unread notifications
  /// in the device notification tray — messages, interests, proposals, profile
  /// views, coin usage, etc.
  Timer? _trayPoller;

  bool get _hasToken =>
      Get.isRegistered<SecureStorageService>() &&
      Get.find<SecureStorageService>().hasToken;

  @override
  void onInit() {
    super.onInit();
    if (_hasToken) {
      AppLogger.i('NotificationController: starting tray poller (hasToken=true)');
      fetchNotifications();
      _startTrayPoller();
    } else {
      AppLogger.w('NotificationController: NO token — tray poller NOT started');
    }
  }

  @override
  void onClose() {
    _trayPoller?.cancel();
    super.onClose();
  }

  void reset() {
    notifications.clear();
    unreadCount.value = 0;
    _currentPage = 1;
    _lastPage = 1;
    _pushTokenRecordId = null;
    _shownInTray.clear();
    _trayPoller?.cancel();
  }

  /// Sends the FCM push token to the backend API (`POST /notifications/push-tokens`).
  Future<void> syncPushToken(String token) async {
    if (!_hasToken || token.isEmpty) return;
    try {
      final String deviceType = Platform.isIOS ? 'ios' : 'android';
      final dynamic res = await _repository.registerPushToken(
        token: token,
        deviceType: deviceType,
      );
      if (res is Map && res['id'] != null) {
        _pushTokenRecordId = res['id'];
      }
      AppLogger.i('FCM Push Token synced to backend successfully (device: $deviceType)');
    } catch (e) {
      AppLogger.w('Failed to sync push token with backend: $e');
    }
  }

  /// Deletes the FCM push token from backend on logout (`DELETE /notifications/push-tokens/{id}`).
  Future<void> deletePushToken() async {
    if (_pushTokenRecordId == null) return;
    try {
      await _repository.deletePushToken(_pushTokenRecordId);
      _pushTokenRecordId = null;
      AppLogger.i('FCM Push Token deleted from backend successfully');
    } catch (e) {
      AppLogger.w('Failed to delete push token from backend: $e');
    }
  }

  // ── Tray Poller ──────────────────────────────────────────────────────────

  /// Starts a periodic poller that fetches the latest unread notifications
  /// and displays them in the device notification tray.
  void _startTrayPoller() {
    _trayPoller?.cancel();
    _trayPoller = Timer.periodic(const Duration(seconds: 15), (_) {
      _pollAndShowInTray();
    });
  }

  /// Fetches the latest unread notifications and shows each new one in the
  /// device tray as a local notification. Covers messages, interests,
  /// proposals, profile views, coin usage, and all other activity types.
  Future<void> _pollAndShowInTray() async {
    if (!_hasToken) return;
    try {
      final pageData = await _repository.getNotifications(page: 1);
      final List<NotificationModel> unread = pageData.notifications
          .where((NotificationModel n) => !n.isRead)
          .toList();

      AppLogger.d('Tray poller: ${pageData.notifications.length} total, ${unread.length} unread, ${unreadCount.value} badge');

      for (final NotificationModel notif in unread) {
        if (_shownInTray.contains(notif.id)) continue;
        _shownInTray.add(notif.id);

        // Show in device notification tray
        final String title = notif.title.isNotEmpty ? notif.title : 'HamQadam';
        final String body = notif.message.isNotEmpty
            ? notif.message
            : _defaultBody(notif.type);

        AppLogger.i('Tray: showing notification #${notif.id} [$title] $body');

        await NotificationService.instance.showNotification(
          id: notif.id,
          title: title,
          body: body,
          payload: notif.deepLink ?? notif.type,
        );
      }

      // Update badge count
      unreadCount.value = pageData.unreadCount;
    } catch (e) {
      AppLogger.w('Tray poller error: $e');
    }
  }

  /// Human-readable default body for notification types without a message.
  String _defaultBody(String type) {
    final String t = type.toLowerCase();
    if (t.contains('message') || t.contains('chat')) return 'You have a new message';
    if (t.contains('interest')) return 'You have a new interest';
    if (t.contains('proposal')) return 'You have a new proposal';
    if (t.contains('profile_view') || t.contains('view')) return 'Someone viewed your profile';
    if (t.contains('coin') || t.contains('payment')) return 'Coin activity on your account';
    if (t.contains('call')) return 'Missed call';
    return 'You have a new notification';
  }

  // ── Fetch / Pagination ──────────────────────────────────────────────────

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (!_hasToken) return;

    if (refresh) {
      _currentPage = 1;
      isLoading.value = true;
    } else {
      if (_currentPage > _lastPage) return;
      isLoadingMore.value = true;
    }

    try {
      final pageData = await _repository.getNotifications(page: _currentPage);
      if (refresh) {
        notifications.assignAll(pageData.notifications);
      } else {
        notifications.addAll(pageData.notifications);
      }
      unreadCount.value = pageData.unreadCount;
      _lastPage = pageData.lastPage;
      _currentPage++;
    } catch (e) {
      AppLogger.w('Failed to fetch notifications: $e');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final success = await _repository.markAllAsRead();
      if (success) {
        for (var i = 0; i < notifications.length; i++) {
          notifications[i] = NotificationModel(
            id: notifications[i].id,
            type: notifications[i].type,
            title: notifications[i].title,
            message: notifications[i].message,
            deepLink: notifications[i].deepLink,
            notifyBy: notifications[i].notifyBy,
            infoId: notifications[i].infoId,
            payload: notifications[i].payload,
            readAt: DateTime.now(),
            createdAt: notifications[i].createdAt,
          );
        }
        unreadCount.value = 0;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to mark all as read');
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final index = notifications.indexWhere((element) => element.id == id);
      if (index != -1 && !notifications[index].isRead) {
        final success = await _repository.markAsRead(id);
        if (success) {
          notifications[index] = NotificationModel(
            id: notifications[index].id,
            type: notifications[index].type,
            title: notifications[index].title,
            message: notifications[index].message,
            deepLink: notifications[index].deepLink,
            notifyBy: notifications[index].notifyBy,
            infoId: notifications[index].infoId,
            payload: notifications[index].payload,
            readAt: DateTime.now(),
            createdAt: notifications[index].createdAt,
          );
          if (unreadCount.value > 0) {
            unreadCount.value--;
          }
        }
      }
    } catch (e) {
      // Background operation, silently fail
    }
  }
}
