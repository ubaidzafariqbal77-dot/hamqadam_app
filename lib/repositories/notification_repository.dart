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
}
