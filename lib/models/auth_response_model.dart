import 'user_model.dart';

/// Parsed `data` node of a successful auth response.
///
/// The live API returns the Sanctum token as `access_token` (with
/// `token_type`, `expires_at`, `device_session_id`) and the user under `user`.
/// `token` is accepted as a fallback for forward/backward compatibility.
class AuthResponseModel {
  const AuthResponseModel({required this.token, this.tokenType, this.user});

  final String token;
  final String? tokenType;
  final UserModel? user;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawUser = json['user'];
    return AuthResponseModel(
      token: (json['access_token'] ?? json['token'] ?? '').toString(),
      tokenType: json['token_type']?.toString(),
      user: rawUser is Map<String, dynamic> ? UserModel.fromJson(rawUser) : null,
    );
  }

  bool get hasToken => token.isNotEmpty;
}
