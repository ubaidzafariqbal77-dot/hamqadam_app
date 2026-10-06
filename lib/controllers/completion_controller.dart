import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../models/completion_model.dart';
import '../repositories/completion_repository.dart';
import '../widgets/app_snackbar.dart';

/// Drives the Completion Center surfaces: the reward ledger under Redeem, the
/// NPS prompt, sponsored listings and the share link.
///
/// Every value comes from the server — nothing about a reward's size, its
/// label or the ledger's contents is decided in the app.
class CompletionController extends GetxController {
  CompletionController(this._repo);

  final CompletionRepository _repo;

  // ---- Reward ledger --------------------------------------------------------
  final Rx<ApiState<RewardLedgerPage>> rewardsState =
      const ApiState<RewardLedgerPage>.initial().obs;
  final RxBool loadingMoreRewards = false.obs;
  int _rewardsPage = 1;
  int _rewardsLastPage = 1;

  // ---- Sponsored listings ----------------------------------------------------
  final Rx<ApiState<List<SponsoredListingModel>>> sponsoredState =
      const ApiState<List<SponsoredListingModel>>.initial().obs;

  // ---- Share link ------------------------------------------------------------
  final RxString profileLink = ''.obs;
  final RxBool loadingProfileLink = false.obs;

  // ---- NPS -------------------------------------------------------------------
  final RxBool submittingNps = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadRewards();
  }

  /// `GET /completion/rewards` — the member's own reward ledger.
  Future<void> loadRewards() async {
    rewardsState.value = const ApiState<RewardLedgerPage>.loading();
    try {
      final RewardLedgerPage page = await _repo.fetchRewards();
      _rewardsPage = page.currentPage;
      _rewardsLastPage = page.lastPage;
      rewardsState.value = page.isEmpty
          ? const ApiState<RewardLedgerPage>.empty(
              message: 'No rewards yet.',
            )
          : ApiState<RewardLedgerPage>.success(page);
    } on AppException catch (e) {
      rewardsState.value = ApiState<RewardLedgerPage>.fromException(e);
    } catch (e) {
      rewardsState.value = ApiState<RewardLedgerPage>.serverError(e.toString());
    }
  }

  /// Appends the next ledger page. No-op on the last page or while in flight.
  Future<void> loadMoreRewards() async {
    if (loadingMoreRewards.value || _rewardsPage >= _rewardsLastPage) return;
    final RewardLedgerPage? current = rewardsState.value.data;
    if (current == null) return;

    loadingMoreRewards.value = true;
    try {
      final RewardLedgerPage next =
          await _repo.fetchRewards(page: _rewardsPage + 1);
      _rewardsPage = next.currentPage;
      _rewardsLastPage = next.lastPage;
      rewardsState.value = ApiState<RewardLedgerPage>.success(
        RewardLedgerPage(
          items: <RewardLedgerEntry>[...current.items, ...next.items],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        ),
      );
    } catch (_) {
      // Keep the pages already on screen; the next scroll can retry.
    } finally {
      loadingMoreRewards.value = false;
    }
  }

  /// `GET /completion/sponsored` — `empty` is a real state (`ad_free` plan).
  Future<void> loadSponsored() async {
    if (sponsoredState.value.isLoading) return;
    try {
      final List<SponsoredListingModel> list = await _repo.fetchSponsored();
      sponsoredState.value = ApiState<List<SponsoredListingModel>>.success(list);
    } on AppException catch (e) {
      sponsoredState.value = ApiState<List<SponsoredListingModel>>.fromException(e);
    } catch (e) {
      sponsoredState.value =
          ApiState<List<SponsoredListingModel>>.serverError(e.toString());
    }
  }

  /// `GET /completion/profile-link` — cached for the session.
  Future<String> loadProfileLink() async {
    if (profileLink.value.isNotEmpty) return profileLink.value;
    loadingProfileLink.value = true;
    try {
      profileLink.value = await _repo.fetchProfileLink();
      return profileLink.value;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return '';
    } catch (_) {
      AppSnackbar.error('Could not build your share link.');
      return '';
    } finally {
      loadingProfileLink.value = false;
    }
  }

  /// `POST /completion/nps` — returns true when the server accepted the score.
  Future<bool> submitNps(int score, {String? comment, String? context}) async {
    if (score < 0 || score > 10) return false;
    submittingNps.value = true;
    try {
      await _repo.submitNps(score: score, comment: comment, context: context);
      return true;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return false;
    } catch (_) {
      AppSnackbar.error('Could not send your feedback.');
      return false;
    } finally {
      submittingNps.value = false;
    }
  }

  /// `POST /completion/got-match` — member confirms they found a partner.
  Future<bool> reportGotMatch(int matchedUserId, {String? note}) async {
    try {
      await _repo.reportGotMatch(matchedUserId: matchedUserId, note: note);
      return true;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return false;
    } catch (_) {
      AppSnackbar.error('Could not save your response.');
      return false;
    }
  }

  /// `POST /completion/events` — fire-and-forget analytics.
  ///
  /// Deliberately never throws and never shows UI: telemetry must not interrupt
  /// whatever the member was doing when it fired.
  Future<void> track(
    String eventName, {
    String? featureKey,
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _repo.trackEvent(
        eventName: eventName,
        featureKey: featureKey,
        source: source,
        platform: 'app',
        metadata: metadata,
      );
    } catch (_) {
      // Intentionally ignored.
    }
  }
}
