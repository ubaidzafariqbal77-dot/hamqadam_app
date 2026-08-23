import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/interest_model.dart';

/// Express-interest ("proposal") calls.
///
/// Sending costs coins from the member's balance; responding is free. The cost
/// is admin-configurable and returned with every response, so never assume 1.
class InterestRepository {
  InterestRepository(this._client);

  final ApiClient _client;

  /// `GET /interests/sent`
  Future<InterestPage> fetchSent({String? status, int page = 1, int perPage = 15}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.interestsSent,
      query: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return InterestPage.fromJson(res.dataMap);
  }

  /// `GET /interests/received`
  Future<InterestPage> fetchReceived({String? status, int page = 1, int perPage = 15}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.interestsReceived,
      query: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return InterestPage.fromJson(res.dataMap);
  }

  /// `GET /interests/coin-balance`
  Future<InterestCoinBalance> fetchCoinBalance() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.interestsCoinBalance);
    return InterestCoinBalance.fromJson(res.dataMap);
  }

  /// `POST /interests` — spends coins.
  ///
  /// Throws the parsed API exception on:
  ///   402 `insufficient_coins`  — send the member to packages
  ///   409 `interest_exists`     — one is already pending or accepted either way
  ///   422 `self_interest`
  ///   404 `member_unavailable`
  Future<InterestSendResult> send({required int userId, String? note}) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.interests,
      body: <String, dynamic>{
        'user_id': userId,
        if (note != null && note.trim().isNotEmpty) 'initial_note': note.trim(),
      },
    );
    return InterestSendResult.fromJson(res.dataMap, message: res.message);
  }

  /// `POST /interests/{id}/accept` — also opens the chat thread for the pair.
  Future<InterestModel?> accept(int id) async {
    final ApiEnvelope res = await _client.post(ApiEndpoints.interestAccept(id));
    return _interestFrom(res);
  }

  /// `POST /interests/{id}/reject` — keeps the row and marks it rejected, so it
  /// stays visible under the "rejected" filter.
  Future<InterestModel?> reject(int id) async {
    final ApiEnvelope res = await _client.post(ApiEndpoints.interestReject(id));
    return _interestFrom(res);
  }

  /// `DELETE /interests/{id}` — sender withdraws a pending interest.
  /// Coins are NOT refunded; the recipient was already notified.
  Future<InterestModel?> withdraw(int id) async {
    final ApiEnvelope res = await _client.delete(ApiEndpoints.interestWithdraw(id));
    return _interestFrom(res);
  }

  InterestModel? _interestFrom(ApiEnvelope res) {
    final dynamic raw = res.dataMap['interest'];
    return raw is Map<String, dynamic> ? InterestModel.fromJson(raw) : null;
  }
}
