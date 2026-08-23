import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/ai_verification_model.dart';

/// AI identity-verification calls. Controllers depend on this, never on Dio.
///
/// None of these take an upload. The server rebuilds the model payload from the
/// CNIC and selfie already stored at registration step 13, falling back to the
/// profile photo, so the app never re-sends images just to retry a check.
class AiVerificationRepository {
  AiVerificationRepository(this._client);

  final ApiClient _client;

  /// `GET /verification/ai/status` — poll this after registration; the check
  /// runs out of band, so the signup response only ever reports `pending`.
  Future<AiVerificationModel> fetchStatus() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.aiVerificationStatus);
    return AiVerificationModel.fromJson(res.dataMap);
  }

  /// `GET /verification/ai/history` — last 20 attempts, newest first.
  Future<List<AiVerificationAttempt>> fetchHistory() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.aiVerificationHistory);
    final dynamic raw = res.dataMap['attempts'];
    if (raw is! List) return const <AiVerificationAttempt>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AiVerificationAttempt.fromJson)
        .toList(growable: false);
  }

  /// `POST /verification/ai/run` — runs the check now and waits for the verdict.
  ///
  /// Synchronous on purpose: the member pressed a button and wants an answer.
  /// It calls a CPU-bound model, so expect a few seconds, and the endpoint is
  /// throttled to 3 requests a minute.
  ///
  /// A "not verified" outcome still comes back as HTTP 200 with a status — it
  /// is not a client error, so do not surface it as a failure.
  Future<AiVerificationRunResult> run() async {
    final ApiEnvelope res = await _client.post(ApiEndpoints.aiVerificationRun);
    return AiVerificationRunResult.fromJson(res.dataMap, fallbackMessage: res.message);
  }
}
