import 'package:get/get.dart';

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
