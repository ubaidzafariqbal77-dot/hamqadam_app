import 'package:get/get.dart';

import '../constants/feature_access.dart';

import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../models/interest_model.dart';
import '../repositories/interest_repository.dart';
import 'verification_controller.dart';

/// Outcome of sending an interest, so the caller can react without inspecting
/// exceptions. [needsCoins] is the case worth special-casing: route the member
/// to packages rather than showing a generic failure.
class SendInterestOutcome {
  const SendInterestOutcome({
    required this.sent,
    required this.message,
    this.needsCoins = false,
    this.alreadyExists = false,
    this.needsVerification = false,
    this.coinsSpent = 0,
  });

  final bool sent;
  final String message;
  final bool needsCoins;
  final bool alreadyExists;

  /// Blocked by the identity-verification gate rather than by coins — the
  /// caller should route to verification, not to the coin top-up.
  final bool needsVerification;

  final int coinsSpent;
}

/// Drives the Interests screen (sent / received tabs) and sending an interest
/// from a profile.
///
/// Coins: sending costs [coinBalance]'s `costPerInterest`; accepting, rejecting
/// and withdrawing are free. The cost is admin-configurable and echoed by the
/// server, so it is never assumed here.
class InterestController extends GetxController {
  InterestController(this._repo);

  final InterestRepository _repo;

  static const int _perPage = 15;

  final Rx<ApiState<InterestPage>> received = const ApiState<InterestPage>.initial().obs;
  final Rx<ApiState<InterestPage>> sent = const ApiState<InterestPage>.initial().obs;
  final Rx<InterestCoinBalance> coinBalance = InterestCoinBalance.empty().obs;

  /// Status filters currently applied to each tab (null = all).
  final RxnString receivedFilter = RxnString();
  final RxnString sentFilter = RxnString();

  /// Ids currently being accepted/rejected/withdrawn, so each row can show its
  /// own spinner instead of locking the whole list.
  final RxSet<int> busyIds = <int>{}.obs;

  /// User IDs to whom an interest has already been sent in this session.
  final RxSet<int> sentUserIds = <int>{}.obs;

  final RxBool sending = false.obs;

  /// Badge count for the bottom navigation.
  int get pendingReceived => received.value.data?.pendingCount ?? 0;

  bool isBusy(int id) => busyIds.contains(id);
  bool hasSentInterestTo(int userId) => sentUserIds.contains(userId);

  @override
  void onInit() {
    super.onInit();
    loadReceived();
    loadSent();
    refreshCoins();
  }

  // ---- Lists ---------------------------------------------------------------

  Future<void> loadReceived({String? status, bool keepFilter = false}) async {
    if (!keepFilter) receivedFilter.value = status;
    received.value = const ApiState<InterestPage>.loading();
    try {
      final InterestPage page = await _repo.fetchReceived(
        status: receivedFilter.value,
        perPage: _perPage,
      );
      received.value = page.isEmpty
          ? ApiState<InterestPage>.empty(message: _emptyReceivedMessage())
          : ApiState<InterestPage>.success(page);
    } on AppException catch (e) {
      received.value = ApiState<InterestPage>.fromException(e);
    } catch (e) {
      received.value = ApiState<InterestPage>.serverError(e.toString());
    }
  }

  Future<void> loadSent({String? status, bool keepFilter = false}) async {
    if (!keepFilter) sentFilter.value = status;
    sent.value = const ApiState<InterestPage>.loading();
    try {
      final InterestPage page = await _repo.fetchSent(status: sentFilter.value, perPage: _perPage);
      // The sent list carries the coin balance, so keep it in sync for free.
      if (page.coinBalance != null) coinBalance.value = page.coinBalance!;
      for (final InterestModel item in page.interests) {
        if (item.member != null) sentUserIds.add(item.member!.id);
      }
      sent.value = page.isEmpty
          ? ApiState<InterestPage>.empty(message: _emptySentMessage())
          : ApiState<InterestPage>.success(page);
    } on AppException catch (e) {
      sent.value = ApiState<InterestPage>.fromException(e);
    } catch (e) {
      sent.value = ApiState<InterestPage>.serverError(e.toString());
    }
  }

  /// Appends the next page. Silently does nothing when there is no next page or
  /// a load is already in flight.
  Future<void> loadMoreReceived() => _loadMore(received, isReceived: true);
  Future<void> loadMoreSent() => _loadMore(sent, isReceived: false);

