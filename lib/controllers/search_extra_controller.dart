import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../exceptions/app_exceptions.dart';
import '../models/search_filter_profile_model.dart';
import '../repositories/discover_extra_repository.dart';
import '../repositories/search_extra_repository.dart';
import '../widgets/app_snackbar.dart';

/// Saved searches, search history, recently viewed profiles, hidden users.
class SearchExtraController extends GetxController {
  SearchExtraController(this._repo, this._discover);

  final SearchExtraRepository _repo;
  final DiscoverExtraRepository _discover;

  final RxList<Map<String, dynamic>> savedSearches = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> searchHistory = <Map<String, dynamic>>[].obs;
  final RxBool loading = false.obs;

  /// Profiles this account has opened, newest first (`GET /profile-views`).
  final RxList<ViewedProfile> recentlyViewed = <ViewedProfile>[].obs;
  final RxBool loadingRecentlyViewed = false.obs;
  final RxBool clearingHistory = false.obs;

  Future<void> loadSaved() async {
    loading.value = true;
    try {
      savedSearches.assignAll(await _repo.fetchSaved());
    } on AppException catch (e) {
      debugPrint('Failed to load saved searches: ${e.message}');
    } catch (e) {
      debugPrint('Failed to load saved searches: $e');
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadHistory() async {
    try {
      searchHistory.assignAll(await _repo.fetchHistory());
    } catch (_) {}
  }

  /// `DELETE /search/history` — the list is emptied here first so the screen
  /// responds to the tap immediately, then refilled from the server's answer.
  Future<void> clearHistory() async {
    if (clearingHistory.value) return;
    clearingHistory.value = true;
    try {
      final int deleted = await _discover.clearSearchHistory();
      searchHistory.clear();
      AppSnackbar.success(deleted == 0
          ? 'Your search history is already empty.'
          : 'Search history cleared.');
    } catch (e) {
      AppSnackbar.error('Could not clear history: $e');
    } finally {
      clearingHistory.value = false;
    }
  }

  /// `DELETE /search/history/{id}` — removes a single entry.
  Future<void> deleteHistoryEntry(int id) async {
    try {
      await _discover.deleteSearchHistory(id);
      searchHistory.removeWhere((Map<String, dynamic> item) =>
          (item['id'] is int ? item['id'] as int : int.tryParse('${item['id']}')) == id);
    } catch (e) {
      AppSnackbar.error('Could not remove that search: $e');
    }
  }

  /// Recently viewed profiles (`GET /profile-views`).
  Future<void> loadRecentlyViewed() async {
    loadingRecentlyViewed.value = true;
    try {
      recentlyViewed.assignAll(await _discover.fetchRecentlyViewed());
    } on AppException catch (e) {
      debugPrint('Failed to load recently viewed: ${e.message}');
    } catch (e) {
      debugPrint('Failed to load recently viewed: $e');
    } finally {
      loadingRecentlyViewed.value = false;
    }
  }

  Future<void> saveSearch(String name, SearchFilterModel filter) async {
    try {
      await _repo.saveSearch(name: name, filters: filter.toQueryParams());
      await loadSaved();
    } catch (_) {}
  }

  Future<void> deleteSaved(int id) async {
    try {
      await _repo.deleteSaved(id);
      savedSearches.removeWhere((s) => s['id'] == id);
    } catch (_) {}
  }

  Future<void> hideUser(int userId) async {
    try {
      await _repo.hideFrom(userId: userId);
    } catch (_) {}
  }

  Future<void> unhideUser(int userId) async {
    try {
      await _repo.unhideFrom(userId);
    } catch (_) {}
  }
}
