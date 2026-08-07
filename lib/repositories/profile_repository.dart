import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/profile_model.dart';

/// Profile API calls. Controllers depend on this, never on Dio.
class ProfileRepository {
  ProfileRepository(this._client);

  final ApiClient _client;

  /// `GET /profile` — the authenticated member's full profile.
  Future<ProfileModel> fetchProfile() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.profile);
    return ProfileModel.fromJson(res.dataMap);
  }

  /// `PUT /profile` — updates the member's profile and returns the fresh copy.
  Future<ProfileModel> updateProfile(Map<String, dynamic> body) async {
    final ApiEnvelope res = await _client.put(ApiEndpoints.profile, body: body);
    return ProfileModel.fromJson(res.dataMap);
  }
}
