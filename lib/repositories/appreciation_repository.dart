import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/appreciation_model.dart';

class AppreciationRepository {
  AppreciationRepository(this._client);

  final ApiClient _client;

  Future<AppreciationStatus> fetchStatus(int userId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.appreciationStatus(userId));
    return AppreciationStatus.fromJson(res.dataMap);
  }

  /// Toggles the free Like. Returns `(liked, mutual)`.
  Future<(bool, bool)> toggleLike(int userId) async {
    final ApiEnvelope res = await _client.post(ApiEndpoints.appreciationLike(userId));
    final Map<String, dynamic> data = res.dataMap;
    return (data['liked'] == true, data['mutual'] == true);
  }

  Future<SuperLikeResult> superLike(int userId, {required int quotedCost}) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.appreciationSuperLike(userId),
      body: <String, dynamic>{'quoted_cost': quotedCost},
    );
    return SuperLikeResult.fromJson(res.dataMap);
  }

  Future<AppreciationActivityPage> fetchActivity({
    required bool received,
    required AppreciationType type,
    int page = 1,
  }) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.appreciationActivity,
      query: <String, dynamic>{
        'direction': received ? 'received' : 'sent',
        'type': type.apiValue,
        'page': page,
        'per_page': 20,
      },
    );
    final Map<String, dynamic> meta = res.meta ?? <String, dynamic>{};
    return AppreciationActivityPage(
      items: res.dataList
          .whereType<Map>()
          .map((Map e) => AppreciationActivity.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      currentPage: int.tryParse('${meta['current_page'] ?? 1}') ?? 1,
      lastPage: int.tryParse('${meta['last_page'] ?? 1}') ?? 1,
    );
  }
}
