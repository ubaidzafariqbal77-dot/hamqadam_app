import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/partner_preference_model.dart';

/// Partner-preference calls.
///
/// These drive server-side match filtering, so a save here changes what the
/// member sees under Matches — refresh those lists after a successful update.
class PartnerPreferenceRepository {
  PartnerPreferenceRepository(this._client);

  final ApiClient _client;

  /// `GET /partner-preferences`
  ///
  /// A member who never completed step 17 has no row; the endpoint answers with
  /// an empty object rather than 404, which maps to an empty model.
  Future<PartnerPreferenceModel> fetch() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.partnerPreferences);
    final Map<String, dynamic> data = res.dataMap;
    return data.isEmpty ? PartnerPreferenceModel.empty() : PartnerPreferenceModel.fromJson(data);
  }

  /// `PUT /partner-preferences`
  ///
  /// Pass the body from [PartnerPreferenceModel.toUpdateJson], which flattens
  /// and renames the nested read shape into the column names the validator
  /// expects. Posting the read shape back silently saves nothing.
  Future<PartnerPreferenceModel> update(Map<String, dynamic> body) async {
    final ApiEnvelope res = await _client.put(ApiEndpoints.partnerPreferences, body: body);
    return PartnerPreferenceModel.fromJson(res.dataMap);
  }

  /// `DELETE /partner-preferences` — clears every preference, which widens the
  /// match pool rather than emptying it.
  Future<void> clear() async {
    await _client.delete(ApiEndpoints.partnerPreferences);
  }
}
