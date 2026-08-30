import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';

/// Safety/trust API calls: report, block, mute, restrict.
class SafetyRepository {
  SafetyRepository(this._client);

  final ApiClient _client;

  /// `POST /safety/report` — report a user.
  Future<void> report({
    required int userId,
    required String reason,
    String severity = 'medium',
  }) async {
    await _client.post(
      ApiEndpoints.safetyReport,
      body: <String, dynamic>{
        'user_id': userId,
        'reason': reason,
        'severity': severity,
      },
    );
  }

  /// `POST /safety/block` — block a user.
  Future<void> block({required int userId, String? reason}) async {
    await _client.post(
      ApiEndpoints.safetyBlock,
      body: <String, dynamic>{
        'user_id': userId,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// `POST /safety/mute` — mute a user.
  Future<void> mute({required int userId, String? reason}) async {
    await _client.post(
      ApiEndpoints.safetyMute,
      body: <String, dynamic>{
        'user_id': userId,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// `POST /safety/restrict` — restrict a user.
  Future<void> restrict({required int userId, String? reason}) async {
    await _client.post(
      ApiEndpoints.safetyRestrict,
      body: <String, dynamic>{
        'user_id': userId,
        if (reason != null) 'reason': reason,
      },
    );
  }
}
