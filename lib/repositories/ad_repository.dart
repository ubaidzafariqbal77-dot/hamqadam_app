import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../core/api/api_response.dart';
import '../models/ad_slide_model.dart';

/// App home ads banner from `GET /ads-banner` — managed in
/// Admin → Website Setup → Member Ad Sliders.
class AdRepository {
  AdRepository(this._client);

  final ApiClient _client;

  /// Active slides for one placement (`top` = Discover hero banner).
  Future<List<AdSlideModel>> fetchSlides({String placement = 'top'}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.adsBanner,
      query: <String, dynamic>{'placement': placement},
    );
    final dynamic list = res.dataMap[placement];
    if (list is! List) return <AdSlideModel>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AdSlideModel.fromJson)
        .where((AdSlideModel s) => s.imageUrl != null)
        .toList();
  }
}
