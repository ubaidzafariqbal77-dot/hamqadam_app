import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/search_filter_profile_model.dart';

/// Repository for Search & Filter profiles API calls (`GET /search/profiles`).
class SearchRepository {
  SearchRepository(this._client);

  final ApiClient _client;

  /// Fetches a page of search profiles matching the given [filter].
  Future<SearchProfilesPage> fetchProfiles({
    required SearchFilterModel filter,
    int page = 1,
    int perPage = 20,
  }) async {
    final Map<String, dynamic> query = filter.toQueryParams(page: page, perPage: perPage);
    final ApiEnvelope res = await _client.get(ApiEndpoints.searchProfiles, query: query);

    return SearchProfilesPage.fromEnvelopeData(
      data: res.dataList.isNotEmpty ? res.dataList : res.data,
      meta: res.meta,
    );
  }
}
