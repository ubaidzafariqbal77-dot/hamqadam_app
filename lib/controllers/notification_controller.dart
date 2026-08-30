import 'package:get/get.dart';

import 'dart:io';

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

  bool get _hasToken =>
      Get.isRegistered<SecureStorageService>() &&
      Get.find<SecureStorageService>().hasToken;

  @override
  void onInit() {
    super.onInit();
    if (_hasToken) {
      fetchNotifications();
    }
  }

  void reset() {
    notifications.clear();
    unreadCount.value = 0;
    _currentPage = 1;
    _lastPage = 1;
    _pushTokenRecordId = null;
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
