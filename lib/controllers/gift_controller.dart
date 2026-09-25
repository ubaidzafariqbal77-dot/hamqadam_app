import 'package:get/get.dart';

import '../controllers/interest_controller.dart';
import '../core/api/api_response.dart';
import '../core/utils/app_logger.dart';
import '../models/gift_model.dart';
import '../repositories/gift_repository.dart';
import '../widgets/app_snackbar.dart';

/// Gift module state. The coin balance is only ever READ from the backend
/// (`/interests/coin-balance` — the existing package wallet); nothing is
/// computed or stored locally as a source of truth.
class GiftController extends GetxController {
  GiftController(this._repo);

  final GiftRepository _repo;

  /// Gift catalog from `GET /gifts` (active only, sort_order ASC).
  final RxList<GiftModel> gifts = <GiftModel>[].obs;

  /// Current coin balance from the existing backend wallet.
  final RxInt coinBalance = 0.obs;
  final RxBool isBalanceLoading = false.obs;

  /// True while a send is in flight — the send button binds to this, so a
  /// double click cannot fire two requests.
  final RxBool isSending = false.obs;

  /// My Gifts tabs.
  final Rx<ApiState<List<GiftTransactionModel>>> receivedState =
      const ApiState<List<GiftTransactionModel>>.initial().obs;
  final Rx<ApiState<List<GiftTransactionModel>>> sentState =
      const ApiState<List<GiftTransactionModel>>.initial().obs;

  /// One gift transaction (deep-link detail).
  final Rx<ApiState<GiftTransactionModel>> transactionState =
      const ApiState<GiftTransactionModel>.initial().obs;

  bool _giftsLoaded = false;

  // ---- Catalog -------------------------------------------------------------

  Future<void> loadGifts({bool force = false}) async {
    if (_giftsLoaded && !force) return;
    try {
      gifts.assignAll(await _repo.fetchGifts());
      _giftsLoaded = true;
    } catch (e) {
      AppLogger.w('Failed to load gifts: $e');
    }
  }

  // ---- Balance (existing backend wallet) -------------------------------------

  /// Reads the coin balance from the existing interest wallet controller
  /// (`/interests/coin-balance` → members.remaining_interest). One wallet,
  /// one source of truth — no duplicate wallet or endpoint here.
  Future<void> refreshBalance() async {
    isBalanceLoading.value = true;
    try {
      if (Get.isRegistered<InterestController>()) {
        final InterestController interestCtrl = Get.find<InterestController>();
        await interestCtrl.refreshCoins();
        coinBalance.value = interestCtrl.coinBalance.value.remainingInterest;
      }
    } catch (_) {
      // Balance display is best-effort; the send itself re-checks server-side.
    } finally {
      isBalanceLoading.value = false;
    }
  }

  // ---- Send ------------------------------------------------------------------

  /// Sends a gift. Returns the server result, or null on failure (the
  /// snackbar explains why). [onInsufficientCoins] lets the UI open the
  /// existing coin purchase flow.
  Future<SendGiftResult?> sendGift({
    required int receiverId,
    required GiftModel gift,
    String? message,
    required int currentBalance,
    void Function()? onInsufficientCoins,
  }) async {
    // Front-end guard; the backend enforces the same rule inside the txn.
    if (currentBalance < gift.coins) {
      AppSnackbar.error(
        'Insufficient Coins — you need ${gift.coins} coins and you have $currentBalance.',
      );
      onInsufficientCoins?.call();
      return null;
    }

    if (isSending.value) return null; // double-click protection
    isSending.value = true;

    try {
      final SendGiftResult result = await _repo.sendGift(
        receiverId: receiverId,
        giftId: gift.id,
        message: message,
      );
      // The REAL balance after the send — straight from the backend wallet.
      coinBalance.value = result.remainingCoins;
      AppSnackbar.success('Gift sent!');
      // Sent list is now stale.
      sentState.value = const ApiState<List<GiftTransactionModel>>.initial();
      return result;
    } catch (e) {
      final String msg = e.toString();
      if (msg.contains('insufficient_coins') || msg.contains('Insufficient') || msg.contains('coin(s)')) {
        AppSnackbar.error('Insufficient coins. Please top up and try again.');
        onInsufficientCoins?.call();
      } else if (msg.contains('not available') || msg.contains('403')) {
        AppSnackbar.error('This member is not available for gifts.');
      } else if (msg.contains('yourself')) {
        AppSnackbar.error('You cannot send a gift to yourself.');
      } else {
        AppSnackbar.error('Could not send the gift. Please try again.');
      }
      return null;
    } finally {
      isSending.value = false;
    }
  }

  // ---- My Gifts ----------------------------------------------------------------

  Future<void> loadReceived({bool refresh = true}) async {
    if (refresh) receivedState.value = const ApiState<List<GiftTransactionModel>>.loading();
    try {
      final List<GiftTransactionModel> items = await _repo.fetchReceived();
      receivedState.value = items.isEmpty
          ? const ApiState<List<GiftTransactionModel>>.empty()
          : ApiState<List<GiftTransactionModel>>.success(items);
    } catch (e) {
      receivedState.value = ApiState<List<GiftTransactionModel>>.serverError(
        'Could not load received gifts.',
      );
    }
  }

  Future<void> loadSent({bool refresh = true}) async {
    if (refresh) sentState.value = const ApiState<List<GiftTransactionModel>>.loading();
    try {
      final List<GiftTransactionModel> items = await _repo.fetchSent();
      sentState.value = items.isEmpty
          ? const ApiState<List<GiftTransactionModel>>.empty()
          : ApiState<List<GiftTransactionModel>>.success(items);
    } catch (e) {
      sentState.value = ApiState<List<GiftTransactionModel>>.serverError(
        'Could not load sent gifts.',
      );
    }
  }

  Future<void> loadTransaction(int transactionId) async {
    transactionState.value = const ApiState<GiftTransactionModel>.loading();
    try {
      transactionState.value = ApiState<GiftTransactionModel>.success(
        await _repo.fetchTransaction(transactionId),
      );
    } catch (e) {
      transactionState.value = ApiState<GiftTransactionModel>.serverError(
        'Could not load the gift.',
      );
    }
  }
}
