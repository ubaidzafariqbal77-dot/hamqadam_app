import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../exceptions/app_exceptions.dart';
import '../models/search_filter_profile_model.dart';
import '../repositories/discover_extra_repository.dart';
import '../widgets/app_snackbar.dart';

/// Swipe Matching.
///
/// The deck is a plain list held newest-last, so the top card is
/// `deck.last` and both gestures (like / pass) only ever remove it. Nothing is
/// decided locally: every swipe is POSTed and the counters that come back are
/// the server's own, which keeps the deck honest if the same member swipes from
/// another device.
class SwipeController extends GetxController {
  SwipeController(this._repo);

  final DiscoverExtraRepository _repo;

  /// Cards still to judge — the last one is on top.
  final RxList<SearchProfileModel> deck = <SearchProfileModel>[].obs;

  final RxBool loading = false.obs;
  final RxBool swiping = false.obs;
  final RxString error = ''.obs;

  /// likes_sent / passes_sent / matches, straight from the API.
  final RxMap<String, int> summary = <String, int>{}.obs;

  /// The member's swipe filters (only the ones the deck endpoint accepts).
  final RxBool photoOnly = false.obs;
  final RxBool excludeViewed = false.obs;

  /// Members left in the deck according to the server.
  final RxInt remaining = 0.obs;

  SearchProfileModel? get topCard => deck.isEmpty ? null : deck.last;

  bool get hasCards => deck.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    loadDeck();
  }

  /// Loads the deck. [silent] keeps the current cards on screen while the new
  /// page is fetched (used by pull-to-refresh).
  Future<void> loadDeck({bool silent = false}) async {
    if (loading.value) return;
    loading.value = true;
    error.value = '';
    if (!silent) deck.clear();
    try {
      final SwipeDeck page = await _repo.fetchSwipeDeck(
        photoOnly: photoOnly.value,
        excludeViewed: excludeViewed.value,
      );
      deck.assignAll(page.candidates);
      remaining.value = page.remaining;
      if (page.summary.isNotEmpty) summary.assignAll(page.summary);
    } on AppException catch (e) {
      error.value = e.message;
    } catch (e) {
      error.value = '$e';
      debugPrint('Failed to load the swipe deck: $e');
    } finally {
      loading.value = false;
    }
  }

  /// Records a like or a pass on [profile] and drops the card.
  ///
  /// The card leaves the deck optimistically — a swipe that waits on the
  /// network reads as a broken gesture — and is put back if the request fails.
  Future<void> swipe(SearchProfileModel profile, {required bool like}) async {
    if (swiping.value) return;
    swiping.value = true;

    final int index = deck.indexWhere((SearchProfileModel p) => p.id == profile.id);
    if (index >= 0) deck.removeAt(index);

    try {
      final SwipeResult result = await _repo.swipe(userId: profile.id, like: like);
      if (result.summary.isNotEmpty) summary.assignAll(result.summary);
      remaining.value = remaining.value > 0 ? remaining.value - 1 : 0;

      if (result.isMatch) {
        final SearchProfileModel matched = result.matchedProfile ?? profile;
        _success("It's a match! ${matched.name ?? 'They'} liked you too.");
        _showMatchLocally(matched);
      }
    } catch (e) {
      if (index >= 0 && index <= deck.length) {
        deck.insert(index, profile);
      }
      _error('Could not save that swipe: $e');
    } finally {
      swiping.value = false;
    }
  }

  // --------------------------------------------------------------------------
  // Toasts
  // --------------------------------------------------------------------------
  //
  // A swipe can come back after the deck was popped, or while the app is
  // shutting down. A snackbar then has no context to attach to and used to
  // throw — which swallowed the real result of the request — so every message
  // here is skipped when there is nothing to show it in. The deck state and the
  // counters above are updated either way.

  void _success(String message) {
    if (Get.context != null) AppSnackbar.success(message);
  }

  void _info(String message) {
    if (Get.context != null) AppSnackbar.info(message);
  }

  void _error(String message) {
    if (Get.context != null) AppSnackbar.error(message);
  }

  /// `DELETE /matches/swipe/last` — puts the last card back on top.
  Future<void> undo() async {
    if (swiping.value) return;
    swiping.value = true;
    try {
      final SearchProfileModel? restored = await _repo.undoSwipe();
      if (restored == null) {
        _info('There is nothing to undo.');
        return;
      }
      deck.add(restored);
      _info('Last swipe undone.');
    } catch (e) {
      _error('Could not undo: $e');
    } finally {
      swiping.value = false;
    }
  }

  /// Called by the view so the match celebration lives in one place.
  void Function(SearchProfileModel profile)? onMatch;

  void _showMatchLocally(SearchProfileModel profile) {
    onMatch?.call(profile);
  }

  Future<void> togglePhotoOnly() async {
    photoOnly.toggle();
    await loadDeck();
  }

  Future<void> toggleExcludeViewed() async {
    excludeViewed.toggle();
    await loadDeck();
  }

  void reset() {
    deck.clear();
    summary.clear();
    remaining.value = 0;
    error.value = '';
  }
}
