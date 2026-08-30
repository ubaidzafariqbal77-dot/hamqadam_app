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
