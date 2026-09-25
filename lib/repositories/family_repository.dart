import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';

/// Family feature API calls: guardians, wali mode, approval requests, conversations, notes.
class FamilyRepository {
  FamilyRepository(this._client);

  final ApiClient _client;

  // ---- Dashboard ------------------------------------------------------------

  /// `GET /family/dashboard` — family dashboard overview.
  Future<Map<String, dynamic>> fetchDashboard({int? profileUserId}) async {
    final Map<String, dynamic> params = <String, dynamic>{};
    if (profileUserId != null) params['profile_user_id'] = profileUserId;
    final ApiEnvelope res = await _client.get(ApiEndpoints.familyDashboard, query: params.isNotEmpty ? params : null);
    return res.dataMap;
  }

  // ---- Guardians ------------------------------------------------------------

  /// `GET /family/guardians` — list guardians.
  Future<List<Map<String, dynamic>>> fetchGuardians() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.familyGuardians);
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /family/guardians` — invite a guardian.
  Future<Map<String, dynamic>> inviteGuardian({
    required int guardianUserId,
    required String relationship,
    List<String> permissions = const <String>[],
    String? guardianRole,
    bool isWali = false,
    String? digestFrequency,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.familyGuardians,
      body: <String, dynamic>{
        'guardian_user_id': guardianUserId,
        'relationship': relationship,
        if (guardianRole != null) 'guardian_role': guardianRole,
        'is_wali': isWali,
        if (digestFrequency != null) 'digest_frequency': digestFrequency,
        if (permissions.isNotEmpty) 'permissions': permissions,
      },
    );
    return res.dataMap;
  }

  /// `PATCH /family/guardians/{guardian}` — update guardian settings.
  Future<void> updateGuardian(int guardianId, Map<String, dynamic> body) async {
    await _client.patch(ApiEndpoints.familyGuardianUpdate(guardianId), body: body);
  }

  /// `POST /family/guardians/{guardian}/approve` — approve a guardian.
  Future<void> approveGuardian(int guardianId) async {
    await _client.post(ApiEndpoints.familyGuardianApprove(guardianId));
  }

  /// `DELETE /family/guardians/{guardian}` — revoke a guardian.
  Future<void> revokeGuardian(int guardianId) async {
    await _client.delete(ApiEndpoints.familyGuardianDelete(guardianId));
  }

  // ---- Wali Mode ------------------------------------------------------------

  /// `POST /family/wali-mode` — toggle wali mode.
  Future<void> toggleWaliMode({required bool enabled}) async {
    await _client.post(
      ApiEndpoints.familyWaliMode,
      body: <String, dynamic>{'enabled': enabled},
    );
  }

  // ---- Guardian Mode (spec §5–§25) -----------------------------------------

  /// `GET /family/guardian-mode/status` — enabled flag, permission catalog,
  /// presets and defaults.
  Future<Map<String, dynamic>> fetchGuardianModeStatus() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.guardianModeStatus);
    return res.dataMap;
  }

  /// `POST /family/guardian-mode` — activate/deactivate Guardian Mode.
  Future<void> toggleGuardianMode({required bool enabled}) async {
    await _client.post(
      ApiEndpoints.guardianModeToggle,
      body: <String, dynamic>{'enabled': enabled},
    );
  }

  /// `POST /family/guardian-invitations` — single-use expiring invite.
  Future<Map<String, dynamic>> createGuardianInvitation({
    required String contact,
    required String relationship,
    String? guardianRole,
    bool isWali = false,
    String permissionPreset = 'view_only',
    List<String>? permissions,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.guardianInvitations,
      body: <String, dynamic>{
        'contact': contact,
        'relationship': relationship,
        if (guardianRole != null) 'guardian_role': guardianRole,
        'is_wali': isWali,
        'permission_preset': permissionPreset,
        if (permissions != null && permissions.isNotEmpty) 'permissions': permissions,
      },
    );
    return res.dataMap;
  }

  /// `GET /family/guardian-invitations` — the member's sent invitations.
  Future<List<Map<String, dynamic>>> fetchGuardianInvitations() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.guardianInvitations);
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /family/guardian-invitations/accept` — guardian consumes a token.
  Future<Map<String, dynamic>> acceptGuardianInvitation(String token) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.guardianInvitationsAccept,
      body: <String, dynamic>{'token': token},
    );
    return res.dataMap;
  }

  /// `POST /family/guardians/{id}/pause` — pause without deleting.
  Future<void> pauseGuardian(int guardianId) async {
    await _client.post(ApiEndpoints.familyGuardianPause(guardianId));
  }

  /// `POST /family/guardians/{id}/resume`.
  Future<void> resumeGuardian(int guardianId) async {
    await _client.post(ApiEndpoints.familyGuardianResume(guardianId));
  }

  /// `PATCH /family/guardians/{id}/permissions` — granular permission keys.
  Future<void> updateGuardianPermissions(int guardianId, List<String> permissions) async {
    await _client.patch(
      ApiEndpoints.familyGuardianPermissions(guardianId),
      body: <String, dynamic>{'permissions': permissions},
    );
  }

  /// `GET /family/{profile}/activity` — readable audit trail.
  Future<List<Map<String, dynamic>>> fetchGuardianActivity(int profileUserId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.familyGuardianActivity(profileUserId));
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `GET /guardian/matches` — match review feed for a managed profile.
  Future<List<Map<String, dynamic>>> fetchGuardianMatches(int profileUserId) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.guardianMatches,
      query: <String, dynamic>{'profile_user_id': profileUserId},
    );
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /guardian/matches/shortlist` — shortlist on behalf of the member.
  Future<void> guardianShortlist({required int profileUserId, required int targetUserId}) async {
    await _client.post(
      ApiEndpoints.guardianMatchShortlist,
      body: <String, dynamic>{'profile_user_id': profileUserId, 'target_user_id': targetUserId},
    );
  }

  /// `POST /guardian/matches/feedback` — not-suitable / recommend.
  Future<void> guardianFeedback({
    required int profileUserId,
    required int targetUserId,
    required String feedbackType,
    String? reason,
    String? comment,
  }) async {
    await _client.post(
      ApiEndpoints.guardianMatchFeedback,
      body: <String, dynamic>{
        'profile_user_id': profileUserId,
        'target_user_id': targetUserId,
        'feedback_type': feedbackType,
        if (reason != null) 'reason': reason,
        if (comment != null) 'comment': comment,
      },
    );
  }

  /// `POST /guardian/matches/note` — guardian note with explicit visibility.
  Future<void> guardianNote({
    required int profileUserId,
    required int targetUserId,
    required String note,
    String visibility = 'primary_and_guardian',
  }) async {
    await _client.post(
      ApiEndpoints.guardianMatchNote,
      body: <String, dynamic>{
        'profile_user_id': profileUserId,
        'target_user_id': targetUserId,
        'comment': note,
        'visibility': visibility,
      },
    );
  }

  /// `GET /family/introductions` — family introductions involving the caller.
  Future<List<Map<String, dynamic>>> fetchIntroductions() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.familyIntroductions);
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /family/introductions` — request a family introduction.
  Future<Map<String, dynamic>> requestIntroduction({required int proposalId, String? message}) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.familyIntroductions,
      body: <String, dynamic>{
        'proposal_id': proposalId,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return res.dataMap;
  }

  /// `POST /family/introductions/{id}/respond` — accept or decline.
  Future<void> respondIntroduction(int introductionId, {required bool accept}) async {
    await _client.post(
      ApiEndpoints.familyIntroductionRespond(introductionId),
      body: <String, dynamic>{'accept': accept},
    );
  }

  /// `POST /family/introductions/{id}/cancel` — the initiating side cancels.
  Future<void> cancelIntroduction(int introductionId) async {
    await _client.post(ApiEndpoints.familyIntroductionCancel(introductionId));
  }

  // ---- Managed Profiles -----------------------------------------------------

  /// `GET /family/managed-profiles` — profiles managed by current guardian.
  Future<List<Map<String, dynamic>>> fetchManagedProfiles() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.familyManagedProfiles);
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  // ---- Approval Requests ----------------------------------------------------

  /// `GET /family/approval-requests` — list approval requests.
  Future<List<Map<String, dynamic>>> fetchApprovalRequests() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.familyApprovalRequests);
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /family/approval-requests` — create an approval request.
  Future<Map<String, dynamic>> requestApproval(Map<String, dynamic> body) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.familyApprovalRequests,
      body: body,
    );
    return res.dataMap;
  }

  /// `POST /family/approval-requests/{approval}/approve` — approve request.
  Future<void> approveRequest(int approvalId, {String? note}) async {
    await _client.post(
      ApiEndpoints.familyApprovalApprove(approvalId),
      body: <String, dynamic>{
        if (note != null) 'note': note,
      },
    );
  }

  /// `POST /family/approval-requests/{approval}/reject` — reject request.
  Future<void> rejectRequest(int approvalId, {String? note}) async {
    await _client.post(
      ApiEndpoints.familyApprovalReject(approvalId),
      body: <String, dynamic>{
        if (note != null) 'note': note,
      },
    );
  }

  // ---- Notes ----------------------------------------------------------------

  /// `GET /family/notes/{profile}` — private notes for a profile.
  Future<List<Map<String, dynamic>>> fetchNotes(int profileId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.familyNotes(profileId));
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /family/notes` — add a private note.
  Future<Map<String, dynamic>> addNote({required int profileId, required String note}) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.familyNotesStore,
      body: <String, dynamic>{
        'profile_id': profileId,
        'note': note,
      },
    );
    return res.dataMap;
  }

  // ---- Conversations --------------------------------------------------------

  /// `GET /family/conversations` — list family conversations.
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.familyConversations);
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /family/conversations` — start a family conversation.
  Future<Map<String, dynamic>> startConversation({
    int? proposalId,
    required int profileUserId,
    String? message,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.familyConversations,
      body: <String, dynamic>{
        if (proposalId != null) 'proposal_id': proposalId,
        'profile_user_id': profileUserId,
        if (message != null) 'message': message,
      },
    );
    return res.dataMap;
  }

  /// `GET /family/conversations/{conversation}/messages` — fetch messages.
  Future<List<Map<String, dynamic>>> fetchConversationMessages(int conversationId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.familyConversationMessages(conversationId));
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /family/conversations/{conversation}/messages` — send a message.
  Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required String message,
    List<String> attachmentPaths = const <String>[],
  }) async {
    if (attachmentPaths.isNotEmpty) {
      final ApiEnvelope res = await _client.multipart(
        ApiEndpoints.familyConversationMessages(conversationId),
        fields: <String, dynamic>{'message': message},
        arrayFiles: <String, List<String>>{
          'attachments': attachmentPaths,
        },
      );
      return res.dataMap;
    } else {
      final ApiEnvelope res = await _client.post(
        ApiEndpoints.familyConversationMessages(conversationId),
        body: <String, dynamic>{'message': message},
      );
      return res.dataMap;
    }
  }

  // ---- Digest ---------------------------------------------------------------

  /// `GET /family/digest/preview` — preview guardian digest.
  Future<Map<String, dynamic>> fetchDigestPreview() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.familyDigestPreview);
    return res.dataMap;
  }
}
