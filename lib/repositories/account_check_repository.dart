import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../exceptions/app_exceptions.dart';

/// Result of a registration-time availability check.
class AccountCheckResult {
  const AccountCheckResult({required this.available, this.message});

  final bool available;
  final String? message;
}

/// Registration availability checks + in-app password change.
///
/// `check` is public on the backend (no token needed — a fresh registrant has
/// none yet), `changePassword` requires the bearer token like every other
/// authenticated endpoint.
class AccountCheckRepository {
  AccountCheckRepository(this._client);

  final ApiClient _client;

  /// `POST /auth/check` — `{ type: email|phone|cnic, value }`.
  Future<AccountCheckResult> check({
    required String type,
    required String value,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.accountCheck,
      body: <String, dynamic>{'type': type, 'value': value},
      authenticated: false,
    );
    final Map<String, dynamic> data = res.dataMap;
    return AccountCheckResult(
      available: data['available'] == true,
      message: data['message']?.toString(),
    );
  }

  /// `POST /auth/change-password` — throws [AppException] with field errors
  /// when the current password is wrong (the caller shows it inline).
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.changePassword,
      body: <String, dynamic>{
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      },
    );
    return res.message;
  }
}
