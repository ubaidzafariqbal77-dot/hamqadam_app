import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/privacy_settings_model.dart';
import '../models/profile_model.dart';
import '../models/public_profile_model.dart';

/// Profile API calls. Controllers depend on this, never on Dio.
class ProfileRepository {
  ProfileRepository(this._client);

  final ApiClient _client;

  /// `GET /profile` — the authenticated member's full profile.
  ///
  /// Returns everything registration collected, grouped by area
  /// (religion_and_language, caste, location, education, career, physical,
  /// lifestyle_and_interests, family, marriage_expectations, photos,
  /// verification, registration) alongside the original `user` / `member` /
  /// `privacy` keys.
  Future<ProfileModel> fetchProfile() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.profile);
    return ProfileModel.fromJson(res.dataMap);
  }

  /// `PUT /profile` — updates the member's profile and returns the fresh copy.
  ///
  /// Every field is `sometimes` on the server, so send only what changed: a
  /// partial body never blanks a field that was left out. Keys are the flat
  /// registration names (`religion_id`, `area`, `job_title`, `diet`, `hobbies`,
  /// `father_occupation`, …), not the nested read shape.
  Future<ProfileModel> updateProfile(Map<String, dynamic> body) async {
    final ApiEnvelope res = await _client.put(ApiEndpoints.profile, body: body);
    return ProfileModel.fromJson(res.dataMap);
  }

  /// `PATCH /profile/privacy` — returns the privacy block only, not the profile.
  Future<PrivacySettingsModel> updatePrivacy(Map<String, dynamic> body) async {
    final ApiEnvelope res = await _client.patch(ApiEndpoints.profilePrivacy, body: body);
    return PrivacySettingsModel.fromJson(res.dataMap);
  }

  /// `PATCH /profile/visibility` — hides or shows the profile in search and
  /// matches. Returns the full profile, so the caller can refresh from it.
  Future<ProfileModel> updateVisibility({required bool hideProfile}) async {
    final ApiEnvelope res = await _client.patch(
      ApiEndpoints.profileVisibility,
      body: <String, dynamic>{'hide_profile': hideProfile},
    );
    return ProfileModel.fromJson(res.dataMap);
  }

  /// `POST /profile/deactivate` — deactivates the account.
  ///
  /// Irreversible from the app's side: the member is removed from search and
  /// matching and has to be reactivated by support. Confirm before calling.
  Future<String> deactivate() async {
    final ApiEnvelope res = await _client.post(ApiEndpoints.profileDeactivate);
    return res.message;
  }

  /// `GET /profiles/{id}` — another member's profile.
  ///
  /// Carries a verification BADGE only (`identity_verified`, `verified_at`);
  /// the AI internals belong to the owner and are not returned here.
  Future<PublicProfileModel> fetchPublicProfile(int profileId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.publicProfile(profileId));
    return PublicProfileModel.fromJson(res.dataMap);
  }

  /// `GET /profiles/{id}/compatibility`
  Future<CompatibilityModel> fetchCompatibility(int profileId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.profileCompatibility(profileId));
    return CompatibilityModel.fromJson(res.dataMap);
  }
}
