import 'package:get/get.dart';

import 'completion_controller.dart';
import 'interest_controller.dart';
import '../repositories/rewards_repository.dart';
import '../widgets/app_snackbar.dart';

/// Drives the profile's Redeem section: server state in, claim action out.
///
/// The claim button is enabled only when the server says `claimable` — i.e.
/// the member is FULLY verified and has not claimed before. Everything else
/// (pending review, already claimed) shows as a disabled state on the card.
class RewardsController extends GetxController {
  RewardsController(this._repo);

  final RewardsRepository _repo;

  final Rx<WelcomeBonusState> state = const WelcomeBonusState().obs;
  final RxBool loading = false.obs;
  final RxBool claiming = false.obs;

  /// Bumped once a claim succeeds so the claim screen can run its celebration
  /// exactly once per navigation.
  final RxInt claimSuccessTick = 0.obs;

  bool get claimable => state.value.claimable && !claiming.value;
  bool get claimed => state.value.claimed;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    try {
      state.value = await _repo.fetchStatus();
    } catch (_) {
      // Keep last known state; the card still renders disabled rather than
      // shouting an error for a purely informational bonus.
    } finally {
      loading.value = false;
    }
  }

  /// Claims the 25 coins. Returns true on success (screen plays animation).
  Future<bool> claim() async {
    if (!claimable) return false;
    claiming.value = true;
    try {
      final WelcomeBonusState next = await _repo.claim();
      state.value = WelcomeBonusState(
        coins: next.coins,
        eligible: next.eligible,
        claimed: true,
        claimable: false,
        claimedAt: next.claimedAt ?? DateTime.now(),
        balance: next.balance,
        justClaimed: true,
      );
      claimSuccessTick.value++;
      // The same wallet powers interests/shortlist/chat — refresh every
      // surface that shows the balance so nothing disagrees.
      if (Get.isRegistered<InterestController>()) {
        Get.find<InterestController>().refreshCoins();
      }
      // Completion Center analytics + the reward ledger now has a new row.
      if (Get.isRegistered<CompletionController>()) {
        final CompletionController completion = Get.find<CompletionController>();
        completion.track(
          'welcome_bonus_claimed',
          featureKey: 'rewards',
          source: 'redeem_screen',
          metadata: <String, dynamic>{'coins': next.coins},
        );
        completion.loadRewards();
      }
      return true;
    } catch (e) {
      AppSnackbar.error('Could not claim: $e');
      return false;
    } finally {
      claiming.value = false;
    }
  }
}
