import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_lookups.dart';
import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';
import '../models/profile_model.dart';
import '../models/user_model.dart';
import '../models/search_filter_profile_model.dart';
import '../repositories/search_repository.dart';
import 'auth_controller.dart';
import 'lookup_controller.dart';
import 'profile_controller.dart';
import 'shortlist_controller.dart';


/// Drives the Search / Discover dashboard screen:
/// - Fetches `GET /search/profiles` with dynamic query filters
/// - Manages active filters and draft filters (for bottom sheet)
/// - Supports infinite scroll pagination and pull-to-refresh
/// - Resolves lookup ids into human readable labels
class SearchProfilesController extends GetxController {
  SearchProfilesController({
    required SearchRepository repository,
    required LookupController lookupController,
  })  : _repo = repository,
        _lookup = lookupController;

  final SearchRepository _repo;
  final LookupController _lookup;

  static const int _perPage = 20;

  /// Main screen state holding the profiles page.
  final Rx<ApiState<SearchProfilesPage>> state =
      const ApiState<SearchProfilesPage>.initial().obs;

  /// Active filter criteria applied to the current search.
  final Rx<SearchFilterModel> filter = SearchFilterModel.empty().obs;

  /// Temporary filter state edited within the filter bottom sheet.
  final Rx<SearchFilterModel> draftFilter = SearchFilterModel.empty().obs;

  /// Indicates if an infinite-scroll next page is currently being loaded.
  final RxBool isLoadingMore = false.obs;

  /// Shortlisted user IDs.
  final RxSet<int> shortlistedUserIds = <int>{}.obs;

  /// Ignored user IDs to hide from current view.
  final RxSet<int> ignoredUserIds = <int>{}.obs;

  /// Search text editing controller for the dashboard search bar.
  final TextEditingController searchInputController = TextEditingController();
  Timer? _debounceTimer;

  SearchProfilesPage? get pageData => state.value.data;
  List<SearchProfileModel> get profiles => pageData?.profiles ?? <SearchProfileModel>[];
  /// What the grid renders: ignored members removed, and — the last line of
  /// defence for the opposite-gender rule — anything the backend returned that
  /// is not the allowed gender dropped. Sending `gender` on the query is a
  /// request; this makes it a guarantee.
  List<SearchProfileModel> get visibleProfiles {
    final String? allowed = _allowedGender;
    return profiles.where((SearchProfileModel p) {
      if (ignoredUserIds.contains(p.id)) return false;
      if (allowed == null) return true;
      final String g = (p.gender ?? '').trim();
      // An unlabelled profile is kept: hiding it would be guessing.
      return g.isEmpty || g == allowed;
    }).toList();
  }
  bool get hasMore => pageData?.hasMore ?? false;
  int get activeFilterCount => filter.value.activeFilterCount;

  bool isShortlisted(int userId) {
    if (Get.isRegistered<ShortlistController>()) {
      return Get.find<ShortlistController>().isShortlisted(userId);
    }
    return shortlistedUserIds.contains(userId);
  }

  void toggleShortlist(int userId, {String? displayName}) {
    if (Get.isRegistered<ShortlistController>()) {
      Get.find<ShortlistController>().toggleShortlist(userId, displayName: displayName);
    } else {
      if (shortlistedUserIds.contains(userId)) {
        shortlistedUserIds.remove(userId);
      } else {
        shortlistedUserIds.add(userId);
      }
    }
  }


  void ignoreProfile(int userId) {
    ignoredUserIds.add(userId);
  }

  void unignoreProfile(int userId) {
    ignoredUserIds.remove(userId);
  }

  /// Watches the profile until it reveals the member's gender. Disposed as soon
  /// as it fires, and again in [onClose] if it never did.
  Worker? _genderWorker;

  @override
  void onInit() {
    super.onInit();
    _warmLookups();
    _lockFilterToOppositeGender();
    if (_allowedGender == null && _awaitGender()) {
      // Hold the grid on its spinner rather than showing an unfiltered page
      // that would flash the member's own gender before the corrected reload.
      state.value = const ApiState<SearchProfilesPage>.loading();
      return;
    }
    loadProfiles();
  }

