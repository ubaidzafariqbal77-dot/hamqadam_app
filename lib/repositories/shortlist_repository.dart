import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/shortlist_model.dart';

/// All REST calls for the Shortlist feature.
class ShortlistRepository {
  ShortlistRepository(this._client);

  final ApiClient _client;

  /// `GET /proposals/shortlists` — fetch paginated shortlisted profiles.
  Future<ShortlistPage> fetchShortlists({int page = 1, int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.shortlists,
      query: <String, dynamic>{
        'page': page,
        'per_page': perPage,
      },
    );
    return ShortlistPage.fromJson(res.raw);
  }

  /// `POST /proposals/shortlists` — add user to shortlist.
  Future<ShortlistToggleResult> addToShortlist(int userId) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.shortlists,
      body: <String, dynamic>{'user_id': userId},
    );
    return ShortlistToggleResult.fromJson(res.dataMap);
  }

  /// `DELETE /proposals/shortlists/{userId}` — remove user from shortlist.
  Future<bool> removeFromShortlist(int userId) async {
    final ApiEnvelope res = await _client.delete(
      ApiEndpoints.shortlistRemove(userId),
    );
    return res.success;
  }

  /// `GET /proposals/shortlists/{userId}/check` — check if user is shortlisted.
  Future<bool> checkIsShortlisted(int userId) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.shortlistCheck(userId),
    );
    final ShortlistCheckResult result = ShortlistCheckResult.fromJson(res.dataMap);
    return result.isShortlisted;
  }
}
