import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';

/// Repository for Horoscope / Astronomic API calls.
class HoroscopeRepository {
  HoroscopeRepository(this._client);

  final ApiClient _client;

  /// Loads horoscope dropdown options (sun_signs, moon_signs, nakshatras, etc.).
  Future<ApiEnvelope> getDropdowns() =>
      _client.get(ApiEndpoints.horoscopeDropdowns);

  /// Updates the member's horoscope/astronomic details.
  Future<ApiEnvelope> update(Map<String, dynamic> payload) =>
      _client.post(ApiEndpoints.horoscopeUpdate, body: payload);

  /// Fetches horoscope-matched profiles.
  Future<ApiEnvelope> getMatchedProfiles() =>
      _client.get(ApiEndpoints.horoscopeMatchedProfiles);
}
