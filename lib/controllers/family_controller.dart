import 'package:get/get.dart';
import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../repositories/family_repository.dart';
import '../widgets/app_snackbar.dart';

/// Family features: guardians, wali mode, approval requests, conversations, notes.
class FamilyController extends GetxController {
  FamilyController(this._repo);

  final FamilyRepository _repo;

  final Rx<ApiState<Map<String, dynamic>>> dashboardState =
      const ApiState<Map<String, dynamic>>.initial().obs;
  final RxList<Map<String, dynamic>> guardians = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> managedProfiles = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> approvalRequests = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> conversations = <Map<String, dynamic>>[].obs;
  final RxBool busy = false.obs;

  // ---- Dashboard
  Future<void> loadDashboard({int? profileUserId}) async {
    dashboardState.value = const ApiState.loading();
    try {
      final data = await _repo.fetchDashboard(profileUserId: profileUserId);
      dashboardState.value = ApiState.success(data);
    } on AppException catch (e) {
      dashboardState.value = ApiState.fromException(e);
    } catch (e) {
      dashboardState.value = ApiState.serverError(e.toString());
    }
  }

  // ---- Guardians
  Future<void> loadGuardians() async {
    try {
      guardians.assignAll(await _repo.fetchGuardians());
    } catch (_) {}
  }

  Future<bool> inviteGuardian({
    required int guardianUserId,
    required String relationship,
    List<String> permissions = const <String>[],
  }) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      await _repo.inviteGuardian(
        guardianUserId: guardianUserId,
        relationship: relationship,
        permissions: permissions,
      );
      AppSnackbar.success('Guardian invitation sent.');
      await loadGuardians();
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to invite guardian.');
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<void> approveGuardian(int guardianId) async {
    try {
      await _repo.approveGuardian(guardianId);
      AppSnackbar.success('Guardian approved.');
      await loadGuardians();
    } catch (e) {
      AppSnackbar.error('Failed to approve guardian.');
    }
  }

  Future<void> revokeGuardian(int guardianId) async {
    try {
      await _repo.revokeGuardian(guardianId);
      AppSnackbar.success('Guardian removed.');
      await loadGuardians();
    } catch (e) {
      AppSnackbar.error('Failed to remove guardian.');
    }
  }

  // ---- Wali Mode
  Future<void> toggleWaliMode(bool enabled) async {
    try {
      await _repo.toggleWaliMode(enabled: enabled);
      AppSnackbar.success(enabled ? 'Wali mode enabled.' : 'Wali mode disabled.');
    } catch (e) {
      AppSnackbar.error('Failed to toggle wali mode.');
    }
  }

  // ---- Managed Profiles
  Future<void> loadManagedProfiles() async {
    try {
      managedProfiles.assignAll(await _repo.fetchManagedProfiles());
    } catch (_) {}
  }

  // ---- Approval Requests
  Future<void> loadApprovalRequests() async {
    try {
      approvalRequests.assignAll(await _repo.fetchApprovalRequests());
    } catch (_) {}
  }

  Future<bool> approveRequest(int approvalId, {String? note}) async {
    try {
      await _repo.approveRequest(approvalId, note: note);
      AppSnackbar.success('Request approved.');
      await loadApprovalRequests();
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to approve request.');
      return false;
    }
  }

  Future<bool> rejectRequest(int approvalId, {String? note}) async {
    try {
      await _repo.rejectRequest(approvalId, note: note);
      AppSnackbar.success('Request rejected.');
      await loadApprovalRequests();
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to reject request.');
      return false;
    }
  }

  // ---- Notes
  Future<List<Map<String, dynamic>>> fetchNotes(int profileId) async {
    try {
      return await _repo.fetchNotes(profileId);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> addNote(int profileId, String note) async {
    try {
      await _repo.addNote(profileId: profileId, note: note);
      AppSnackbar.success('Note added.');
    } catch (e) {
      AppSnackbar.error('Failed to add note.');
    }
  }

  // ---- Conversations
  Future<void> loadConversations() async {
    try {
      conversations.assignAll(await _repo.fetchConversations());
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> fetchConversationMessages(int conversationId) async {
    try {
      return await _repo.fetchConversationMessages(conversationId);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<bool> sendMessage(int conversationId, String message) async {
    try {
      await _repo.sendMessage(conversationId: conversationId, message: message);
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to send message.');
      return false;
    }
  }
}
