import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../constants/app_lookups.dart';
import '../core/api/api_response.dart';
import '../core/utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';
import '../repositories/lookup_repository.dart';

/// Central store for all lookup lists. Each (key, parentId) pair has its own
/// [ApiState] so dropdowns can show loading/empty/retry inline and dependent
/// dropdowns (country→state→city, religion→caste→sub-caste) stay consistent.
class LookupController extends GetxController {
  LookupController(this._repo);

  final LookupRepository _repo;
  final RxMap<String, ApiState<List<LookupItem>>> states =
      <String, ApiState<List<LookupItem>>>{}.obs;

  String cacheKey(String key, int? parentId) => parentId == null ? key : '$key:$parentId';

  ApiState<List<LookupItem>> stateOf(String key, {int? parentId}) =>
      states[cacheKey(key, parentId)] ?? const ApiState<List<LookupItem>>.initial();

  List<LookupItem> itemsOf(String key, {int? parentId}) =>
      stateOf(key, parentId: parentId).data ?? const <LookupItem>[];

  /// Fetches the whole `dropdown-reference-data` payload once, then warms the
  /// lists the registration flow opens with. Safe to call repeatedly.
  Future<void> preloadReference({bool force = false}) async {
    try {
      await _repo.preload(force: force);
    } catch (e) {
      AppLogger.w('Dropdown reference preload failed (bundled data will be used): $e');
    }
    // A forced refresh happens when a token appears, i.e. when everything
    // cached so far may be bundled fallback data. Drop the per-list states too,
    // otherwise `ensure` short-circuits on their stale "success" and dropdowns
    // keep showing ids the server does not recognise. Cleared only now that the
    // fresh payload is in hand — clearing first would blank every dropdown on
    // screen for the whole length of the request.
    if (force) states.clear();
    // The payload is parsed by now, so each list is a slice of memory. Warming
    // them concurrently keeps the first step from waiting on a chain of awaits.
    await Future.wait<void>(<Future<void>>[
      for (final String key in LookupKeys.preload) force ? load(key) : ensure(key),
    ]);
  }

  /// Forgets every cached list (new signup / logout).
  void resetAll() {
    _repo.clear();
    states.clear();
  }

  /// Loads only if not already loaded/loading.
  Future<void> ensure(String key, {int? parentId}) async {
    final ApiState<List<LookupItem>> s = stateOf(key, parentId: parentId);
    if (s.isSuccess || s.isLoading) return;
    await load(key, parentId: parentId);
  }

  Future<void> load(String key, {int? parentId, bool force = false}) async {
    final String ck = cacheKey(key, parentId);
    _emit(ck, const ApiState<List<LookupItem>>.loading());
    try {
      final List<LookupItem> items = await _repo.fetch(
        key,
        parentId: parentId,
        forceRefresh: force,
      );
      _emit(
        ck,
        items.isEmpty
            ? const ApiState<List<LookupItem>>.empty()
            : ApiState<List<LookupItem>>.success(items),
      );
    } on AppException catch (e) {
      _emit(ck, ApiState<List<LookupItem>>.fromException(e));
    } catch (e) {
      _emit(ck, ApiState<List<LookupItem>>.serverError(e.toString()));
    }
  }

  /// Assigns state safely. If called while Flutter is mid-build (e.g. a lookup
  /// triggered from a controller's onInit during a view's initState), the
  /// mutation is deferred to the next frame so it never marks an Obx dirty
  /// during build.
  void _emit(String ck, ApiState<List<LookupItem>> state) {
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => states[ck] = state);
    } else {
      states[ck] = state;
    }
  }

  /// Drops a cached dependent list so it will be re-fetched for a new parent.
  void invalidate(String key, {int? parentId}) {
    _repo.invalidate(key, parentId: parentId);
    if (parentId == null) {
      states.removeWhere((String k, _) => k == key || k.startsWith('$key:'));
    } else {
      states.remove(cacheKey(key, parentId));
    }
  }
}
