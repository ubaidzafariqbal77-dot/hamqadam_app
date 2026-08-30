import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/search_filter_profile_model.dart';

/// Saved search, search history, and hidden users APIs.
class SearchExtraRepository {
  SearchExtraRepository(this._client);

  final ApiClient _client;

  // ---- Saved Searches -------------------------------------------------------

  /// `GET /search/saved` — list saved searches.
  Future<List<Map<String, dynamic>>> fetchSaved() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.searchSaved);
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /search/saved` — save a search filter.
  Future<void> saveSearch({required String name, required Map<String, dynamic> filters}) async {
    await _client.post(
      ApiEndpoints.searchSaved,
      body: <String, dynamic>{
        'name': name,
        ...filters,
      },
    );
  }

  /// `DELETE /search/saved/{id}` — delete a saved search.
  Future<void> deleteSaved(int id) async {
    await _client.delete(ApiEndpoints.searchSavedDelete(id));
  }

  // ---- Search History -------------------------------------------------------

  /// `GET /search/history` — recent search history.
  Future<List<Map<String, dynamic>>> fetchHistory() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.searchHistory);
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  // ---- Hidden Users ---------------------------------------------------------

  /// `POST /search/hidden-users` — hide profile from a user.
  Future<void> hideFrom({required int userId}) async {
    await _client.post(
      ApiEndpoints.searchHiddenUsers,
      body: <String, dynamic>{'user_id': userId},
    );
  }

  /// `DELETE /search/hidden-users/{user}` — unhide from a user.
  Future<void> unhideFrom(int userId) async {
    await _client.delete(ApiEndpoints.searchHiddenUsersDelete(userId));
  }

  // ---- Utility: convert saved search to SearchFilterModel -------------------

  static SearchFilterModel savedToFilter(Map<String, dynamic> saved) {
    return SearchFilterModel(
      ageMin: saved['age_min'] as int?,
      ageMax: saved['age_max'] as int?,
      verifiedOnly: saved['verified_only'] == true || saved['verified_only'] == 1,
      photoOnly: saved['photo_only'] == true || saved['photo_only'] == 1,
      compatibilityMin: saved['compatibility_min'] as int?,
      nearby: saved['nearby'] == true || saved['nearby'] == 1,
      sort: saved['sort'] as String?,
      gender: saved['gender'] as String?,
      maritalStatusId: saved['marital_status_id'] as int?,
      religionId: saved['religion_id'] as int?,
      casteId: saved['caste_id'] as int?,
      countryId: saved['country_id'] as int?,
      stateId: saved['state_id'] as int?,
      cityId: saved['city_id'] as int?,
      searchQuery: saved['search'] as String?,
    );
  }
}