  /// Kicks off the profile fetch that carries `member.gender` and reloads once
  /// it lands. Returns false when the gender cannot be resolved that way, in
  /// which case the caller should just search unfiltered.
  ///
  /// `ProfileController` is registered lazily and only fetches `/profile` when
  /// the Profile tab is first opened — so on a fresh login, opening Discover
  /// first left the gender unknown. Resolving it here is what makes the rule
  /// hold from the very first search instead of from the second.
  bool _awaitGender() {
    if (!Get.isRegistered<ProfileController>() && !Get.isPrepared<ProfileController>()) {
      return false;
    }
    final ProfileController profile = Get.find<ProfileController>();
    if (_allowedGender != null) return false; // already there, nothing to wait for

    // The profile has already settled and still tells us nothing (it failed, or
    // the member record carries no gender). Waiting on `ever` here would hang
    // the grid on a spinner that nothing is left to resolve.
    final ApiState<ProfileModel> now = profile.state.value;
    if (!now.isLoading && !now.isInitial) return false;

    _genderWorker = ever<ApiState<ProfileModel>>(profile.state, (ApiState<ProfileModel> s) {
      if (s.isLoading || s.isInitial) return;
      // Either the gender arrived or the profile failed; both end the wait, so
      // a broken /profile call degrades to an unfiltered search instead of a
      // permanently empty screen.
      _disposeGenderWorker();
      _lockFilterToOppositeGender();
      loadProfiles();
    });
    return true;
  }

  void _disposeGenderWorker() {
    _genderWorker?.dispose();
    _genderWorker = null;
  }

  // ---- Opposite-gender rule -------------------------------------------------
  //
  // Discover only ever shows the other gender: a male member sees women, a
  // female member sees men. This is a rule, not a preference — the gender
  // filter is not something the member can widen or clear, so it is applied to
  // the stored filter AND re-applied to every outgoing request, and the results
  // are screened once more on the way in.

  /// The signed-in member's gender as the API spells it ("1" male, "2" female).
  ///
  /// `/auth/me` does not carry it: gender lives on the PROFILE (`member.gender`
  /// — see the captured `dev_stubs/api_samples/profile.json`), which is why
  /// reading only `AuthController.user.gender` left this null and showed
  /// everybody both genders. The profile is preferred and the user record is a
  /// fallback for the window before the profile has loaded.
  String? get _myGender {
    if (Get.isRegistered<ProfileController>()) {
      final String? fromProfile =
          Get.find<ProfileController>().profile?.member.gender;
      if (fromProfile != null && fromProfile.trim().isNotEmpty) {
        return fromProfile.trim();
      }
    }
    if (Get.isRegistered<AuthController>()) {
      final UserModel? me = Get.find<AuthController>().user.value;
      final String? fromUser = me?.gender;
      if (fromUser != null && fromUser.trim().isNotEmpty) return fromUser.trim();
      // Some payloads nest the member record inside the user object.
      final dynamic nested = me?.raw['member'];
      if (nested is Map<String, dynamic>) {
        final String nestedGender = (nested['gender'] ?? '').toString().trim();
        if (nestedGender.isNotEmpty) return nestedGender;
      }
    }
    return null;
  }

  /// The only gender Discover may show, or null while the member's own gender
  /// is still unknown (a fresh session that has not loaded the profile yet).
  String? get _allowedGender => switch (_myGender) {
        '1' => '2',
        '2' => '1',
        _ => null,
      };

  /// Forces [f] onto the allowed gender. A no-op while [_allowedGender] is
  /// null, so an unknown gender degrades to the old unfiltered behaviour
  /// instead of returning an empty screen.
  SearchFilterModel _lockGender(SearchFilterModel f) {
    final String? allowed = _allowedGender;
    return allowed == null ? f : f.copyWith(gender: allowed);
  }

  /// Pins the live and draft filters to the allowed gender.
  void _lockFilterToOppositeGender() {
    filter.value = _lockGender(filter.value);
    draftFilter.value = _lockGender(draftFilter.value);
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _disposeGenderWorker();
    searchInputController.dispose();
    super.onClose();
  }

  void _warmLookups() {
    // Preload lookups needed for filtering & profile cards display
    _lookup.ensure(LookupKeys.maritalStatuses);
    _lookup.ensure(LookupKeys.religions);
    _lookup.ensure(LookupKeys.castes);
    _lookup.ensure(LookupKeys.countries);
    _lookup.ensure(LookupKeys.states);
    _lookup.ensure(LookupKeys.cities);
  }

  // ---- Fetch & Pagination ---------------------------------------------------

  /// Loads profiles for page 1 using the current [filter].
  Future<void> loadProfiles({bool showLoading = true}) async {
    // Re-applied on every load, not just once in `onInit`: the profile that
    // carries the member's gender is fetched lazily, so the first Discover
    // build can happen before the gender is known.
    _lockFilterToOppositeGender();
    if (showLoading) {
      state.value = const ApiState<SearchProfilesPage>.loading();
    }
    try {
      final SearchProfilesPage page = await _repo.fetchProfiles(
        filter: filter.value,
        page: 1,
        perPage: _perPage,
      );

      state.value = page.isEmpty
          ? const ApiState<SearchProfilesPage>.empty(
              message: 'No profiles match your search criteria. Try adjusting your filters.',
            )
          : ApiState<SearchProfilesPage>.success(page);
    } on AppException catch (e) {
      state.value = ApiState<SearchProfilesPage>.fromException(e);
    } catch (e) {
      state.value = ApiState<SearchProfilesPage>.serverError(e.toString());
    }
  }

