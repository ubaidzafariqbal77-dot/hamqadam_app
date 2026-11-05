import 'package:get/get.dart';

import '../exceptions/app_exceptions.dart';
import '../models/appreciation_model.dart';
import '../repositories/appreciation_repository.dart';
import '../widgets/app_snackbar.dart';
import 'interest_controller.dart';

/// Like (free) and Super Like (coins), cached per member so every card and
/// the detail sheet show the same state. Shortlist stays in
/// ShortlistController; Interest/Proposal are untouched.
class AppreciationController extends GetxController {
  AppreciationController(this._repo);

  final AppreciationRepository _repo;

  final RxSet<int> likedIds = <int>{}.obs;
  final RxSet<int> superLikedIds = <int>{}.obs;
  final RxSet<int> busyIds = <int>{}.obs;
  final RxInt superLikeCost = 10.obs;

  final Set<int> _statusLoaded = <int>{};

  bool isLiked(int id) => likedIds.contains(id);
  bool isSuperLiked(int id) => superLikedIds.contains(id);
  bool isBusy(int id) => busyIds.contains(id);

  int get coinBalance => Get.isRegistered<InterestController>()
      ? Get.find<InterestController>().coinBalance.value.remainingInterest
      : 0;

  void reset() {
    likedIds.clear();
    superLikedIds.clear();
    busyIds.clear();
    _statusLoaded.clear();
  }

  /// Pulls the real state once per member (the cards start optimistic-empty).
  Future<void> ensureStatus(int userId, {bool force = false}) async {
    if (!force && _statusLoaded.contains(userId)) return;
    _statusLoaded.add(userId);
    try {
      final AppreciationStatus s = await _repo.fetchStatus(userId);
      s.liked ? likedIds.add(userId) : likedIds.remove(userId);
      s.superLiked ? superLikedIds.add(userId) : superLikedIds.remove(userId);
      superLikeCost.value = s.superLikeCost;
    } catch (_) {
      _statusLoaded.remove(userId);
    }
  }

  Future<void> toggleLike(int userId) async {
    if (busyIds.contains(userId)) return;
    busyIds.add(userId);
    try {
      final (bool liked, bool mutual) = await _repo.toggleLike(userId);
      liked ? likedIds.add(userId) : likedIds.remove(userId);
      if (mutual) {
        AppSnackbar.success("It's mutual! ❤️ You have liked each other's profiles.");
      } else if (liked) {
        AppSnackbar.success('Profile liked.');
      }
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('Could not update Like. Please try again.');
    } finally {
      busyIds.remove(userId);
    }
  }

  /// Sends the Super Like at the price the member confirmed. The server
  /// rejects (422, no charge) when that price is stale or coins are short.
  /// Returns true when the profile is (now or already) Super Liked.
  Future<bool> superLike(int userId, {required int quotedCost}) async {
    if (busyIds.contains(userId)) return false;
    busyIds.add(userId);
    try {
      final SuperLikeResult r = await _repo.superLike(userId, quotedCost: quotedCost);
      superLikedIds.add(userId);
      AppSnackbar.success(r.created
          ? 'Your Super Like has been sent successfully! ⭐'
          : 'You have already Super Liked this profile.');
      return true;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      // Price may have changed — refresh it for the next confirmation.
      _statusLoaded.remove(userId);
      ensureStatus(userId);
      return false;
    } catch (_) {
      AppSnackbar.error('Could not send Super Like. Please try again.');
      return false;
    } finally {
      busyIds.remove(userId);
      if (Get.isRegistered<InterestController>()) Get.find<InterestController>().refreshCoins();
    }
  }
}
