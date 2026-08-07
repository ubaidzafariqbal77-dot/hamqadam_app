import '../constants/api_endpoints.dart';
import '../constants/app_constants.dart';
import '../core/api/api_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// All authentication API calls. Controllers depend on this, never on Dio.
class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  /// Step 1 — creates the account and returns the Sanctum token + user.
  Future<AuthResponseModel> register(Map<String, dynamic> payload) async {
    final ApiEnvelope res = await _client.post(ApiEndpoints.register, body: payload);
    return AuthResponseModel.fromJson(res.dataMap);
  }

  Future<AuthResponseModel> loginWithEmail({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.loginEmail,
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'device_name': deviceName,
        'device_type': ApiConfig.deviceType,
      },
    );
    return AuthResponseModel.fromJson(res.dataMap);
  }

  Future<UserModel?> me() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.me);
    final dynamic user = res.dataMap['user'] ?? res.data;
    return user is Map<String, dynamic> ? UserModel.fromJson(user) : null;
  }

  /// Request an OTP to a mobile number.
  Future<String> requestMobileOtp({
    required String phone,
    required String countryCode,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.requestMobileOtp,
      body: <String, dynamic>{'phone': phone, 'country_code': countryCode},
    );
    return res.message;
  }

  /// Login with a mobile OTP.
  Future<AuthResponseModel> loginWithMobileOtp({
    required String phone,
    required String countryCode,
    required String otp,
    required String deviceName,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.loginMobile,
      body: <String, dynamic>{
        'phone': phone,
        'country_code': countryCode,
        // Backend expects the OTP under `code` (verified).
        'code': otp,
        'device_name': deviceName,
        'device_type': ApiConfig.deviceType,
      },
    );
    return AuthResponseModel.fromJson(res.dataMap);
  }

  /// Login with a Google ID token (obtained from the Google Sign-In SDK).
  Future<AuthResponseModel> loginWithGoogle({
    required String idToken,
    required String deviceName,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.loginGoogle,
      body: <String, dynamic>{'id_token': idToken, 'device_name': deviceName},
    );
    return AuthResponseModel.fromJson(res.dataMap);
  }

  Future<void> logout() => _client.post(ApiEndpoints.logout);

  Future<void> logoutAll() => _client.post(ApiEndpoints.logoutAll);

  /// Deactivates (soft-deletes) the current account.
  Future<void> deactivateAccount() => _client.delete(ApiEndpoints.deleteAccount);

  /// Sends a password-reset OTP. The live API expects `identifier` + `channel`
  /// (verified) rather than a bare `email`.
  Future<String> forgotPassword(String email, {String channel = 'email'}) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.forgotPassword,
      body: <String, dynamic>{'identifier': email, 'channel': channel},
    );
    return res.message;
  }

  /// Resets the password using the OTP. Live fields: identifier, channel,
  /// `code` (the OTP), password, password_confirmation (verified).
  Future<String> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
    String channel = 'email',
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.resetPassword,
      body: <String, dynamic>{
        'identifier': email,
        'channel': channel,
        'code': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    return res.message;
  }
}
