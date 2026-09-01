import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  Future<NotificationPage> getNotifications({int page = 1}) async {
    final response = await _apiClient.get(
      ApiEndpoints.notifications,
      query: {'page': page},
    );
    if (response.success) {
      return NotificationPage.fromJson(
        response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{},
      );
    }
    throw Exception(response.message.isNotEmpty ? response.message : 'Failed to load notifications');
  }

  Future<bool> markAllAsRead() async {
    final response = await _apiClient.post(ApiEndpoints.notificationsMarkAllRead);
    return response.success;
  }

  Future<bool> markAsRead(int id) async {
    final response = await _apiClient.post(ApiEndpoints.notificationRead(id));
    return response.success;
  }

  /// Registers the device's FCM push token (`POST /notifications/push-tokens`).
  Future<dynamic> registerPushToken({
    required String token,
    required String deviceType,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.pushTokens,
      body: <String, dynamic>{
        'token': token,
        // `StorePushTokenRequest` validates `platform`; `device_type` was the
        // app's own name for it, so the column was always saved null. Both are
        // sent so an older backend keeps working.
        'platform': deviceType,
        'device_type': deviceType,
      },
    );
    if (response.success) {
      return response.data;
    }
    return null;
  }

  /// Deletes the device's push token on logout (`DELETE /notifications/push-tokens/{id}`).
  Future<bool> deletePushToken(dynamic id) async {
    if (id == null) return false;
    final response = await _apiClient.delete(ApiEndpoints.pushTokenDelete(id));
    return response.success;
  }
}

