import '../constants/api_endpoints.dart';
import '../constants/app_lookups.dart';
import '../core/api/api_client.dart';
import '../core/utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';

/// Supplies dropdown/lookup data.
///
/// Strategy: try the conventional `/lookups/{key}` endpoint first; if the
/// backend has no such endpoint (redirect/404/non-list body) transparently
/// fall back to [BundledLookups]. Results are cached in memory per (key,parent)
/// with a manual [refresh] escape hatch.
///
/// NOTE: the documented HamQadam v1 API exposes no lookup endpoints, so in
/// practice the bundled data is used today. This design means zero UI changes
/// when the backend later ships real endpoints.
class LookupRepository {
  LookupRepository(this._client);

  /// The HamQadam v1 API exposes NO lookup endpoints, so hitting the network
  /// first only adds a failed round-trip of latency before we fall back to the
  /// bundled data (visible as a "loading" flicker on dependent dropdowns like
  /// province/city). Keep this `false` until real `/lookups/*` endpoints ship —
  /// flip to `true` then and the network path below takes over with zero UI
  /// changes.
  static const bool useNetworkLookups = false;

  final ApiClient _client;
  final Map<String, List<LookupItem>> _cache = <String, List<LookupItem>>{};

  String _cacheKey(String key, int? parentId) => parentId == null ? key : '$key:$parentId';

  Future<List<LookupItem>> fetch(String key, {int? parentId, bool forceRefresh = false}) async {
    final String ck = _cacheKey(key, parentId);
    if (!forceRefresh && _cache.containsKey(ck)) return _cache[ck]!;

    List<LookupItem>? items = await _tryNetwork(key, parentId);
    items ??= _bundled(key, parentId);

    _cache[ck] = items;
    return items;
  }

  void invalidate(String key, {int? parentId}) {
    if (parentId == null) {
      _cache.removeWhere((String k, _) => k == key || k.startsWith('$key:'));
    } else {
      _cache.remove(_cacheKey(key, parentId));
    }
  }

  Future<List<LookupItem>?> _tryNetwork(String key, int? parentId) async {
    if (!useNetworkLookups) return null; // bundled data is served instantly
    try {
      final ApiEnvelope res = await _client.get(
        ApiEndpoints.lookup(key),
        query: parentId == null ? null : <String, dynamic>{'parent_id': parentId},
      );
      final List<dynamic> list = res.dataList;
      if (list.isEmpty) return null; // fall back to bundled
      return list.whereType<Map<String, dynamic>>().map(LookupItem.fromJson).toList();
    } on AppException catch (e) {
      AppLogger.d('Lookup "$key" not available over network ($e) — using bundled data.');
      return null;
    }
  }

  List<LookupItem> _bundled(String key, int? parentId) {
    final List<Map<String, dynamic>>? data = BundledLookups.byKey[key];
    if (data == null) return const <LookupItem>[];
    Iterable<LookupItem> items = data.map(LookupItem.fromJson);
    if (parentId != null) {
      items = items.where((LookupItem i) => i.parentId == parentId);
    }
    return items.toList();
  }
}
