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

  /// History pagination — the server pages at 20 rows and the member's full
  /// search history should be reachable, not just the first page.
  final RxBool loadingMoreHistory = false.obs;
  int _historyPage = 1;
  bool _historyHasMore = false;

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
      final ({List<Map<String, dynamic>> items, int page, bool hasMore}) res =
          await _repo.fetchHistoryPaged(page: 1);
      searchHistory.assignAll(res.items);
      _historyPage = res.page;
      _historyHasMore = res.hasMore;
    } catch (_) {}
  }

  /// Appends the next page of history. No-op while a page is already in
  /// flight or the server says this was the last one.
  Future<void> loadMoreHistory() async {
    if (!_historyHasMore || loadingMoreHistory.value) {
      return;
    }
    loadingMoreHistory.value = true;
    try {
      final ({List<Map<String, dynamic>> items, int page, bool hasMore}) res =
          await _repo.fetchHistoryPaged(page: _historyPage + 1);
      // De-dup on id: a re-apply during the fetch could have reloaded page 1.
      final Set<int> seen = searchHistory
          .map((Map<String, dynamic> e) => (e['id'] as num?)?.toInt() ?? 0)
          .toSet();
      searchHistory.addAll(
        res.items.where((Map<String, dynamic> e) =>
            !seen.contains((e['id'] as num?)?.toInt() ?? 0)),
      );
      _historyPage = res.page;
      _historyHasMore = res.hasMore;
    } catch (_) {
      // A failed page load keeps what is on screen.
    } finally {
      loadingMoreHistory.value = false;
    }
  }

  /// `DELETE /search/history` — the list is emptied here first so the screen
  /// responds to the tap immediately, then refilled from the server's answer.
  Future<void> clearHistory() async {
    if (clearingHistory.value) return;
    clearingHistory.value = true;
    try {
      final int deleted = await _discover.clearSearchHistory();
      searchHistory.clear();
      _historyPage = 1;
      _historyHasMore = false;
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

  /// True while the server still has older history pages to load.
  bool get searchHistoryHasMore => _historyHasMore;

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
