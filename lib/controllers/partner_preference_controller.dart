import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../models/partner_preference_model.dart';
import '../repositories/partner_preference_repository.dart';

/// Drives the Partner Preferences screen.
///
/// These are not decoration: the backend filters the match pool with age,
/// marital status, religion, caste and preferred location. Saving here changes
/// what the member sees under Matches, so callers should refresh those lists
/// after [save] succeeds — see [changedFiltering].
class PartnerPreferenceController extends GetxController {
  PartnerPreferenceController(this._repo);

  final PartnerPreferenceRepository _repo;

  final Rx<ApiState<PartnerPreferenceModel>> state =
      const ApiState<PartnerPreferenceModel>.initial().obs;

  /// The working copy the form edits. Kept separate from [state] so an
  /// abandoned edit does not corrupt what was loaded.
  final Rx<PartnerPreferenceModel> draft = PartnerPreferenceModel.empty().obs;

  final RxBool saving = false.obs;
  final RxnString saveError = RxnString();

  /// Field errors from a 422, keyed by the SERVER's field names
  /// (`preferred_age_min`, not `ageMin`).
  final RxMap<String, List<String>> fieldErrors = <String, List<String>>{}.obs;

  /// Set when the last successful save altered a preference the match query
  /// filters on, so the caller knows to refresh matches rather than guessing.
  final RxBool changedFiltering = false.obs;

  PartnerPreferenceModel? get preferences => state.value.data;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    state.value = const ApiState<PartnerPreferenceModel>.loading();
    try {
      final PartnerPreferenceModel data = await _repo.fetch();
      draft.value = data;
      // An empty set is a real, valid state — the member simply has not set
      // preferences — so it is `success`, not `empty`. The UI shows an invite
      // to fill them in based on `isEmpty`.
      state.value = ApiState<PartnerPreferenceModel>.success(data);
    } on AppException catch (e) {
      state.value = ApiState<PartnerPreferenceModel>.fromException(e);
    } catch (e) {
      state.value = ApiState<PartnerPreferenceModel>.serverError(e.toString());
    }
  }

  Future<void> reload() => load();

  /// Applies an edit to the working copy without touching the server.
  void edit(PartnerPreferenceModel Function(PartnerPreferenceModel current) change) {
    draft.value = change(draft.value);
  }

  /// Saves the working copy.
  ///
  /// Only non-null values are sent, because every server rule is `sometimes`:
  /// a partial body never blanks a preference the member did not touch. To
  /// clear one on purpose, name it in [clearFields] using the SERVER's field
  /// name (e.g. `preferred_age_min`).
  ///
  /// Returns null on success, or a message to show.
  Future<String?> save({Set<String> clearFields = const <String>{}}) async {
    if (saving.value) return null;
    saving.value = true;
    saveError.value = null;
    fieldErrors.clear();
    changedFiltering.value = false;

    final PartnerPreferenceModel before = preferences ?? PartnerPreferenceModel.empty();

    try {
      final Map<String, dynamic> body = draft.value.toUpdateJson(explicitNulls: clearFields);

      if (body.isEmpty) {
        return null; // Nothing to save; not an error.
      }

      final PartnerPreferenceModel saved = await _repo.update(body);
      draft.value = saved;
      state.value = ApiState<PartnerPreferenceModel>.success(saved);
      changedFiltering.value = _filteringChanged(before, saved);
      return null;
    } on ValidationException catch (e) {
      fieldErrors.assignAll(e.errors);
      saveError.value = e.message;
      return e.message;
    } on AppException catch (e) {
      saveError.value = e.message;
      return e.message;
    } catch (e) {
      saveError.value = e.toString();
      return e.toString();
    } finally {
      saving.value = false;
    }
  }

  /// Clears every preference. Widens the match pool rather than emptying it.
  /// Returns null on success, or a message to show.
  Future<String?> clearAll() async {
    if (saving.value) return null;
    saving.value = true;
    saveError.value = null;
    try {
      await _repo.clear();
      final PartnerPreferenceModel empty = PartnerPreferenceModel.empty();
      draft.value = empty;
      state.value = ApiState<PartnerPreferenceModel>.success(empty);
      changedFiltering.value = true;
      return null;
    } on AppException catch (e) {
      saveError.value = e.message;
      return e.message;
    } catch (e) {
      saveError.value = e.toString();
      return e.toString();
    } finally {
      saving.value = false;
    }
  }

  /// First server-side error for a field, using the server's naming.
  String? errorFor(String serverField) {
    final List<String>? list = fieldErrors[serverField];
    return (list != null && list.isNotEmpty) ? list.first : null;
  }

  /// Did this save change something the match query actually filters on?
  /// Height, education, profession and income are scored rather than filtered,
  /// so changing them does not alter who is eligible.
  bool _filteringChanged(PartnerPreferenceModel a, PartnerPreferenceModel b) {
    return a.ageMin != b.ageMin ||
        a.ageMax != b.ageMax ||
        a.maritalStatusId != b.maritalStatusId ||
        a.religionId != b.religionId ||
        a.casteId != b.casteId ||
        a.countryId != b.countryId ||
        a.stateId != b.stateId ||
        a.cityId != b.cityId;
  }
}
