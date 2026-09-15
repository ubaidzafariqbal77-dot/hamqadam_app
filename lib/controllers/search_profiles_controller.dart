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
import '../repositories/match_repository.dart';
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
    MatchRepository? matchRepository,
  })  : _repo = repository,
        _lookup = lookupController,
        _matchRepo = matchRepository;

  final SearchRepository _repo;
  final LookupController _lookup;
  final MatchRepository? _matchRepo;

  static const int _perPage = 20;

  /// How many profiles the AI Filtered mode shows — the matchmaking model's
  /// top five for this member.
  static const int _aiMatchLimit = 5;

  /// Main screen state holding the profiles page.
  final Rx<ApiState<SearchProfilesPage>> state =
      const ApiState<SearchProfilesPage>.initial().obs;

  /// Active filter criteria applied to the current search.
  final Rx<SearchFilterModel> filter = SearchFilterModel.empty().obs;

  /// Temporary filter state edited within the filter bottom sheet.
  final Rx<SearchFilterModel> draftFilter = SearchFilterModel.empty().obs;

  /// Whether the feed is narrowed to the AI matchmaking model's top 5.
  final RxBool aiFiltered = false.obs;

  /// State of the AI matches fetch backing [aiFiltered].
  final Rx<ApiState<SearchProfilesPage>> _aiState =
      const ApiState<SearchProfilesPage>.initial().obs;

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
  /// What the grid renders: server results put through the small number of
  /// filters the API does not (yet) apply itself, then ordered.
  ///
  /// 1. Ignored members and anything off the allowed gender are dropped.
  /// 2. `marital_status_id` — accepted by the form validation era of the API
  ///    but never implemented in [ProfileSearchService], so it is filtered
  ///    here over the fetched pages.
  /// 3. The keyword search — the service has no `search`/name clause at all,
  ///    so the search box is matched client-side against name and member
  ///    code across every loaded page (and pagination keeps fetching until
  ///    the pool is exhausted, below).
  ///
  /// When the member has NOT chosen a sort themselves, the survivors are then
  /// ordered by the API's `compatibility_percentage`, highest first, down to 0
  /// — so the best match is the first card, even if a page boundary or a
  /// backend ordering change ever rearranges the raw list. Unknown scores sink
  /// below known ones rather than cutting in. A member-chosen sort (Newest,
  /// Recently Active, …) is respected as-is.
  /// What the Discover body should render: the normal search state, or the
  /// AI-matches state while the feed is narrowed to the top 5.
  ApiState<SearchProfilesPage> get displayState =>
      aiFiltered.value ? _aiState.value : state.value;

  List<SearchProfileModel> get visibleProfiles {
    if (aiFiltered.value) return aiFilteredProfiles;
    final String? allowed = _allowedGender;
    final String query = (filter.value.searchQuery ?? '').trim().toLowerCase();
    final int? marital = filter.value.maritalStatusId;
    final List<SearchProfileModel> list = profiles.where((SearchProfileModel p) {
      if (ignoredUserIds.contains(p.id)) return false;
      if (allowed != null) {
        final String g = (p.gender ?? '').trim();
        // An unlabelled profile is kept: hiding it would be guessing.
        if (g.isNotEmpty && g != allowed) return false;
      }
      if (marital != null && p.maritalStatusId != marital) return false;
      if (query.isNotEmpty) {
        final String name = p.displayName.toLowerCase();
        final String code = (p.code ?? '').toLowerCase();
        if (!name.contains(query) && !code.contains(query)) return false;
      }
      return true;
    }).toList();

    final String? chosen = filter.value.sort;
    final bool memberChoseSort = chosen != null && chosen.isNotEmpty && chosen != 'default';
    if (!memberChoseSort) {
      list.sort((SearchProfileModel a, SearchProfileModel b) {
        final int? sa = a.compatibilityPercentage;
        final int? sb = b.compatibilityPercentage;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sb.compareTo(sa);
      });
    }
    return list;
  }
  /// The five best-matching profiles for the signed-in member, from the AI
  /// matchmaking service (`GET /matches`). If the service returns nothing, the
  /// current search results are ranked by their compatibility score instead, so
  /// the toggle always delivers a usable top 5. Ignored members and anything
  /// off the allowed gender are dropped, and unknown scores sink below known
  /// ones — the same rules as the main feed.
  List<SearchProfileModel> get aiFilteredProfiles {
    final SearchProfilesPage? aiPage = _aiState.value.data;
    final List<SearchProfileModel> source;
    if (aiPage == null) {
      source = const <SearchProfileModel>[];
    } else if (aiPage.isEmpty) {
      source = profiles; // graceful fallback: rank the current results
    } else {
      source = aiPage.profiles;
    }

    final String? allowed = _allowedGender;
    final List<SearchProfileModel> list = source.where((SearchProfileModel p) {
      if (ignoredUserIds.contains(p.id)) return false;
      if (allowed != null) {
        final String g = (p.gender ?? '').trim();
        // An unlabelled profile is kept: hiding it would be guessing.
        if (g.isNotEmpty && g != allowed) return false;
      }
      return true;
    }).toList()
      ..sort((SearchProfileModel a, SearchProfileModel b) {
        final int? sa = a.compatibilityPercentage;
        final int? sb = b.compatibilityPercentage;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sb.compareTo(sa);
      });

    if (list.length > _aiMatchLimit) {
      list.removeRange(_aiMatchLimit, list.length);
    }
    return list;
  }

  bool get hasMore => !aiFiltered.value && (pageData?.hasMore ?? false);
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

  /// The filter as actually sent to the API: the member's choices, the pinned
  /// opposite gender, and — when they have not picked a sort themselves — the
  /// default `sort=compatibility`, so the feed opens with the profiles that
  /// match the logged-in member best and descends toward 0%.
  ///
  /// The default lives here rather than in `filter.value` so it never lights
  /// the "filters active" badge or shows a removable "Sort" chip: it is the
  /// feed's natural order, not a filter the member applied.
  SearchFilterModel get _effectiveFilter {
    final SearchFilterModel f = _lockGender(filter.value);
    final String? sort = f.sort;
    if (sort == null || sort.isEmpty || sort == 'default') {
      return f.copyWith(sort: 'compatibility');
    }
    return f;
  }

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
        filter: _effectiveFilter,
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

  /// Pull-to-refresh handler — refreshes whichever feed is showing.
  Future<void> reload() => aiFiltered.value
      ? loadAiMatches(showLoading: false)
      : loadProfiles(showLoading: false);

  /// Flips the AI Filtered mode. Turning it on fetches the AI matchmaking
  /// service's top matches; pulling to refresh while the mode is on re-fetches
  /// them. Turning it off simply returns to the member's filtered feed.
  Future<void> toggleAiFiltered() async {
    if (aiFiltered.value) {
      aiFiltered.value = false;
      return;
    }
    aiFiltered.value = true;
    await loadAiMatches();
  }

  /// Fetches the AI matchmaking model's top matches for this member.
  Future<void> loadAiMatches({bool showLoading = true}) async {
    final MatchRepository? repo = _matchRepo;
    if (repo == null) {
      // No AI service available (e.g. tests): an empty AI page makes
      // [aiFilteredProfiles] rank the current search results instead of
      // showing an error the member cannot act on.
      _aiState.value = const ApiState<SearchProfilesPage>.success(SearchProfilesPage());
      return;
    }
    if (showLoading) {
      _aiState.value = const ApiState<SearchProfilesPage>.loading();
    }
    try {
      final SearchProfilesPage page =
          await repo.fetchMatches(page: 1, perPage: _aiMatchLimit);
      _aiState.value = ApiState<SearchProfilesPage>.success(page);
    } on AppException catch (e) {
      _aiState.value = ApiState<SearchProfilesPage>.fromException(e);
    } catch (e) {
      _aiState.value = ApiState<SearchProfilesPage>.serverError(e.toString());
    }
  }

  /// Appends the next page to the existing list.
  ///
  /// Standard single-page pagination. The `search` keyword is applied
  /// SERVER-side now (ProfileSearchService filters name/ID before paginating),
  /// so matches are reachable on every page and the old 3-pages-per-scroll
  /// workaround is no longer needed.
  Future<void> loadMore() async {
    final SearchProfilesPage? current = pageData;
    if (current == null || !current.hasMore || isLoadingMore.value || state.value.isLoading) {
      return;
    }

    isLoadingMore.value = true;
    try {
      final SearchProfilesPage next = await _repo.fetchProfiles(
        filter: _effectiveFilter,
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

  /// The search field's action / submit: commits the CURRENT text right away
  /// instead of waiting out the 500 ms debounce. Bound to
  /// `textInputAction: .search` and `onSubmitted` so "tap search on the
  /// keyboard" is a real action, and safe to call when the debounced run has
  /// already committed the same text.
  void submitSearch(String text) {
    _debounceTimer?.cancel();
    final String q = text.trim();
    if (q == (filter.value.searchQuery ?? '')) {
      // Already applied — just re-run the fetch so the tap always does
      // something (fresh results) rather than looking dead.
      loadProfiles(showLoading: false);
      return;
    }
    filter.value = filter.value.copyWith(searchQuery: q);
    loadProfiles();
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
