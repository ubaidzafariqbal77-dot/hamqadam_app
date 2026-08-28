import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../core/storage/current_user_service.dart';
import '../core/storage/secure_storage_service.dart';

import '../exceptions/app_exceptions.dart';
import '../models/proposal_model.dart';
import '../repositories/proposal_repository.dart';
import '../widgets/app_snackbar.dart';

class ProposalController extends GetxController {
  ProposalController(this._repo, this._currentUser);

  final ProposalRepository _repo;
  final CurrentUserService _currentUser;


  final Rx<ApiState<ProposalPage>> state = const ApiState<ProposalPage>.initial().obs;
  final RxList<ProposalModel> proposals = <ProposalModel>[].obs;
  final RxSet<int> sentProposalUserIds = <int>{}.obs;
  final RxSet<int> busyIds = <int>{}.obs;
  final RxBool isLoadingMore = false.obs;

  int _currentPage = 1;
  int _lastPage = 1;

  int get currentUserId => _currentUser.user?.id ?? 0;
  bool get hasMore => _currentPage < _lastPage;
  bool isBusy(int id) => busyIds.contains(id);

  List<ProposalModel> get sentProposals =>
      proposals.where((ProposalModel p) => p.sender?.id == currentUserId).toList();

  List<ProposalModel> get receivedProposals =>
      proposals.where((ProposalModel p) => p.recipient?.id == currentUserId || p.sender?.id != currentUserId).toList();

  bool hasSentProposalTo(int userId) {
    if (sentProposalUserIds.contains(userId)) return true;
    return sentProposals.any((ProposalModel p) => p.recipient?.id == userId && (p.isPending || p.isAccepted));
  }

  bool get _hasToken =>
      Get.isRegistered<SecureStorageService>() &&
      Get.find<SecureStorageService>().hasToken;

  @override
  void onInit() {
    super.onInit();
    if (_hasToken) {
      loadProposals();
    }
  }

  void reset() {
    proposals.clear();
    sentProposalUserIds.clear();
    busyIds.clear();
    state.value = const ApiState<ProposalPage>.initial();
    _currentPage = 1;
    _lastPage = 1;
  }

  /// Loads list of proposals (`GET /proposals`).
  Future<void> loadProposals({bool silent = false, String? status}) async {
    if (!_hasToken) return;

    if (!silent) {
      state.value = const ApiState<ProposalPage>.loading();
    }
    try {
      final ProposalPage page = await _repo.fetchProposals(page: 1, status: status);
      _currentPage = page.currentPage;
      _lastPage = page.lastPage;
      proposals.assignAll(page.proposals);

      _syncSentProposalUserIds();

      state.value = page.isEmpty

          ? const ApiState<ProposalPage>.empty(message: 'No proposals found.')
          : ApiState<ProposalPage>.success(page);
    } on AppException catch (e) {
      if (!silent) state.value = ApiState<ProposalPage>.fromException(e);
    } catch (e) {
      if (!silent) state.value = ApiState<ProposalPage>.serverError(e.toString());
    }
  }

