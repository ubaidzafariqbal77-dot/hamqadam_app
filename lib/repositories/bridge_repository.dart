import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';

/// Repository for the System Bridge endpoints that expose Pusher / realtime
/// connection settings.  The backend returns fingerprints and masked secrets;
/// the actual Pusher credentials live in the `public` node.
class BridgeRepository {
  BridgeRepository(this._client);

  final ApiClient _client;

  /// Fetches Connector A config (Pusher-compatible: app_id, app_key, cluster, host, port, scheme).
  Future<ApiEnvelope> getConnectorA() =>
      _client.get(ApiEndpoints.bridgeConnectorA);

  /// Fetches Connector B config (alternative connector, usually disabled).
  Future<ApiEnvelope> getConnectorB() =>
      _client.get(ApiEndpoints.bridgeConnectorB);
}
