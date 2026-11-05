import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/completion_model.dart';

/// REST calls for the backend "Completion Center": the reward ledger, NPS
/// feedback, match confirmations, sponsored listings, analytics events and the
/// shareable profile link.
///
/// Everything here is server-driven — no reward rules, prices or thresholds are
/// hard-coded in the app, so an admin change shows up without an app release.
class CompletionRepository {
  CompletionRepository(this._client);

  final ApiClient _client;

  /// `POST /completion/events` — analytics beacon. Fire-and-forget: the app
  /// must never block a user action on telemetry, so failures are swallowed by
  /// the caller, not here.
  Future<void> trackEvent({
    required String eventName,
    String? featureKey,
    String? sessionKey,
    String? country,
    String? region,
    String? city,
    String? platform,
    String? source,
    Map<String, dynamic>? metadata,
  }) async {
    await _client.post(
      ApiEndpoints.completionEvent,
      body: <String, dynamic>{
        'event_name': eventName,
        if (featureKey != null && featureKey.isNotEmpty) 'feature_key': featureKey,
        if (sessionKey != null && sessionKey.isNotEmpty) 'session_key': sessionKey,
        if (country != null && country.isNotEmpty) 'country': country,
        if (region != null && region.isNotEmpty) 'region': region,
        if (city != null && city.isNotEmpty) 'city': city,
        if (platform != null && platform.isNotEmpty) 'platform': platform,
        if (source != null && source.isNotEmpty) 'source': source,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      },
    );
  }

  /// `POST /completion/nps` — 0–10 score plus an optional comment.
  Future<void> submitNps({
    required int score,
    String? comment,
    String? context,
    String? platform,
  }) async {
    await _client.post(
      ApiEndpoints.completionNps,
      body: <String, dynamic>{
        'score': score,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        if (context != null && context.isNotEmpty) 'context': context,
        if (platform != null && platform.isNotEmpty) 'platform': platform,
      },
    );
  }

  /// `POST /completion/got-match` — records that this member found a partner.
  Future<void> reportGotMatch({
    required int matchedUserId,
    int? profileMatchId,
    String? note,
  }) async {
    await _client.post(
      ApiEndpoints.completionGotMatch,
      body: <String, dynamic>{
        'matched_user_id': matchedUserId,
        if (profileMatchId != null) 'profile_match_id': profileMatchId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  /// `GET /completion/sponsored` — the server returns `[]` for plans carrying
  /// the `ad_free` flag, so an empty list is a valid "nothing to show".
  Future<List<SponsoredListingModel>> fetchSponsored() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.completionSponsored);
    return res.dataList
        .whereType<Map<String, dynamic>>()
        .map(SponsoredListingModel.fromJson)
        .toList();
  }

  /// `GET /completion/rewards` — the member's own reward ledger, newest first.
  Future<RewardLedgerPage> fetchRewards({int page = 1, int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.completionRewards,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return RewardLedgerPage.fromJson(res.raw);
  }

  /// `GET /completion/profile-link` — server-built share URL for this profile.
  Future<String> fetchProfileLink() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.completionProfileLink);
    final String url = res.dataMap['url'] as String? ?? '';
    return url;
  }
}
