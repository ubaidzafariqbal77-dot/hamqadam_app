import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_lookups.dart';
import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../models/lookup_item_model.dart';
import '../models/search_filter_profile_model.dart';
import '../repositories/search_repository.dart';
import 'lookup_controller.dart';
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
  List<SearchProfileModel> get visibleProfiles =>
      profiles.where((SearchProfileModel p) => !ignoredUserIds.contains(p.id)).toList();
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

  @override
  void onInit() {
    super.onInit();
    _warmLookups();
    loadProfiles();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    searchInputController.dispose();
    super.onClose();
  }

  void _warmLookups() {
    // Preload lookups needed for filtering & profile cards display
    _lookup.ensure(LookupKeys.genders);
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
        filter: filter.value,
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
    draftFilter.value = filter.value;
  }

  /// Applies the draft filter or a new [SearchFilterModel] and reloads.
  void applyFilter([SearchFilterModel? newFilter]) {
    filter.value = newFilter ?? draftFilter.value;
    loadProfiles();
  }

  /// Resets all filters back to empty and reloads.
  void resetFilter() {
    filter.value = SearchFilterModel.empty();
    draftFilter.value = SearchFilterModel.empty();
    searchInputController.clear();
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

  // ---- Lookup Resolution Helpers -------------------------------------------

  String? _lookupName(String key, int? id) {
    if (id == null) return null;
    for (final LookupItem item in _lookup.itemsOf(key)) {
      if (item.id == id) return item.name;
    }
    return null;
  }

  String? genderLabel(String? gender) {
    if (gender == null || gender.isEmpty) return null;
    final int? gid = int.tryParse(gender);
    return _lookupName(LookupKeys.genders, gid) ?? (gender == '1' ? 'Male' : gender == '2' ? 'Female' : gender);
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
