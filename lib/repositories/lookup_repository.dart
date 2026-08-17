import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../constants/api_endpoints.dart';
import '../constants/api_options.dart';
import '../constants/app_lookups.dart';
import '../core/api/api_client.dart';
import '../core/utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';

/// Supplies every dropdown list in the app.
///
/// The documented API exposes ONE endpoint for all of them —
/// `GET /api/v1/profile/dropdown-reference-data` — which returns the dynamic
/// (database-backed) lists together with the hardcoded option lists. It is
/// fetched once, cached in memory, and sliced per field; dependent lists
/// (state→country, city→state, sub-caste→caste, degree→education level, …) are
/// filtered locally on the parent id each row carries.
///
/// If the endpoint is unreachable (offline, or step 1 not completed yet so no
/// token exists) the repository falls back to [BundledLookups] for the core
/// lists and to [ApiOptions] for the hardcoded ones, so the flow never dead-ends
/// on a spinner.
/// Top-level so it can run in the [compute] isolate.
Map<String, dynamic>? _decodeJsonMap(String raw) {
  final dynamic decoded = jsonDecode(raw);
  return decoded is Map<String, dynamic> ? decoded : null;
}

class LookupRepository {
  LookupRepository(this._client);

  final ApiClient _client;

  /// The whole reference payload, parsed once.
  Map<String, List<LookupItem>>? _reference;
  Future<Map<String, List<LookupItem>>>? _inFlight;

  /// When the last fetch failed. Warming a dozen lists offline must not fire a
  /// dozen doomed requests, so failures are remembered for a short while.
  DateTime? _failedAt;
  static const Duration _retryCooldown = Duration(seconds: 30);

  /// Sliced results per (key, parentId).
  final Map<String, List<LookupItem>> _cache = <String, List<LookupItem>>{};

  String _cacheKey(String key, int? parentId) => parentId == null ? key : '$key:$parentId';

  bool get isLoaded => _reference != null;

  /// True once the reference endpoint answered 401 — i.e. the lists on screen
  /// are bundled fallbacks, not the server's. Cleared by a successful fetch.
  bool requiresAuth = false;

  /// Hardcoded lists the API also serves; used when it cannot be reached.
  static const Map<String, List<LookupItem>> _staticFallback = <String, List<LookupItem>>{
    LookupKeys.genders: ApiOptions.gender,
    LookupKeys.marriageTimeline: ApiOptions.marriageTimeline,
    LookupKeys.willingToWork: ApiOptions.workIntent,
    LookupKeys.expectsSpouseToWork: ApiOptions.workIntent,
    LookupKeys.diet: ApiOptions.diet,
    LookupKeys.employmentStatus: ApiOptions.employmentStatus,
    LookupKeys.educationStatus: ApiOptions.educationStatus,
    LookupKeys.liveWithFamily: ApiOptions.liveWithFamily,
    LookupKeys.familyValues: ApiOptions.familyValues,
  };

  /// Loads the reference payload up front (called once a token exists).
  Future<void> preload({bool force = false}) async {
    await _loadReference(force: force);
  }

  Future<List<LookupItem>> fetch(String key, {int? parentId, bool forceRefresh = false}) async {
    final String ck = _cacheKey(key, parentId);
    if (!forceRefresh && _cache.containsKey(ck)) return _cache[ck]!;

    final Map<String, List<LookupItem>> reference = await _loadReference(force: forceRefresh);

    List<LookupItem> items = reference[key] ?? const <LookupItem>[];
    bool fromAsset = false;
    // Offline copy of the same endpoint — carries the server's real ids, so a
    // signup completed without a token still submits values the API accepts.
    if (items.isEmpty) {
      items = await _fromAsset(key);
      fromAsset = items.isNotEmpty;
    }
    if (items.isEmpty) items = _fallback(key);

    final List<LookupItem> sliced = _sliceByParent(items, parentId);
    // Memoise server and bundled-asset data (both carry real ids). The tiny
    // hardcoded fallbacks are not cached, so they cannot outlive a failure.
    if (_reference != null || fromAsset) _cache[ck] = sliced;
    return sliced;
  }

  void invalidate(String key, {int? parentId}) {
    if (parentId == null) {
      _cache.removeWhere((String k, _) => k == key || k.startsWith('$key:'));
    } else {
      _cache.remove(_cacheKey(key, parentId));
    }
  }

  /// Drops everything (new signup / logout / manual refresh).
  void clear() {
    _cache.clear();
    _reference = null;
    _failedAt = null;
    requiresAuth = false;
  }

  // ---- Internals ------------------------------------------------------------

  Future<Map<String, List<LookupItem>>> _loadReference({bool force = false}) {
    if (!force && _reference != null) {
      return Future<Map<String, List<LookupItem>>>.value(_reference!);
    }
    if (force) {
      _reference = null;
      _failedAt = null;
      _cache.clear();
    }
    final DateTime? failedAt = _failedAt;
    if (failedAt != null && DateTime.now().difference(failedAt) < _retryCooldown) {
      return Future<Map<String, List<LookupItem>>>.value(const <String, List<LookupItem>>{});
    }
    return _inFlight ??= _fetchReference().whenComplete(() => _inFlight = null);
  }

