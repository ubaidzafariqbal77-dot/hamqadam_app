import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';

/// Device session info.
class DeviceSession {
  const DeviceSession({
    required this.id,
    this.platform,
    this.deviceId,
    this.lastUsedAt,
  });

  final int id;
  final String? platform;
  final String? deviceId;
  final DateTime? lastUsedAt;

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: (json['id'] as int?) ?? 0,
      platform: json['platform']?.toString(),
      deviceId: json['device_id']?.toString(),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'].toString())
          : null,
    );
  }
}

/// Extra auth endpoints: devices, email verification.
class AuthExtraRepository {
  AuthExtraRepository(this._client);

  final ApiClient _client;

  /// `GET /auth/devices` — list active device sessions.
  Future<List<DeviceSession>> fetchDevices() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.authDevices);
    final List<dynamic> raw = res.dataList;
    return raw
        .whereType<Map<String, dynamic>>()
        .map(DeviceSession.fromJson)
        .toList();
  }

  /// `POST /auth/email/verification-code` — request email verification code.
  Future<String> requestEmailVerification({String? email}) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.authEmailVerificationCode,
      body: <String, dynamic>{
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return res.message;
  }

  /// `POST /auth/email/verify` — verify email with code.
  Future<Map<String, dynamic>> verifyEmail({
    required String code,
    String? email,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.authEmailVerify,
      body: <String, dynamic>{
        'code': code,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return res.dataMap;
  }
}