  Future<void> _loadMore(Rx<ApiState<InterestPage>> target, {required bool isReceived}) async {
    final InterestPage? current = target.value.data;
    if (current == null || !current.hasMore || target.value.isLoading) return;
    try {
      final InterestPage next = isReceived
          ? await _repo.fetchReceived(
              status: receivedFilter.value,
              page: current.currentPage + 1,
              perPage: _perPage,
            )
          : await _repo.fetchSent(
              status: sentFilter.value,
              page: current.currentPage + 1,
              perPage: _perPage,
            );
      target.value = ApiState<InterestPage>.success(current.merge(next));
    } on AppException catch (_) {
      // A failed "load more" must not blank the rows already on screen.
    }
  }

  Future<void> refreshAll() async {
    await Future.wait<void>(<Future<void>>[
      loadReceived(keepFilter: true),
      loadSent(keepFilter: true),
      refreshCoins(),
    ]);
  }

  Future<void> refreshCoins() async {
    try {
      coinBalance.value = await _repo.fetchCoinBalance();
    } on AppException catch (_) {
      // Balance is informational; a failure here should not break the screen.
    }
  }

  // ---- Actions -------------------------------------------------------------

  /// The verification gate for the signed-in member.
  ///
  /// The API enforces nothing on `verification_status`, so this is the app's
  /// own policy — see [FeatureAccess], which documents the full matrix and why
  /// the same rules still need applying server-side.
  FeatureAccess get access {
    if (!Get.isRegistered<VerificationController>()) {
      return const FeatureAccess(VerificationGate.verified);
    }
    return Get.find<VerificationController>().access;
  }

  /// Sends an interest to [userId]. Spends coins on success.
  Future<SendInterestOutcome> sendInterest(int userId, {String? note}) async {
    if (sending.value) {
      return const SendInterestOutcome(sent: false, message: 'Already sending…');
    }

    // Held back until a moderator approves the identity. Checked before the
    // request so the member is not charged coins for a call the policy forbids.
    final String? blocked = access.reasonFor(AppFeature.sendInterest);
    if (blocked != null) {
      return SendInterestOutcome(sent: false, message: blocked, needsVerification: true);
    }
    sending.value = true;
    try {
      final InterestSendResult result = await _repo.send(userId: userId, note: note);
      sentUserIds.add(userId);
      if (result.coinBalance != null) coinBalance.value = result.coinBalance!;
      // The new row belongs in the sent tab.
      await loadSent(keepFilter: true);
      return SendInterestOutcome(
        sent: true,
        message: result.message.isEmpty ? 'Interest sent.' : result.message,
        coinsSpent: result.coinsSpent,
      );
    } on AppException catch (e) {
      // 402 insufficient_coins and 409 interest_exists are expected outcomes,
      // not crashes — the caller routes on them.
      //
      // Only ApiException carries the machine-readable `code`; fall back to the
      // status so this still works if the backend stops sending one.
      final String? code = e is ApiException ? e.code : null;
      final bool noCoins = code == 'insufficient_coins' || e.statusCode == 402;
      final bool exists = code == 'interest_exists' || e.statusCode == 409;
      if (exists) sentUserIds.add(userId);
      if (noCoins) await refreshCoins();
      return SendInterestOutcome(
        sent: false,
        message: e.message,
        needsCoins: noCoins,
        alreadyExists: exists,
      );
    } catch (e) {
      return SendInterestOutcome(sent: false, message: e.toString());
    } finally {
      sending.value = false;
    }
  }

  /// Accepting opens the chat thread for the pair server-side.
  Future<String?> accept(int id) => _respond(id, () => _repo.accept(id), 'Interest accepted.');

  Future<String?> reject(int id) => _respond(id, () => _repo.reject(id), 'Interest rejected.');

  /// Withdraw does NOT refund coins — the recipient was already notified.
  Future<String?> withdraw(int id) =>
      _respond(id, () => _repo.withdraw(id), 'Interest withdrawn.', refreshSent: true);

  /// Returns null on success, or the error message to show.
  Future<String?> _respond(
    int id,
    Future<InterestModel?> Function() action,
    String successFallback, {
    bool refreshSent = false,
  }) async {
    if (busyIds.contains(id)) return null;
    busyIds.add(id);
    try {
      await action();
      // Re-read rather than patching in place: accepting or rejecting changes
      // counts and filters, and the server is the authority on both.
      if (refreshSent) {
        await loadSent(keepFilter: true);
      } else {
        await loadReceived(keepFilter: true);
      }
      return null;
    } on AppException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    } finally {
      busyIds.remove(id);
    }
  }

  // ---- Copy ----------------------------------------------------------------

  String _emptyReceivedMessage() {
    final String? f = receivedFilter.value;
    if (f == null) return 'No one has expressed interest in you yet.';
    return 'No $f interests received.';
  }

  String _emptySentMessage() {
    final String? f = sentFilter.value;
    if (f == null) return 'You have not expressed interest in anyone yet.';
    return 'No $f interests sent.';
  }
}
