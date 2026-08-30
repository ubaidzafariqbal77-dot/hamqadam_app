import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../exceptions/app_exceptions.dart';
import '../models/search_filter_profile_model.dart';
import '../repositories/search_extra_repository.dart';

/// Saved searches, search history, hidden users.
class SearchExtraController extends GetxController {
  SearchExtraController(this._repo);

  final SearchExtraRepository _repo;

  final RxList<Map<String, dynamic>> savedSearches = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> searchHistory = <Map<String, dynamic>>[].obs;
  final RxBool loading = false.obs;

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
