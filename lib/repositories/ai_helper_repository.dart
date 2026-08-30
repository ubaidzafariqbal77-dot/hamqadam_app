import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';

/// AI helper result from any AI endpoint.
class AiHelperResult {
  const AiHelperResult({
    required this.status,
    this.result,
    this.message,
  });

  final String status;
  final dynamic result;
  final String? message;

  factory AiHelperResult.fromJson(Map<String, dynamic> json) {
    return AiHelperResult(
      status: (json['status'] ?? 'success').toString(),
      result: json['result'] ?? json['data'],
      message: json['message']?.toString(),
    );
  }
}

/// AI helper APIs: bio, conversation-starters, profile-quality, scam-check, red-flag-check.
class AiHelperRepository {
  AiHelperRepository(this._client);

  final ApiClient _client;

  /// `POST /ai/bio` — generate bio from text.
  Future<AiHelperResult> generateBio(String text) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.aiBio,
      body: <String, dynamic>{'text': text},
    );
    return AiHelperResult.fromJson(res.dataMap);
  }

  /// `POST /ai/conversation-starters` — generate conversation starters.
  Future<AiHelperResult> generateConversationStarters({required int matchedUserId}) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.aiConversationStarters,
      body: <String, dynamic>{'matched_user_id': matchedUserId},
    );
    return AiHelperResult.fromJson(res.dataMap);
  }

  /// `POST /ai/profile-quality` — check profile quality.
  Future<AiHelperResult> checkProfileQuality(String text) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.aiProfileQuality,
      body: <String, dynamic>{'text': text},
    );
    return AiHelperResult.fromJson(res.dataMap);
  }

  /// `POST /ai/scam-check` — scan text for scam patterns.
  Future<AiHelperResult> scamCheck(String text) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.aiScamCheck,
      body: <String, dynamic>{'text': text},
    );
    return AiHelperResult.fromJson(res.dataMap);
  }

  /// `POST /ai/red-flag-check` — scan text for red flags.
  Future<AiHelperResult> redFlagCheck(String text) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.aiRedFlagCheck,
      body: <String, dynamic>{'text': text},
    );
    return AiHelperResult.fromJson(res.dataMap);
  }
}
