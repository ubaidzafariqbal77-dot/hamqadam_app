import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus so the rest of the app depends on an
/// interface, not the package directly.
class NetworkInfo {
  NetworkInfo({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity() {
    // Keep the cached answer honest without polling: every change the platform
    // reports overwrites it. Never cancelled — this is an app-lifetime singleton.
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _cached = _hasConnection(result);
      _cachedAt = DateTime.now();
    });
  }

  final Connectivity _connectivity;

  /// `checkConnectivity()` is a platform-channel round trip, and every API call
  /// makes one. During registration a screen can fire several lookups at once,
  /// so the answer is reused for a moment instead of asked once per request.
  static const Duration _freshness = Duration(seconds: 3);

  bool? _cached;
  DateTime? _cachedAt;

  Future<bool> get isConnected async {
    final bool? cached = _cached;
    final DateTime? at = _cachedAt;
    if (cached != null && at != null && DateTime.now().difference(at) < _freshness) {
      return cached;
    }
    final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
    _cached = _hasConnection(result);
    _cachedAt = DateTime.now();
    return _cached!;
  }

  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged.map(_hasConnection);

  bool _hasConnection(List<ConnectivityResult> result) =>
      result.any((ConnectivityResult r) => r != ConnectivityResult.none);
}
