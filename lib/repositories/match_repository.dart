import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/search_filter_profile_model.dart';

/// Matching API calls.
class MatchRepository {
  MatchRepository(this._client);

  final ApiClient _client;

  /// `GET /matches` — AI/rule-based smart matches.
  Future<SearchProfilesPage> fetchMatches({int page = 1, int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.matches,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return SearchProfilesPage.fromEnvelopeData(
      data: res.dataList.isNotEmpty ? res.dataList : res.data,
      meta: res.meta,
    );
  }

  /// `GET /matches/recommended` — recommended matches.
  Future<SearchProfilesPage> fetchRecommended({int page = 1, int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.matchesRecommended,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return SearchProfilesPage.fromEnvelopeData(
      data: res.dataList.isNotEmpty ? res.dataList : res.data,
      meta: res.meta,
    );
  }

  /// `GET /matches/daily` — daily curated matches.
  Future<SearchProfilesPage> fetchDaily({int page = 1, int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.matchesDaily,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return SearchProfilesPage.fromEnvelopeData(
      data: res.dataList.isNotEmpty ? res.dataList : res.data,
      meta: res.meta,
    );
  }

  /// `GET /matches/{profile}` — single match detail.
  Future<SearchProfileModel?> fetchMatchDetail(int profileId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.matchDetail(profileId));
    final dynamic raw = res.data;
    if (raw is Map<String, dynamic>) return SearchProfileModel.fromJson(raw);
    return null;
  }

  /// `POST /matches/feedback` — like/dislike feedback.
  Future<void> sendFeedback({
    required int userId,
    required String feedback,
    String? source,
    String? note,
  }) async {
    await _client.post(
      ApiEndpoints.matchesFeedback,
      body: <String, dynamic>{
        'user_id': userId,
        'feedback': feedback,
        if (source != null) 'source': source,
        if (note != null) 'note': note,
      },
    );
  }

  /// `POST /matches/recalculate` — trigger recomputation.
  Future<int> recalculate({int limit = 100}) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.matchesRecalculate,
      body: <String, dynamic>{'limit': limit},
    );
    return (res.dataMap['processed_profiles'] as int?) ?? 0;
  }
}
