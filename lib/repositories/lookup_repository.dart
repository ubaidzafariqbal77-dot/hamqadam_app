import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../constants/api_endpoints.dart';
import '../constants/api_options.dart';
import '../constants/app_lookups.dart';
import '../constants/income_options.dart';
import '../core/api/api_client.dart';
import '../core/utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';

/// One lookup list, already converted and indexed by parent id.
///
/// The reference payload holds ~48 000 cities and ~4 000 states. Filtering those
/// with a linear scan every time a dependent dropdown opens was the slow part of
/// the registration flow, so the parent index is built once — inside the
/// background isolate that parses the payload — and every slice is then a map
/// lookup.
@immutable
class LookupList {
  const LookupList(this.items, this.byParent);

  final List<LookupItem> items;

  /// parent id -> rows. Empty for lists whose rows carry no parent.
  final Map<int, List<LookupItem>> byParent;

  bool get hasParents => byParent.isNotEmpty;

  List<LookupItem> forParent(int? parentId) {
    if (parentId == null || !hasParents) return items;
    return byParent[parentId] ?? const <LookupItem>[];
  }
}

/// Converts the raw `dropdown-reference-data` shape into indexed [LookupList]s.
/// Top-level so it can run in a [compute] isolate.
@visibleForTesting
Map<String, LookupList> buildLookupLists(Map<String, dynamic> data) {
  final Map<String, LookupList> out = <String, LookupList>{};
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
    if (items.isEmpty) return;
    final Map<int, List<LookupItem>> byParent = <int, List<LookupItem>>{};
    for (final LookupItem i in items) {
      final int? parent = i.parentId;
      if (parent != null) (byParent[parent] ??= <LookupItem>[]).add(i);
    }
    out[key] = LookupList(items, byParent);
  });
  return out;
}

/// Decode + convert in one isolate hop. Top-level for [compute].
@visibleForTesting
Map<String, LookupList> decodeAndBuildLookupLists(String raw) {
  final dynamic decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return <String, LookupList>{};
  return buildLookupLists(decoded);
}

/// Supplies every dropdown list in the app.
///
/// The documented API exposes ONE endpoint for all of them —
/// `GET /api/v1/profile/dropdown-reference-data` — which returns the dynamic
/// (database-backed) lists together with the hardcoded option lists. It is
/// fetched once, parsed off the UI isolate, and sliced per field; dependent
/// lists (state→country, city→state, sub-caste→caste, degree→education level, …)
/// come from the parent index each [LookupList] carries.
///
/// The endpoint is bearer-only, and during signup there is no token yet, so the
/// flow reads a bundled copy of the same payload
/// (`assets/lookups/dropdown_reference.json`, which carries the server's real
/// ids) and falls back to [ApiOptions] for the hardcoded lists. Nothing ever
/// dead-ends on a spinner.
class LookupRepository {
  LookupRepository(this._client);

  final ApiClient _client;

  /// The whole reference payload, parsed once.
  Map<String, LookupList>? _reference;
  Future<Map<String, LookupList>>? _inFlight;

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

  /// Loads the reference payload up front. Cheap to call without a token: it
  /// warms the bundled asset instead of firing a request that can only 401.
  Future<void> preload({bool force = false}) async {
    await _loadReference(force: force);
    // Registration reads everything from the asset, so decode it now (off the UI
    // isolate) rather than on the first dropdown tap.
    if (_reference == null) await _loadAssetLists();
  }

