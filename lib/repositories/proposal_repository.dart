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
    return ProposalPage.fromJson(res.raw);
  }

  /// `POST /proposals` — Send a marriage proposal to [userId].
  Future<ProposalModel> sendProposal({
    required int userId,
    String? note,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'user_id': userId,
    };
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }

    final ApiEnvelope res = await _client.post(
      ApiEndpoints.proposals,
      body: body,
    );
    return ProposalModel.fromJson(res.dataMap);
  }

  /// `POST /proposals/{id}/accept` — Accept a received proposal.
  Future<ProposalModel> acceptProposal(int id, {String? note}) async {
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
