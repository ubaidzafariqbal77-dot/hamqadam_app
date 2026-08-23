import 'package:get/get.dart';

import '../constants/app_lookups.dart';
import '../core/api/api_response.dart';
import '../core/storage/profile_completion_service.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';
import '../models/privacy_settings_model.dart';
import '../models/profile_model.dart';
import '../models/public_profile_model.dart';
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

  // ---- Privacy / visibility / deactivation ---------------------------------

  /// True while one of the mutating profile actions below is in flight, so the
  /// UI can disable its switches without flipping the whole screen to loading.
  final RxBool mutating = false.obs;
  final RxnString actionError = RxnString();

  /// Current privacy switches, derived from the loaded profile.
  ///
  /// NOTE: `do_not_disturb` and `invisible_mode` are accepted by the update
  /// endpoint but are NOT echoed by the read resource, so they always read
  /// false here. Keep the local value after a successful save rather than
  /// re-reading it.
  PrivacySettingsModel get privacySettings {
    final ProfilePrivacy? p = profile?.privacy;
    if (p == null) return const PrivacySettingsModel();
    return PrivacySettingsModel(
      showPhoto: p.showPhoto,
      showGallery: p.showGallery,
      showContact: p.showContact,
      showEmail: p.showEmail,
      showPhone: p.showPhone,
      showLocation: p.showLocation,
      allowProfileViewNotifications: p.allowProfileViewNotifications,
    );
  }

  /// `PATCH /profile/privacy`. Sends only what changed. Returns null on
  /// success, or a message to show.
  Future<String?> updatePrivacy(PrivacySettingsModel updated) async {
    final Map<String, dynamic> body = updated.changesFrom(privacySettings);
    if (body.isEmpty) return null;
    return _mutate(() async {
      await _repo.updatePrivacy(body);
      // The endpoint returns the privacy block only, so re-read the profile to
      // keep every derived view consistent.
      await load();
    });
  }

  /// `PATCH /profile/visibility` — hides or shows the profile in search and
  /// matches. Returns null on success, or a message to show.
  Future<String?> setHidden(bool hidden) => _mutate(() async {
    final ProfileModel updated = await _repo.updateVisibility(hideProfile: hidden);
    state.value = ApiState<ProfileModel>.success(updated);
  });

  /// `POST /profile/deactivate`.
  ///
  /// Removes the member from search and matching; reactivation needs support.
  /// Confirm with the member BEFORE calling this. Returns the server message on
  /// success so the caller can show it while signing out.
  Future<({String? error, String? message})> deactivate() async {
    mutating.value = true;
    actionError.value = null;
    try {
      final String message = await _repo.deactivate();
      return (error: null, message: message);
    } on AppException catch (e) {
      actionError.value = e.message;
      return (error: e.message, message: null);
    } catch (e) {
      actionError.value = e.toString();
      return (error: e.toString(), message: null);
    } finally {
      mutating.value = false;
    }
  }

  Future<String?> _mutate(Future<void> Function() action) async {
    if (mutating.value) return null;
    mutating.value = true;
    actionError.value = null;
    try {
      await action();
      return null;
    } on AppException catch (e) {
      actionError.value = e.message;
      return e.message;
    } catch (e) {
      actionError.value = e.toString();
      return e.toString();
    } finally {
      mutating.value = false;
    }
  }

  // ---- Other members -------------------------------------------------------

  /// `GET /profiles/{id}` — another member's profile.
  ///
  /// Carries a verification badge only; the AI internals are the owner's.
  Future<PublicProfileModel?> fetchPublicProfile(int id) async {
    try {
      return await _repo.fetchPublicProfile(id);
    } on AppException catch (e) {
      actionError.value = e.message;
      return null;
    }
  }

  /// `GET /profiles/{id}/compatibility`
  Future<CompatibilityModel?> fetchCompatibility(int id) async {
    try {
      return await _repo.fetchCompatibility(id);
    } on AppException catch (e) {
      actionError.value = e.message;
      return null;
    }
  }

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

  List<String> languageLabels(List<int> ids) =>
      ids.map(languageLabel).whereType<String>().toList(growable: false);
}
