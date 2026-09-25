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

  // ---- Guardian Mode state ------------------------------------------------

  /// Guardian Mode on/off (server flag: wali_mode_enabled).
  final RxBool guardianModeEnabled = false.obs;

  /// Permission catalog from `GET /family/guardian-mode/status`:
  /// `{<key>: <human label>}`.
  final RxMap<String, dynamic> permissionCatalog = <String, dynamic>{}.obs;

  /// Presets: `{view_only: [...], review: [...], participate: [...]}`.
  final RxMap<String, dynamic> permissionPresets = <String, dynamic>{}.obs;

  /// The member's sent guardian invitations.
  final RxList<Map<String, dynamic>> guardianInvitations = <Map<String, dynamic>>[].obs;

  /// Guardian's match-review feed for one managed profile.
  final RxList<Map<String, dynamic>> guardianMatches = <Map<String, dynamic>>[].obs;

  /// Guardian activity (audit) rows for one profile.
  final RxList<Map<String, dynamic>> guardianActivity = <Map<String, dynamic>>[].obs;

  /// Family introductions involving the caller.
  final RxList<Map<String, dynamic>> introductions = <Map<String, dynamic>>[].obs;

  /// Whether the member's wali/family-involvement mode is on (server flag).
  final RxBool waliModeEnabled = false.obs;

  /// Guardian digest preview: `{managed_profiles, new_proposals_this_week,
  /// pending_family_approvals}`.
  final RxMap<String, dynamic> digest = <String, dynamic>{}.obs;

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
      // The service echoes the new state; trust our intent when it does not.
      waliModeEnabled.value = enabled;
      AppSnackbar.success(enabled ? 'Wali mode enabled.' : 'Wali mode disabled.');
    } catch (e) {
      AppSnackbar.error('Failed to toggle wali mode.');
    }
  }

  // ---- Digest
  Future<void> loadDigest() async {
    try {
      digest.value = await _repo.fetchDigestPreview();
    } catch (_) {
      // Digest is a nice-to-have on this screen; silence is fine.
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

  /// Asks an approved guardian to approve something (e.g. a proposal chat).
  Future<bool> createApprovalRequest({
    required int guardianUserId,
    required String requestType,
    Map<String, dynamic>? payload,
  }) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      await _repo.requestApproval(<String, dynamic>{
        'guardian_user_id': guardianUserId,
        'request_type': requestType,
        if (payload != null) 'payload': payload,
      });
      AppSnackbar.success('Approval request sent.');
      await loadApprovalRequests();
      return true;
    } catch (e) {
      AppSnackbar.error('Could not send the approval request.');
      return false;
    } finally {
      busy.value = false;
    }
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

  // ---- Guardian Mode (spec §5–§25) ----------------------------------------

  Future<void> loadGuardianModeStatus() async {
    try {
      final Map<String, dynamic> status = await _repo.fetchGuardianModeStatus();
      guardianModeEnabled.value = status['enabled'] == true;
      permissionCatalog.assignAll(
        (status['permissions'] as Map<String, dynamic>? ?? <String, dynamic>{}).cast<String, dynamic>(),
      );
      permissionPresets.assignAll(
        (status['presets'] as Map<String, dynamic>? ?? <String, dynamic>{}).cast<String, dynamic>(),
      );
    } catch (_) {}
  }

  Future<void> toggleGuardianMode(bool enabled) async {
    try {
      await _repo.toggleGuardianMode(enabled: enabled);
      guardianModeEnabled.value = enabled;
      AppSnackbar.success(enabled ? 'Guardian Mode enabled.' : 'Guardian Mode disabled.');
    } catch (e) {
      AppSnackbar.error('Failed to toggle Guardian Mode.');
    }
  }

  Future<void> loadGuardianInvitations() async {
    try {
      guardianInvitations.assignAll(await _repo.fetchGuardianInvitations());
    } catch (_) {}
  }

  /// Invite via single-use expiring token; accepts a preset or explicit keys.
  Future<bool> inviteGuardianWithPreset({
    required String contact,
    required String relationship,
    String? guardianRole,
    bool isWali = false,
    String permissionPreset = 'view_only',
    List<String>? permissions,
  }) async {
    if (busy.value) return false;
    busy.value = true;
    try {
      await _repo.createGuardianInvitation(
        contact: contact,
        relationship: relationship,
        guardianRole: guardianRole,
        isWali: isWali,
        permissionPreset: permissionPreset,
        permissions: permissions,
      );
      AppSnackbar.success('Guardian invitation sent.');
      await Future.wait(<Future<void>>[loadGuardians(), loadGuardianInvitations()]);
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to invite guardian.');
      return false;
    } finally {
      busy.value = false;
    }
  }

  /// Guardian accepts an invitation token (from a link/code).
  Future<bool> acceptGuardianInvitation(String token) async {
    try {
      await _repo.acceptGuardianInvitation(token);
      AppSnackbar.success('Invitation accepted — you are now a guardian.');
      await loadManagedProfiles();
      return true;
    } catch (e) {
      AppSnackbar.error('This invitation is not valid.');
      return false;
    }
  }

  Future<void> pauseGuardian(int guardianId) async {
    try {
      await _repo.pauseGuardian(guardianId);
      AppSnackbar.success('Guardian paused.');
      await loadGuardians();
    } catch (e) {
      AppSnackbar.error('Failed to pause guardian.');
    }
  }

  Future<void> resumeGuardian(int guardianId) async {
    try {
      await _repo.resumeGuardian(guardianId);
      AppSnackbar.success('Guardian resumed.');
      await loadGuardians();
    } catch (e) {
      AppSnackbar.error('Failed to resume guardian.');
    }
  }

  Future<void> updateGuardianPermissions(int guardianId, List<String> permissions) async {
    try {
      await _repo.updateGuardianPermissions(guardianId, permissions);
      AppSnackbar.success('Permissions updated.');
      await loadGuardians();
    } catch (e) {
      AppSnackbar.error('Failed to update permissions.');
    }
  }

  Future<void> loadGuardianActivity(int profileUserId) async {
    try {
      guardianActivity.assignAll(await _repo.fetchGuardianActivity(profileUserId));
    } catch (_) {}
  }

  Future<void> loadGuardianMatches(int profileUserId) async {
    try {
      guardianMatches.assignAll(await _repo.fetchGuardianMatches(profileUserId));
    } catch (_) {
      guardianMatches.clear();
    }
  }

  Future<bool> guardianShortlist({required int profileUserId, required int targetUserId}) async {
    try {
      await _repo.guardianShortlist(profileUserId: profileUserId, targetUserId: targetUserId);
      AppSnackbar.success('Shortlisted for the member.');
      return true;
    } catch (e) {
      AppSnackbar.error('Not permitted or failed.');
      return false;
    }
  }

  Future<bool> guardianFeedback({
    required int profileUserId,
    required int targetUserId,
    required String feedbackType,
    String? reason,
    String? comment,
  }) async {
    try {
      await _repo.guardianFeedback(
        profileUserId: profileUserId,
        targetUserId: targetUserId,
        feedbackType: feedbackType,
        reason: reason,
        comment: comment,
      );
      AppSnackbar.success('Feedback saved.');
      return true;
    } catch (e) {
      AppSnackbar.error('Not permitted or failed.');
      return false;
    }
  }

  Future<bool> guardianNote({
    required int profileUserId,
    required int targetUserId,
    required String note,
    String visibility = 'primary_and_guardian',
  }) async {
    try {
      await _repo.guardianNote(
        profileUserId: profileUserId,
        targetUserId: targetUserId,
        note: note,
        visibility: visibility,
      );
      AppSnackbar.success('Note saved.');
      return true;
    } catch (e) {
      AppSnackbar.error('Not permitted or failed.');
      return false;
    }
  }

  Future<void> loadIntroductions() async {
    try {
      introductions.assignAll(await _repo.fetchIntroductions());
    } catch (_) {}
  }

  Future<bool> requestIntroduction({required int proposalId, String? message}) async {
    try {
      await _repo.requestIntroduction(proposalId: proposalId, message: message);
      AppSnackbar.success('Family introduction requested.');
      await loadIntroductions();
      return true;
    } catch (e) {
      AppSnackbar.error('Could not request the introduction.');
      return false;
    }
  }

  Future<void> respondIntroduction(int introductionId, {required bool accept}) async {
    try {
      await _repo.respondIntroduction(introductionId, accept: accept);
      AppSnackbar.success(accept ? 'Introduction accepted.' : 'Introduction declined.');
      await loadIntroductions();
    } catch (e) {
      AppSnackbar.error('Failed to respond.');
    }
  }

  Future<void> cancelIntroduction(int introductionId) async {
    try {
      await _repo.cancelIntroduction(introductionId);
      AppSnackbar.success('Introduction cancelled.');
      await loadIntroductions();
    } catch (e) {
      AppSnackbar.error('Failed to cancel.');
    }
  }
}
