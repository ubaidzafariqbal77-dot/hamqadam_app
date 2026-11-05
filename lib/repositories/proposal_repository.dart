import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/proposal_model.dart';

/// All REST API calls for Proposal / Rishta proposals.
class ProposalRepository {
  ProposalRepository(this._client);

  final ApiClient _client;

  /// `GET /proposals` — Fetch list of marriage proposals.
  Future<ProposalPage> fetchProposals({
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    final ApiEnvelope res = await _client.get(
      ApiEndpoints.proposals,
      query: query,
    );
    final ProposalPage legacy = ProposalPage.fromJson(res.raw);

    // Reviewed proposals (managed workflow) live in their own table; merge them
    // in so a received proposal actually shows up. A failure here must never
    // hide the legacy list.
    ProposalPage? workflow;
    try {
      final ApiEnvelope w = await _client.get(
        ApiEndpoints.connectionProposals,
        query: <String, dynamic>{'page': page, 'per_page': perPage},
      );
      workflow = ProposalPage.fromJson(w.raw);
    } catch (_) {
      workflow = null;
    }
    if (workflow == null || workflow.isEmpty) return legacy;

    final List<ProposalModel> merged = <ProposalModel>[
      ...legacy.proposals,
      ...workflow.proposals.where((ProposalModel p) =>
          status == null || status.isEmpty || p.status == status),
    ]..sort((ProposalModel a, ProposalModel b) {
        final DateTime ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    return ProposalPage(
      proposals: merged,
      currentPage: legacy.currentPage,
      lastPage: legacy.lastPage > workflow.lastPage ? legacy.lastPage : workflow.lastPage,
      perPage: legacy.perPage,
      total: legacy.total + workflow.total,
    );
  }

  static bool _isWorkflow(int id) => id >= ApiEndpoints.workflowProposalIdOffset;
  static int _workflowId(int id) => id - ApiEndpoints.workflowProposalIdOffset;

  Future<ProposalModel> _respondWorkflow(int id, String decision) async {
    await _client.post(
      ApiEndpoints.connectionProposalRespond(_workflowId(id)),
      body: <String, dynamic>{'decision': decision},
    );
    return ProposalModel.fromJson(<String, dynamic>{
      'id': id,
      'status': decision == 'accept' ? 'accepted' : 'rejected',
    });
  }

  /// `POST /connection-workflow/members/{id}/proposal` — sends a reviewed,
  /// approved proposal message. Returns the new proposal id.
  ///
  /// The server requires an accepted interest between the pair and a message of
  /// 20–5000 characters; its business-rule errors arrive as 422 field errors.
  Future<int> sendProposal({
    required int userId,
    required String message,
    String language = 'en',
    bool fromAi = false,
    int? templateId,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.connectionProposal(userId),
      body: <String, dynamic>{
        if (templateId != null && !fromAi) 'template_id': templateId,
        'language': language == 'ur' ? 'ur' : 'en',
        'source': fromAi ? 'ai' : 'static',
        'message': message.trim(),
        'approved': true,
        'send': true,
      },
    );
    final dynamic id = res.dataMap['id'];
    return id is int ? id : int.tryParse('$id') ?? 0;
  }

  /// `POST /proposals/{id}/accept` — Accept a received proposal.
  Future<ProposalModel> acceptProposal(int id, {String? note}) async {
    if (_isWorkflow(id)) return _respondWorkflow(id, 'accept');
    final Map<String, dynamic> body = <String, dynamic>{};
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.proposalAccept(id),
      body: body,
    );
    return ProposalModel.fromJson(res.dataMap.isNotEmpty ? res.dataMap : <String, dynamic>{'id': id, 'status': 'accepted'});
  }

  /// `POST /proposals/{id}/reject` — Decline/reject a received proposal.
  Future<ProposalModel> rejectProposal(int id, {String? note}) async {
    if (_isWorkflow(id)) return _respondWorkflow(id, 'decline');
    final Map<String, dynamic> body = <String, dynamic>{};
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.proposalReject(id),
      body: body,
    );
    return ProposalModel.fromJson(res.dataMap.isNotEmpty ? res.dataMap : <String, dynamic>{'id': id, 'status': 'rejected'});
  }

  /// `POST /proposals/{id}/withdraw` — Withdraw a sent proposal.
  Future<ProposalModel> withdrawProposal(int id, {String? note}) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.proposalWithdraw(id),
      body: body,
    );
    return ProposalModel.fromJson(res.dataMap.isNotEmpty ? res.dataMap : <String, dynamic>{'id': id, 'status': 'withdrawn'});
  }

  /// `POST /proposals/{id}/cancel` — Cancel a proposal.
  Future<ProposalModel> cancelProposal(int id, {String? note}) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.proposalCancel(id),
      body: body,
    );
    return ProposalModel.fromJson(res.dataMap.isNotEmpty ? res.dataMap : <String, dynamic>{'id': id, 'status': 'cancelled'});
  }
}
