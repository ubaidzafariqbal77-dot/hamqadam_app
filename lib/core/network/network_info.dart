import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus so the rest of the app depends on an
/// interface, not the package directly.
class NetworkInfo {
  NetworkInfo({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> get isConnected async {
    final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
    return _hasConnection(result);
  }

  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged.map(_hasConnection);

  bool _hasConnection(List<ConnectivityResult> result) =>
      result.any((ConnectivityResult r) => r != ConnectivityResult.none);
}