  Future<Map<String, List<LookupItem>>> _fetchReference() async {
    try {
      final ApiEnvelope res = await _client.get(ApiEndpoints.dropdownReferenceData);
      final Map<String, dynamic> data = res.dataMap;
      final Map<String, List<LookupItem>> parsed = <String, List<LookupItem>>{};
      data.forEach((String key, dynamic value) {
        if (value is! List) return;
        final List<LookupItem> items = <LookupItem>[];
        for (final dynamic row in value) {
          if (row is Map<String, dynamic>) {
            items.add(LookupItem.fromJson(row));
          } else if (row is String) {
            items.add(LookupItem.option(row, row));
          }
        }
        if (items.isNotEmpty) parsed[key] = items;
      });
      if (parsed.isEmpty) {
        AppLogger.w('dropdown-reference-data returned no lists — using bundled data.');
        _failedAt = DateTime.now();
        return <String, List<LookupItem>>{};
      }
      AppLogger.i('Loaded ${parsed.length} dropdown lists from the API.');
      _failedAt = null;
      requiresAuth = false;
      return _reference = parsed;
    } on UnauthorizedException catch (e) {
      // Registration is filled in locally and only submitted at the end, so no
      // token exists while the user is picking from these dropdowns. The
      // endpoint is documented as bearer-only, which leaves the flow on bundled
      // data — and bundled ids do NOT match the server's, so the final
      // submission is rejected ("The selected city id is invalid").
      //
      // BACKEND FIX: allow `GET /api/v1/profile/dropdown-reference-data`
      // unauthenticated (or publish a public alias). Nothing changes in the app.
      requiresAuth = true;
      AppLogger.w(
        'dropdown-reference-data returned 401 ($e). Registration dropdowns are '
        'falling back to bundled data — the endpoint must be reachable without '
        'a token for the signup flow to submit real ids.',
      );
      _failedAt = DateTime.now();
      return <String, List<LookupItem>>{};
    } on AppException catch (e) {
      // Offline or a server hiccup — bundled/static data takes over. The
      // payload is NOT memoised, so a later call (or a manual retry) tries again.
      AppLogger.d('dropdown-reference-data unavailable ($e) — using bundled data.');
      _failedAt = DateTime.now();
      return <String, List<LookupItem>>{};
    }
  }

  // ---- Bundled copy of dropdown-reference-data ------------------------------

  /// The raw asset, decoded once. Kept as JSON rather than [LookupItem]s so the
  /// 48k-row city list is never converted unless a city dropdown is opened.
  Map<String, dynamic>? _assetJson;
  Future<Map<String, dynamic>>? _assetInFlight;

  /// Per-key conversions, so each list is built at most once.
  final Map<String, List<LookupItem>> _assetItems = <String, List<LookupItem>>{};

  static const String _assetPath = 'assets/lookups/dropdown_reference.json';

  Future<List<LookupItem>> _fromAsset(String key) async {
    final List<LookupItem>? done = _assetItems[key];
    if (done != null) return done;
    try {
      final Map<String, dynamic> json = await _loadAssetJson();
      final dynamic rows = json[key];
      if (rows is! List) return const <LookupItem>[];
      final List<LookupItem> items = <LookupItem>[
        for (final dynamic row in rows)
          if (row is Map<String, dynamic>) LookupItem.fromJson(row),
      ];
      return _assetItems[key] = items;
    } catch (e) {
      AppLogger.w('Bundled dropdown asset unavailable for "$key": $e');
      return const <LookupItem>[];
    }
  }

  Future<Map<String, dynamic>> _loadAssetJson() {
    final Map<String, dynamic>? cached = _assetJson;
    if (cached != null) return Future<Map<String, dynamic>>.value(cached);
    return _assetInFlight ??= _decodeAsset().whenComplete(() => _assetInFlight = null);
  }

  Future<Map<String, dynamic>> _decodeAsset() async {
    final String raw = await rootBundle.loadString(_assetPath);
    // ~2.4 MB of JSON — decoding on the UI isolate drops frames.
    final Map<String, dynamic> json =
        await compute(_decodeJsonMap, raw) ?? <String, dynamic>{};
    AppLogger.i('Loaded ${json.length} dropdown lists from the bundled asset.');
    return _assetJson = json;
  }

  List<LookupItem> _fallback(String key) {
    final List<LookupItem>? statics = _staticFallback[key];
    if (statics != null) return statics;
    final List<Map<String, dynamic>>? bundled = BundledLookups.byKey[key];
    if (bundled == null) return const <LookupItem>[];
    return bundled.map(LookupItem.fromJson).toList();
  }

  /// Keeps only the rows belonging to [parentId]. Lists that carry no parent
  /// information at all (e.g. castes, which the API documents as independent)
  /// are returned untouched so a stale parent never blanks a dropdown.
  List<LookupItem> _sliceByParent(List<LookupItem> items, int? parentId) {
    if (parentId == null || items.isEmpty) return items;
    if (items.every((LookupItem i) => i.parentId == null)) return items;
    return items.where((LookupItem i) => i.parentId == parentId).toList();
  }
}
