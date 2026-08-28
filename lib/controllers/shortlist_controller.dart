import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../core/storage/secure_storage_service.dart';
import '../exceptions/app_exceptions.dart';
import '../models/search_filter_profile_model.dart';
import '../models/shortlist_model.dart';
import '../repositories/shortlist_repository.dart';
import '../widgets/app_snackbar.dart';

class ShortlistController extends GetxController {
  ShortlistController(this._repo);

  final ShortlistRepository _repo;

  final Rx<ApiState<ShortlistPage>> state = const ApiState<ShortlistPage>.initial().obs;
  final RxList<SearchProfileModel> profiles = <SearchProfileModel>[].obs;
  final RxSet<int> shortlistedUserIds = <int>{}.obs;
  final RxSet<int> busyUserIds = <int>{}.obs;
  final RxBool isLoadingMore = false.obs;

  int _currentPage = 1;
  int _lastPage = 1;

  bool get hasMore => _currentPage < _lastPage;
  bool isShortlisted(int userId) => shortlistedUserIds.contains(userId);
  bool isBusy(int userId) => busyUserIds.contains(userId);

  bool get _hasToken =>
      Get.isRegistered<SecureStorageService>() &&
      Get.find<SecureStorageService>().hasToken;

  @override
  void onInit() {
    super.onInit();
    if (_hasToken) {
      loadShortlists();
    }
  }

  void reset() {
    profiles.clear();
    shortlistedUserIds.clear();
    busyUserIds.clear();
    state.value = const ApiState<ShortlistPage>.initial();
    _currentPage = 1;
    _lastPage = 1;
  }

  /// Loads shortlisted profiles (`GET /proposals/shortlists`).
  Future<void> loadShortlists({bool silent = false}) async {
    if (!_hasToken) return;

    if (!silent) {
      state.value = const ApiState<ShortlistPage>.loading();
    }
    try {
      final ShortlistPage page = await _repo.fetchShortlists(page: 1);

      _currentPage = page.currentPage;
      _lastPage = page.lastPage;
      profiles.assignAll(page.profiles);

      // Populate set of shortlisted IDs
      shortlistedUserIds.addAll(page.profiles.map((SearchProfileModel p) => p.id));

      state.value = page.isEmpty
          ? const ApiState<ShortlistPage>.empty(message: 'No shortlisted profiles yet.')
          : ApiState<ShortlistPage>.success(page);
    } on AppException catch (e) {
      if (!silent) state.value = ApiState<ShortlistPage>.fromException(e);
    } catch (e) {
      if (!silent) state.value = ApiState<ShortlistPage>.serverError(e.toString());
    }
  }

  /// Loads the next page of shortlisted profiles.
  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore) return;
    isLoadingMore.value = true;
    try {
      final int nextPage = _currentPage + 1;
      final ShortlistPage page = await _repo.fetchShortlists(page: nextPage);
      _currentPage = page.currentPage;
      _lastPage = page.lastPage;
      profiles.addAll(page.profiles);
      shortlistedUserIds.addAll(page.profiles.map((SearchProfileModel p) => p.id));
      state.value = ApiState<ShortlistPage>.success(
        ShortlistPage(
          profiles: profiles,
          currentPage: _currentPage,
          lastPage: _lastPage,
          total: page.total,
        ),
      );
    } catch (_) {} finally {
      isLoadingMore.value = false;
    }
  }

  /// Checks and sets the shortlist state for a specific user.
  Future<bool> checkUserShortlistStatus(int userId) async {
    try {
      final bool isShort = await _repo.checkIsShortlisted(userId);
      if (isShort) {
        shortlistedUserIds.add(userId);
      } else {
        shortlistedUserIds.remove(userId);
      }
      return isShort;
    } catch (_) {
      return isShortlisted(userId);
    }
  }

  /// Toggles shortlist status for [userId].
  Future<bool> toggleShortlist(int userId, {String? displayName}) async {
    if (busyUserIds.contains(userId)) return isShortlisted(userId);
    busyUserIds.add(userId);

    final bool currentlyShortlisted = isShortlisted(userId);
    final String name = displayName ?? 'Member';

    try {
      if (currentlyShortlisted) {
        // Remove from shortlist
        await _repo.removeFromShortlist(userId);
        shortlistedUserIds.remove(userId);
        profiles.removeWhere((SearchProfileModel p) => p.id == userId);
        if (profiles.isEmpty) {
          state.value = const ApiState<ShortlistPage>.empty(message: 'No shortlisted profiles yet.');
        }
        AppSnackbar.info('Removed $name from Shortlist.');
        return false;
      } else {
        // Add to shortlist
        await _repo.addToShortlist(userId);
        shortlistedUserIds.add(userId);
        AppSnackbar.success('Added $name to Shortlist.');
        return true;
      }
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return currentlyShortlisted;
    } catch (e) {
      AppSnackbar.error('Failed to update shortlist.');
      return currentlyShortlisted;
    } finally {
      busyUserIds.remove(userId);
    }
  }

  /// Explicitly removes a profile from shortlist (e.g. from the Shortlist screen).
  Future<void> removeProfile(int userId, {String? displayName}) async {
    if (busyUserIds.contains(userId)) return;
    busyUserIds.add(userId);
    final String name = displayName ?? 'Member';
    try {
      await _repo.removeFromShortlist(userId);
      shortlistedUserIds.remove(userId);
      profiles.removeWhere((SearchProfileModel p) => p.id == userId);
      if (profiles.isEmpty) {
        state.value = const ApiState<ShortlistPage>.empty(message: 'No shortlisted profiles yet.');
      }
      AppSnackbar.info('Removed $name from Shortlist.');
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
    } catch (e) {
      AppSnackbar.error('Failed to remove from shortlist.');
    } finally {
      busyUserIds.remove(userId);
    }
  }
}