  Future<List<LookupItem>> fetch(String key, {int? parentId, bool forceRefresh = false}) async {
    final String ck = _cacheKey(key, parentId);
    if (!forceRefresh && _cache.containsKey(ck)) return _cache[ck]!;

    final Map<String, LookupList> reference = await _loadReference(force: forceRefresh);

    LookupList? list = reference[key];
    bool fromAsset = false;
    // Offline copy of the same endpoint — carries the server's real ids, so a
    // signup completed without a token still submits values the API accepts.
    if (list == null) {
      list = (await _loadAssetLists())[key];
      fromAsset = list != null;
    }

    final List<LookupItem> sliced =
        list != null ? list.forParent(parentId) : _sliceByParent(_fallback(key), parentId);
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

  Future<Map<String, LookupList>> _loadReference({bool force = false}) {
    if (!force && _reference != null) {
      return Future<Map<String, LookupList>>.value(_reference!);
    }
    if (force) {
      _reference = null;
      _failedAt = null;
      _cache.clear();
    }
    // Bearer-only endpoint: with no token the request cannot do anything but
    // 401, and paying that round trip on every dropdown is exactly what made the
    // registration steps feel slow. Go straight to the bundled copy.
    if (!_client.hasToken) {
      requiresAuth = true;
      return Future<Map<String, LookupList>>.value(const <String, LookupList>{});
    }
    final DateTime? failedAt = _failedAt;
    if (failedAt != null && DateTime.now().difference(failedAt) < _retryCooldown) {
      return Future<Map<String, LookupList>>.value(const <String, LookupList>{});
    }
    return _inFlight ??= _fetchReference().whenComplete(() => _inFlight = null);
  }

  Future<Map<String, LookupList>> _fetchReference() async {
    try {
      final ApiEnvelope res = await _client.get(ApiEndpoints.dropdownReferenceData);
      final Map<String, dynamic> data = res.dataMap;
      // ~48 000 rows: converting and indexing them on the UI isolate drops frames.
      final Map<String, LookupList> parsed = await compute(buildLookupLists, data);
      if (parsed.isEmpty) {
        AppLogger.w('dropdown-reference-data returned no lists — using bundled data.');
        _failedAt = DateTime.now();
        return <String, LookupList>{};
      }
      AppLogger.i('Loaded ${parsed.length} dropdown lists from the API.');
      _failedAt = null;
      requiresAuth = false;
      return _reference = parsed;
    } on UnauthorizedException catch (e) {
      // Registration is filled in locally and only submitted at the end, so no
      // token exists while the user is picking from these dropdowns. The
      // endpoint is documented as bearer-only, which leaves the flow on the
      // bundled copy of the same payload (real server ids, so the final
      // submission is still accepted).
      //
      // BACKEND FIX: allow `GET /api/v1/profile/dropdown-reference-data`
      // unauthenticated (or publish a public alias). Nothing changes in the app
      // beyond the lists being live rather than bundled.
      requiresAuth = true;
      AppLogger.w('dropdown-reference-data returned 401 ($e) — using bundled data.');
      _failedAt = DateTime.now();
      return <String, LookupList>{};
    } on AppException catch (e) {
      // Offline or a server hiccup — bundled/static data takes over. The
      // payload is NOT memoised, so a later call (or a manual retry) tries again.
      AppLogger.d('dropdown-reference-data unavailable ($e) — using bundled data.');
      _failedAt = DateTime.now();
      return <String, LookupList>{};
    }
  }

  // ---- Bundled copy of dropdown-reference-data ------------------------------

  /// Every bundled list, converted and indexed once.
  Map<String, LookupList>? _assetLists;
  Future<Map<String, LookupList>>? _assetInFlight;

  static const String _assetPath = 'assets/lookups/dropdown_reference.json';

  Future<Map<String, LookupList>> _loadAssetLists() {
    final Map<String, LookupList>? cached = _assetLists;
    if (cached != null) return Future<Map<String, LookupList>>.value(cached);
    return _assetInFlight ??= _decodeAsset().whenComplete(() => _assetInFlight = null);
  }

  Future<Map<String, LookupList>> _decodeAsset() async {
    try {
      final String raw = await rootBundle.loadString(_assetPath);
      // ~2.4 MB of JSON and ~52 000 rows. Decoding, converting and indexing all
      // of it happens in one isolate hop; the result is handed back without a
      // copy, so the UI isolate never touches a row.
      final Map<String, LookupList> lists = await compute(decodeAndBuildLookupLists, raw);
      AppLogger.i('Loaded ${lists.length} dropdown lists from the bundled asset.');
      return _assetLists = lists;
    } catch (e) {
      AppLogger.w('Bundled dropdown asset unavailable: $e');
      return _assetLists = const <String, LookupList>{};
    }
  }

  /// Lists the server does not serve at all, so they can only ever come from
  /// here. Not const, because the rows are generated.
  static List<LookupItem> _generatedFallback(String key) => switch (key) {
    LookupKeys.annualIncome => IncomeBand.options,
    LookupKeys.partnerIncome => IncomeBand.options,
    LookupKeys.siblings => SiblingOptions.options,
    _ => const <LookupItem>[],
  };

  List<LookupItem> _fallback(String key) {
    final List<LookupItem>? statics = _staticFallback[key];
    if (statics != null) return statics;
    final List<LookupItem> generated = _generatedFallback(key);
    if (generated.isNotEmpty) return generated;
    final List<Map<String, dynamic>>? bundled = BundledLookups.byKey[key];
    if (bundled == null) return const <LookupItem>[];
    return bundled.map(LookupItem.fromJson).toList();
  }

  /// Keeps only the rows belonging to [parentId]. Used for the small hardcoded
  /// fallback lists, which are not worth indexing. Lists that carry no parent
  /// information at all (e.g. castes, which the API documents as independent)
  /// are returned untouched so a stale parent never blanks a dropdown.
  List<LookupItem> _sliceByParent(List<LookupItem> items, int? parentId) {
    if (parentId == null || items.isEmpty) return items;
    if (items.every((LookupItem i) => i.parentId == null)) return items;
    return items.where((LookupItem i) => i.parentId == parentId).toList();
  }
}
