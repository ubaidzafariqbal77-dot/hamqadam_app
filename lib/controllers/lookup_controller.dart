import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../core/api/api_response.dart';
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
