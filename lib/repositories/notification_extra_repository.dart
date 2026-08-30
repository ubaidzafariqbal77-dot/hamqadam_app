import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';

/// Extra notification endpoints: unread count and preferences.
class NotificationExtraRepository {
  NotificationExtraRepository(this._client);

  final ApiClient _client;

  /// `GET /notifications/unread-count` — quick unread badge count.
  Future<int> fetchUnreadCount() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.notificationsUnreadCount);
    return (res.dataMap['unread_count'] as int?) ?? 0;
  }

  /// `GET /notifications/preferences` — current notification preferences.
  Future<Map<String, dynamic>> fetchPreferences() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.notificationsPreferences);
    return res.dataMap;
  }

  /// `PATCH /notifications/preferences` — update notification preferences.
  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> body) async {
    final ApiEnvelope res = await _client.patch(
      ApiEndpoints.notificationsPreferences,
      body: body,
    );
    return res.dataMap;
  }
}
