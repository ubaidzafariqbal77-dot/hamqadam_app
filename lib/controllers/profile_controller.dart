import 'package:get/get.dart';

import '../constants/app_lookups.dart';
import '../core/api/api_response.dart';
import '../core/storage/profile_completion_service.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';
import 'lookup_controller.dart';

/// Drives the Profile screen: fetches `GET /profile` and exposes the result as
/// an [ApiState] so the UI can render the mandated loading / success / empty /
/// error states. Also resolves the member's numeric ids (marital status,
/// gender, languages, on-behalf) into human labels via [LookupController].
class ProfileController extends GetxController {
  ProfileController(this._repo, this._lookup, this.completion);

  final ProfileRepository _repo;
  final LookupController _lookup;

  /// Drives the completion graph; reconciled with the server copy on every load
  /// so data added elsewhere still counts as a finished section.
  final ProfileCompletionService completion;

  final Rx<ApiState<ProfileModel>> state = const ApiState<ProfileModel>.initial().obs;

  ProfileModel? get profile => state.value.data;

  @override
  void onInit() {
    super.onInit();
    // Warm the lookup lists used for id → label resolution (bundled fallback is
    // instant; a network refresh, if available, updates in place).
    _lookup
      ..ensure(LookupKeys.genders)
      ..ensure(LookupKeys.maritalStatuses)
      ..ensure(LookupKeys.languages)
      ..ensure(LookupKeys.onBehalf);
    load();
  }

  Future<void> load() async {
    state.value = const ApiState<ProfileModel>.loading();
    try {
      final ProfileModel data = await _repo.fetchProfile();
      completion.reconcile(data);
      state.value = ApiState<ProfileModel>.success(data);
    } on AppException catch (e) {
      state.value = ApiState<ProfileModel>.fromException(e);
    } catch (e) {
      state.value = ApiState<ProfileModel>.serverError(e.toString());
    }
  }

  Future<void> reload() => load();

  /// Replaces the cached profile after a successful edit (`PUT /profile`) so the
  /// Profile screen reflects the change without another round-trip.
  void applyUpdated(ProfileModel updated) {
    state.value = ApiState<ProfileModel>.success(updated);
  }

  // ---- Label resolution -----------------------------------------------------

  String? _nameFor(String key, int? id) {
    if (id == null) return null;
    for (final LookupItem i in _lookup.itemsOf(key)) {
      if (i.id == id) return i.name;
    }
    return null;
  }

  String? genderLabel(String? genderId) =>
      _nameFor(LookupKeys.genders, genderId == null ? null : int.tryParse(genderId));

  String? maritalLabel(int? id) => _nameFor(LookupKeys.maritalStatuses, id);

  String? onBehalfLabel(int? id) => _nameFor(LookupKeys.onBehalf, id);

  String? languageLabel(int? id) => _nameFor(LookupKeys.languages, id);

  List<String> languageLabels(List<int> ids) => ids
      .map(languageLabel)
      .whereType<String>()
      .toList(growable: false);
}
