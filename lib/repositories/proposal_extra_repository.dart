import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';

/// Additional proposal APIs: favourites, ignored, notes, timeline, meetings.
class ProposalExtraRepository {
  ProposalExtraRepository(this._client);

  final ApiClient _client;

  // ---- Favourites -----------------------------------------------------------

  /// `GET /proposals/favourites` — list favourited profiles.
  Future<List<Map<String, dynamic>>> fetchFavourites({int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.proposalFavourites,
      query: <String, dynamic>{'per_page': perPage},
    );
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /proposals/favourites` — add a user to favourites.
  Future<void> addFavourite({required int userId}) async {
    await _client.post(
      ApiEndpoints.proposalFavourites,
      body: <String, dynamic>{'user_id': userId},
    );
  }

  /// `GET /proposals/favourites/{user}/check` — check if user is favourited.
  Future<bool> checkFavourite(int userId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.proposalFavouriteCheck(userId));
    return res.dataMap['is_favourite'] == true;
  }

  /// `DELETE /proposals/favourites/{user}` — remove from favourites.
  Future<void> removeFavourite(int userId) async {
    await _client.delete(ApiEndpoints.proposalFavouriteRemove(userId));
  }

  // ---- Ignored --------------------------------------------------------------

  /// `POST /proposals/ignored` — ignore a user.
  Future<void> ignore({required int userId}) async {
    await _client.post(
      ApiEndpoints.proposalIgnored,
      body: <String, dynamic>{'user_id': userId},
    );
  }

  /// `DELETE /proposals/ignored/{user}` — remove from ignored list.
  Future<void> removeIgnore(int userId) async {
    await _client.delete(ApiEndpoints.proposalIgnoredRemove(userId));
  }

  // ---- Notes ----------------------------------------------------------------

  /// `POST /proposals/{proposal}/notes` — add a note to a proposal.
  Future<void> addNote({required int proposalId, required String note}) async {
    await _client.post(
      ApiEndpoints.proposalNotes(proposalId),
      body: <String, dynamic>{'note': note},
    );
  }

  // ---- Timeline -------------------------------------------------------------

  /// `GET /proposals/{proposal}/timeline` — get proposal timeline events.
  Future<List<Map<String, dynamic>>> fetchTimeline(int proposalId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.proposalTimeline(proposalId));
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  // ---- Meetings -------------------------------------------------------------

  /// `GET /proposals/{proposal}/meetings` — list meetings for a proposal.
  Future<List<Map<String, dynamic>>> fetchMeetings(int proposalId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.proposalMeetings(proposalId));
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// `POST /proposals/{proposal}/meetings` — schedule a meeting.
  Future<Map<String, dynamic>> scheduleMeeting({
    required int proposalId,
    required Map<String, dynamic> data,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.proposalMeetings(proposalId),
      body: data,
    );
    return res.dataMap;
  }

  /// `PATCH /proposals/meetings/{meeting}` — update a meeting.
  Future<void> updateMeeting({
    required int meetingId,
    required Map<String, dynamic> data,
  }) async {
    await _client.patch(
      ApiEndpoints.proposalMeetingUpdate(meetingId),
      body: data,
    );
  }

  /// `POST /proposals/meetings/{meeting}/feedback` — post meeting feedback.
  Future<void> meetingFeedback({
    required int meetingId,
    required Map<String, dynamic> data,
  }) async {
    await _client.post(
      ApiEndpoints.proposalMeetingFeedback(meetingId),
      body: data,
    );
  }

  /// `POST /proposals/meetings/{meeting}/recording-consent` — consent to recording.
  Future<void> recordingConsent({
    required int meetingId,
    required bool consent,
    String? recordingUrl,
  }) async {
    await _client.post(
      ApiEndpoints.proposalMeetingRecordingConsent(meetingId),
      body: <String, dynamic>{
        'consent': consent,
        if (recordingUrl != null) 'recording_url': recordingUrl,
      },
    );
  }

  // ---- Relationship Status --------------------------------------------------

  /// `POST /proposals/relationship-status` — update relationship status.
  Future<void> updateRelationshipStatus({
    required int partnerUserId,
    required String status,
    int? proposalId,
    String? statusDate,
    String? notes,
    bool isPublic = false,
  }) async {
    await _client.post(
      ApiEndpoints.proposalRelationshipStatus,
      body: <String, dynamic>{
        'partner_user_id': partnerUserId,
        'status': status,
        if (proposalId != null) 'proposal_id': proposalId,
        if (statusDate != null) 'status_date': statusDate,
        if (notes != null) 'notes': notes,
        'is_public': isPublic,
      },
    );
  }
}
