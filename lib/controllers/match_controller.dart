import 'package:get/get.dart';
import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../models/search_filter_profile_model.dart';
import '../repositories/match_repository.dart';

/// Drives the Matches screen: smart matches, recommended, daily.
class MatchController extends GetxController {
  MatchController(this._repo);

  final MatchRepository _repo;

  final Rx<ApiState<SearchProfilesPage>> smartState =
      const ApiState<SearchProfilesPage>.initial().obs;
  final Rx<ApiState<SearchProfilesPage>> recommendedState =
      const ApiState<SearchProfilesPage>.initial().obs;
  final Rx<ApiState<SearchProfilesPage>> dailyState =
      const ApiState<SearchProfilesPage>.initial().obs;

  final RxBool isLoadingMore = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSmart();
    loadRecommended();
    loadDaily();
  }

  Future<void> loadSmart({bool showLoading = true}) async {
    if (showLoading) smartState.value = const ApiState<SearchProfilesPage>.loading();
    try {
      final SearchProfilesPage page = await _repo.fetchMatches();
      smartState.value = page.isEmpty
          ? const ApiState<SearchProfilesPage>.empty(message: 'No matches found.')
          : ApiState<SearchProfilesPage>.success(page);
    } on AppException catch (e) {
      smartState.value = ApiState<SearchProfilesPage>.fromException(e);
    } catch (e) {
      smartState.value = ApiState<SearchProfilesPage>.serverError(e.toString());
    }
  }

  Future<void> loadRecommended({bool showLoading = true}) async {
    if (showLoading) recommendedState.value = const ApiState<SearchProfilesPage>.loading();
    try {
      final SearchProfilesPage page = await _repo.fetchRecommended();
      recommendedState.value = page.isEmpty
          ? const ApiState<SearchProfilesPage>.empty(message: 'No recommended matches.')
          : ApiState<SearchProfilesPage>.success(page);
    } on AppException catch (e) {
      recommendedState.value = ApiState<SearchProfilesPage>.fromException(e);
    } catch (e) {
      recommendedState.value = ApiState<SearchProfilesPage>.serverError(e.toString());
    }
  }

  Future<void> loadDaily({bool showLoading = true}) async {
    if (showLoading) dailyState.value = const ApiState<SearchProfilesPage>.loading();
    try {
      final SearchProfilesPage page = await _repo.fetchDaily();
      dailyState.value = page.isEmpty
          ? const ApiState<SearchProfilesPage>.empty(message: 'No daily matches.')
          : ApiState<SearchProfilesPage>.success(page);
    } on AppException catch (e) {
      dailyState.value = ApiState<SearchProfilesPage>.fromException(e);
    } catch (e) {
      dailyState.value = ApiState<SearchProfilesPage>.serverError(e.toString());
    }
  }

  Future<void> sendFeedback(int userId, String feedback, {String? note}) async {
    try {
      await _repo.sendFeedback(userId: userId, feedback: feedback, note: note);
    } catch (_) {}
  }

  Future<void> refreshAll() async {
    await Future.wait(<Future<void>>[
      loadSmart(showLoading: false),
      loadRecommended(showLoading: false),
      loadDaily(showLoading: false),
    ]);
  }
}