  /// Pull-to-refresh handler.
  Future<void> reload() => loadProfiles(showLoading: false);

  /// Appends the next page to the existing list.
  Future<void> loadMore() async {
    final SearchProfilesPage? current = pageData;
    if (current == null || !current.hasMore || isLoadingMore.value || state.value.isLoading) {
      return;
    }

    isLoadingMore.value = true;
    try {
      final SearchProfilesPage next = await _repo.fetchProfiles(
        filter: _lockGender(filter.value),
        page: current.currentPage + 1,
        perPage: _perPage,
      );

      state.value = ApiState<SearchProfilesPage>.success(current.merge(next));
    } on AppException catch (_) {
      // Do not replace existing list on pagination error
    } catch (_) {
      // Do not replace existing list on pagination error
    } finally {
      isLoadingMore.value = false;
    }
  }

  // ---- Filter Actions -------------------------------------------------------

  /// Prepares the draft filter before opening the filter bottom sheet.
  void prepareDraftFilter() {
    draftFilter.value = _lockGender(filter.value);
  }

  /// Applies the draft filter or a new [SearchFilterModel] and reloads.
  ///
  /// The gender is re-pinned here too, so neither the filter sheet nor a
  /// "remove this filter" chip can widen the search to both genders.
  void applyFilter([SearchFilterModel? newFilter]) {
    filter.value = _lockGender(newFilter ?? draftFilter.value);
    loadProfiles();
  }

  /// Resets all filters back to empty — except the gender, which is a rule
  /// rather than a filter and survives the reset.
  void resetFilter() {
    filter.value = SearchFilterModel.empty();
    draftFilter.value = SearchFilterModel.empty();
    searchInputController.clear();
    _lockFilterToOppositeGender();
    loadProfiles();
  }

  /// Quick toggle for a single filter attribute.
  void toggleVerifiedOnly() {
    filter.value = filter.value.copyWith(verifiedOnly: !filter.value.verifiedOnly);
    loadProfiles();
  }

  void togglePhotoOnly() {
    filter.value = filter.value.copyWith(photoOnly: !filter.value.photoOnly);
    loadProfiles();
  }

  void toggleNearby() {
    filter.value = filter.value.copyWith(nearby: !filter.value.nearby);
    loadProfiles();
  }

  void setSort(String? sort) {
    filter.value = filter.value.copyWith(sort: sort);
    loadProfiles();
  }

  /// Handles search query input with debounce.
  void onSearchChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      filter.value = filter.value.copyWith(searchQuery: text.trim());
      loadProfiles(showLoading: false);
    });
  }

  void clearSearchQuery() {
    searchInputController.clear();
    filter.value = filter.value.copyWith(clearSearch: true);
    loadProfiles();
  }

  /// Toggles the partner-preference filter. When enabled, sends
  /// `partner_preference=false` so the backend filters results by the
  /// logged-in user's saved partner preferences.
  void togglePartnerPreferenceFilter() {
    filter.value = filter.value.copyWith(
      partnerPreferenceFilter: !filter.value.partnerPreferenceFilter,
    );
    loadProfiles();
  }

  // ---- Lookup Resolution Helpers -------------------------------------------

  String? _lookupName(String key, int? id) {
    if (id == null) return null;
    for (final LookupItem item in _lookup.itemsOf(key)) {
      if (item.id == id) return item.name;
    }
    return null;
  }

  String? maritalStatusLabel(int? id) => _lookupName(LookupKeys.maritalStatuses, id);
  String? religionLabel(int? id) => _lookupName(LookupKeys.religions, id);
  String? casteLabel(int? id) => _lookupName(LookupKeys.castes, id);
  String? countryLabel(int? id) => _lookupName(LookupKeys.countries, id);
  String? stateLabel(int? id) => _lookupName(LookupKeys.states, id);
  String? cityLabel(int? id) => _lookupName(LookupKeys.cities, id);

  String formatLocation(SearchProfileModel p) {
    final List<String> parts = <String>[];
    final String? city = cityLabel(p.cityId);
    final String? country = countryLabel(p.countryId);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (country != null && country.isNotEmpty) parts.add(country);
    return parts.join(', ');
  }
}
