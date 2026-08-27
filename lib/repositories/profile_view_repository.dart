import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/profile_view_model.dart';
import '../models/public_profile_model.dart';

/// REST client repository for profile view tracking and allowance spending.
class ProfileViewRepository {
  ProfileViewRepository(this._client);

  final ApiClient _client;

  /// `GET /profile-views/received` — members who viewed the current user.
  Future<ProfileViewsPage> fetchReceivedViews({int page = 1, int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.profileViewsReceived,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    final Map<String, dynamic> rawJson = res.raw is Map<String, dynamic>
        ? res.raw as Map<String, dynamic>
        : <String, dynamic>{
            'data': res.dataList,
            'meta': res.meta,
            'links': res.links,
          };
    return ProfileViewsPage.fromJson(rawJson);
  }

  /// `GET /profile-views` — profiles the current member has viewed.
  Future<ProfileViewsPage> fetchMyViews({int page = 1, int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.profileViews,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    final Map<String, dynamic> rawJson = res.raw is Map<String, dynamic>
        ? res.raw as Map<String, dynamic>
        : <String, dynamic>{
            'data': res.dataList,
            'meta': res.meta,
            'links': res.links,
          };
    return ProfileViewsPage.fromJson(rawJson);
  }

  /// `GET /profile-views/balance` — view balance and active package info.
  Future<ProfileViewSummary> fetchBalance() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.profileViewsBalance);
    final dynamic raw = res.raw is Map<String, dynamic> ? res.raw as Map<String, dynamic> : null;
    final dynamic data = res.dataMap.isNotEmpty
        ? res.dataMap
        : raw?['summary'] ?? raw?['data'];
    if (data is Map<String, dynamic>) {
      return ProfileViewSummary.fromJson(data);
    }
    return const ProfileViewSummary();
  }

  /// `POST /profile-views/{profile}` — consumes one profile-view allowance.
  Future<PublicProfileModel> consumeProfileView(int profileId) async {
    final ApiEnvelope res = await _client.post(ApiEndpoints.consumeProfileView(profileId));
    return PublicProfileModel.fromJson(res.dataMap);
  }
}
