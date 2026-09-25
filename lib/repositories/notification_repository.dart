import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/notification_model.dart';

/// Result of marking one notification read. [notification] is the server's
/// canonical row (may be null on success without a body); [unreadCount] is the
/// backend's total of unread rows for this member, so the app badge and the
/// All/Unread tabs stay in step with the server instead of guessing.
class MarkReadResult {
  const MarkReadResult({this.notification, required this.unreadCount});

  final NotificationModel? notification;
  final int unreadCount;
}

class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  Future<NotificationPage> getNotifications({int page = 1, bool unreadOnly = false}) async {
    final response = await _apiClient.get(
      ApiEndpoints.notifications,
      query: <String, dynamic>{
        'page': page,
        if (unreadOnly) 'unread_only': 1,
      },
    );
    if (response.success) {
      // response.raw contains the full envelope {data, meta, links} whereas
      // response.data has already been unwrapped to just the data payload.
      final Map<String, dynamic> body = response.raw is Map<String, dynamic>
          ? response.raw as Map<String, dynamic>
          : response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};
      return NotificationPage.fromJson(body);
    }
    throw Exception(response.message.isNotEmpty ? response.message : 'Failed to load notifications');
  }

  Future<bool> markAllAsRead() async {
    final response = await _apiClient.post(ApiEndpoints.notificationsMarkAllRead);
    return response.success;
  }

  /// Marks one notification read. Success alone is enough for the optimistic
  /// path; [unreadCount] only feeds the badge sync when the server echoes it.
  Future<MarkReadResult> markAsRead(int id) async {
    final response = await _apiClient.post(ApiEndpoints.notificationRead(id));
    if (!response.success) {
      throw Exception(response.message.isNotEmpty ? response.message : 'Failed to mark notification as read');
    }
    final dynamic raw = response.data;
    NotificationModel? row;
    int count = 0;
    if (raw is Map<String, dynamic>) {
      // V1 shape: data = the notification row itself (+ unread_count beside it).
      // Defensive: some deployments nest it under `notification` or `data`.
      final Map<String, dynamic>? rowJson = raw['id'] != null
          ? raw
          : raw['notification'] is Map<String, dynamic>
              ? raw['notification'] as Map<String, dynamic>
              : raw['data'] is Map<String, dynamic>
                  ? raw['data'] as Map<String, dynamic>
                  : null;
      if (rowJson != null) row = NotificationModel.fromJson(rowJson);
      final dynamic countRaw = raw['unread_count'] ?? (raw['meta'] is Map<String, dynamic> ? (raw['meta'] as Map<String, dynamic>)['unread_count'] : null);
      if (countRaw is int) count = countRaw;
      if (countRaw is String) count = int.tryParse(countRaw) ?? 0;
    }
    return MarkReadResult(notification: row, unreadCount: count);
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