  /// Loads next page of proposals.
  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore) return;
    isLoadingMore.value = true;
    try {
      final int nextPage = _currentPage + 1;
      final ProposalPage nextPageData = await _repo.fetchProposals(page: nextPage);
      _currentPage = nextPageData.currentPage;
      _lastPage = nextPageData.lastPage;

      proposals.addAll(nextPageData.proposals);
      _syncSentProposalUserIds();

      state.value = ApiState<ProposalPage>.success(
        ProposalPage(
          proposals: proposals,
          currentPage: _currentPage,
          lastPage: _lastPage,
          total: nextPageData.total,
        ),
      );
    } catch (_) {} finally {
      isLoadingMore.value = false;
    }
  }

  void _syncSentProposalUserIds() {
    for (final ProposalModel p in proposals) {
      if (p.sender?.id == currentUserId && p.recipient != null) {
        sentProposalUserIds.add(p.recipient!.id);
      }
    }
  }

  /// Sends a marriage proposal to [userId].
  Future<bool> sendProposal(int userId, {String? note, String? recipientName}) async {
    final String name = recipientName ?? 'Member';
    try {
      final ProposalModel result = await _repo.sendProposal(userId: userId, note: note);
      proposals.insert(0, result);
      sentProposalUserIds.add(userId);
      state.value = ApiState<ProposalPage>.success(
        ProposalPage(proposals: proposals, currentPage: _currentPage, lastPage: _lastPage, total: proposals.length),
      );
      AppSnackbar.success('Marriage proposal sent to $name successfully!');
      return true;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return false;
    } catch (e) {
      AppSnackbar.error('Failed to send proposal.');
      return false;
    }
  }

  /// Accepts a received proposal.
  Future<bool> acceptProposal(int id, {String? note}) async {
    if (busyIds.contains(id)) return false;
    busyIds.add(id);
    try {
      await _repo.acceptProposal(id, note: note);
      final int index = proposals.indexWhere((ProposalModel p) => p.id == id);
      if (index != -1) {
        final ProposalModel old = proposals[index];
        proposals[index] = ProposalModel(
          id: old.id,
          status: 'accepted',
          statusValue: 1,
          initialNote: old.initialNote,
          compatibilityPercentage: old.compatibilityPercentage,
          sender: old.sender,
          recipient: old.recipient,
          respondedAt: DateTime.now(),
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      AppSnackbar.success('Proposal accepted successfully!');
      return true;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return false;
    } catch (e) {
      AppSnackbar.error('Failed to accept proposal.');
      return false;
    } finally {
      busyIds.remove(id);
    }
  }

  /// Declines / rejects a received proposal.
  Future<bool> rejectProposal(int id, {String? note}) async {
    if (busyIds.contains(id)) return false;
    busyIds.add(id);
    try {
      await _repo.rejectProposal(id, note: note);
      final int index = proposals.indexWhere((ProposalModel p) => p.id == id);
      if (index != -1) {
        final ProposalModel old = proposals[index];
        proposals[index] = ProposalModel(
          id: old.id,
          status: 'rejected',
          statusValue: 2,
          initialNote: old.initialNote,
          compatibilityPercentage: old.compatibilityPercentage,
          sender: old.sender,
          recipient: old.recipient,
          respondedAt: DateTime.now(),
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      AppSnackbar.info('Proposal declined.');
      return true;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return false;
    } catch (e) {
      AppSnackbar.error('Failed to decline proposal.');
      return false;
    } finally {
      busyIds.remove(id);
    }
  }

  /// Withdraws a sent proposal.
  Future<bool> withdrawProposal(int id, {String? note}) async {
    if (busyIds.contains(id)) return false;
    busyIds.add(id);
    try {
      await _repo.withdrawProposal(id, note: note);
      final int index = proposals.indexWhere((ProposalModel p) => p.id == id);
      if (index != -1) {
        final ProposalModel old = proposals[index];
        proposals[index] = ProposalModel(
          id: old.id,
          status: 'withdrawn',
          statusValue: 3,
          initialNote: old.initialNote,
          compatibilityPercentage: old.compatibilityPercentage,
          sender: old.sender,
          recipient: old.recipient,
          withdrawnAt: DateTime.now(),
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
        if (old.recipient != null) {
          sentProposalUserIds.remove(old.recipient!.id);
        }
      }
      AppSnackbar.info('Proposal withdrawn.');
      return true;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return false;
    } catch (e) {
      AppSnackbar.error('Failed to withdraw proposal.');
      return false;
    } finally {
      busyIds.remove(id);
    }
  }

  /// Cancels a proposal.
  Future<bool> cancelProposal(int id, {String? note}) async {
    if (busyIds.contains(id)) return false;
    busyIds.add(id);
    try {
      await _repo.cancelProposal(id, note: note);
      final int index = proposals.indexWhere((ProposalModel p) => p.id == id);
      if (index != -1) {
        final ProposalModel old = proposals[index];
        proposals[index] = ProposalModel(
          id: old.id,
          status: 'cancelled',
          statusValue: 4,
          initialNote: old.initialNote,
          compatibilityPercentage: old.compatibilityPercentage,
          sender: old.sender,
          recipient: old.recipient,
          cancelledAt: DateTime.now(),
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
        if (old.recipient != null) {
          sentProposalUserIds.remove(old.recipient!.id);
        }
      }
      AppSnackbar.info('Proposal cancelled.');
      return true;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return false;
    } catch (e) {
      AppSnackbar.error('Failed to cancel proposal.');
      return false;
    } finally {
      busyIds.remove(id);
    }
  }
}
