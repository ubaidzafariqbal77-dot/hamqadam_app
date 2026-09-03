import 'call_model.dart';

/// Which way the call went.
enum CallLogDirection { incoming, outgoing }

/// How the call finished.
///
/// Deliberately keeps `cancelled` and `missed` apart even though both read as
/// "Missed call" to whoever was being called: the caller's own list has to be
/// able to say "you cancelled this" rather than "they did not answer".
enum CallLogOutcome { ringing, answered, missed, declined, cancelled, busy }

/// One row in the device's own call history.
///
/// The Calls tab used to be built by asking the server for each conversation's
/// calls in turn — one request per thread, capped at the first ten, and nothing
/// at all for a member with more conversations than that. Worse, a call that
/// arrived while the app was closed only appeared if its thread happened to be
/// in range.
///
/// This is written locally the moment a call changes state, so the tab is
/// instant, works offline, and never loses a missed call.
class CallLogEntry {
  const CallLogEntry({
    required this.callId,
    required this.threadId,
    required this.peerId,
    required this.peerName,
    required this.isVideo,
    required this.direction,
    required this.outcome,
    required this.startedAt,
    this.peerPhoto,
    this.durationSeconds = 0,
    this.seen = false,
  });

  /// The server's call id. Also the upsert key: one call is one row however
  /// many times it changes state.
  final int callId;
  final int threadId;
  final int peerId;
  final String peerName;
  final String? peerPhoto;
  final bool isVideo;
  final CallLogDirection direction;
  final CallLogOutcome outcome;
  final DateTime startedAt;
  final int durationSeconds;

  /// False until the member has looked at the Calls tab — drives the badge.
  final bool seen;

  bool get isIncoming => direction == CallLogDirection.incoming;

  /// Whether this belongs in the "missed" count.
  ///
  /// A cancelled incoming call is a missed call from where the receiver sits —
  /// the caller gave up before they could answer — so it counts too.
  bool get isMissedCall =>
      isIncoming &&
      (outcome == CallLogOutcome.missed || outcome == CallLogOutcome.cancelled);

  /// True while the call is still going, so the row can be replaced rather
  /// than shown as history.
  bool get isInProgress => outcome == CallLogOutcome.ringing;

  /// What the row says under the name.
  String get label {
    switch (outcome) {
      case CallLogOutcome.ringing:
        return isIncoming ? 'Incoming call' : 'Calling…';
      case CallLogOutcome.answered:
        return isIncoming ? 'Incoming' : 'Outgoing';
      case CallLogOutcome.missed:
        return isIncoming ? 'Missed call' : 'No answer';
      case CallLogOutcome.declined:
        return isIncoming ? 'You declined' : 'Declined';
      case CallLogOutcome.cancelled:
        return isIncoming ? 'Missed call' : 'Cancelled';
      case CallLogOutcome.busy:
        return 'Busy';
    }
  }

  CallLogEntry copyWith({
    CallLogOutcome? outcome,
    int? durationSeconds,
    bool? seen,
    String? peerName,
    String? peerPhoto,
  }) {
    return CallLogEntry(
      callId: callId,
      threadId: threadId,
      peerId: peerId,
      peerName: peerName ?? this.peerName,
      peerPhoto: peerPhoto ?? this.peerPhoto,
      isVideo: isVideo,
      direction: direction,
      outcome: outcome ?? this.outcome,
      startedAt: startedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      seen: seen ?? this.seen,
    );
  }

  /// Builds a row from whatever the server last said about a call.
  ///
  /// [direction] is passed only when this device knows something the payload
  /// does not — an outgoing call it just placed. Otherwise it is worked out
  /// from who the caller is.
  static CallLogEntry? fromCall(
    CallModel call, {
    required int myUserId,
    CallLogDirection? direction,
    CallLogOutcome? outcome,
  }) {
    if (call.id <= 0 || myUserId <= 0) return null;
    // Only calls this member is actually part of. Call events ride the thread
    // channel as well as each participant's own, so a payload aimed at the
    // other party reaches us too — and `peerFor` would happily hand back the
    // caller for a viewer who is neither, filing somebody else's call in our
    // history.
    if (!call.isCaller(myUserId) && !call.isReceiver(myUserId)) return null;

    final CallParticipant? peer = call.peerFor(myUserId);
    if (peer == null) return null;

    return CallLogEntry(
      callId: call.id,
      threadId: call.threadId,
      peerId: peer.id,
      peerName: peer.displayName,
      peerPhoto: peer.photo,
      isVideo: call.isVideo,
      direction: direction ??
          (call.isCaller(myUserId)
              ? CallLogDirection.outgoing
              : CallLogDirection.incoming),
      outcome: outcome ?? outcomeOf(call),
      // `started_at` is only set once a call is answered, so fall back through
      // to now — a row with no time would sort to the bottom of the list for
      // ever.
      startedAt: call.answeredAt ?? call.endedAt ?? DateTime.now(),
      durationSeconds: call.durationSeconds,
    );
  }

  /// Maps the server's status onto an outcome.
  static CallLogOutcome outcomeOf(CallModel call) {
    switch (call.status) {
      case CallStatus.calling:
      case CallStatus.ringing:
        return CallLogOutcome.ringing;
      case CallStatus.accepted:
      case CallStatus.connected:
        return CallLogOutcome.answered;
      case CallStatus.rejected:
        return CallLogOutcome.declined;
      case CallStatus.cancelled:
        return CallLogOutcome.cancelled;
      case CallStatus.missed:
        return CallLogOutcome.missed;
      case CallStatus.busy:
        return CallLogOutcome.busy;
      case CallStatus.ended:
        // A call that ended without ever being answered was given up on, not
        // talked through — the server records both as `ended`.
        return call.answeredAt != null
            ? CallLogOutcome.answered
            : CallLogOutcome.cancelled;
      case CallStatus.unknown:
        return CallLogOutcome.ringing;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'call_id': callId,
        'thread_id': threadId,
        'peer_id': peerId,
        'peer_name': peerName,
        'peer_photo': peerPhoto,
        'is_video': isVideo,
        'direction': direction.name,
        'outcome': outcome.name,
        'started_at': startedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'seen': seen,
      };

  static CallLogEntry? fromJson(Map<String, dynamic> json) {
    final int? callId = _asInt(json['call_id']);
    if (callId == null || callId <= 0) return null;
    final DateTime? startedAt = DateTime.tryParse((json['started_at'] ?? '').toString());
    if (startedAt == null) return null;

    return CallLogEntry(
      callId: callId,
      threadId: _asInt(json['thread_id']) ?? 0,
      peerId: _asInt(json['peer_id']) ?? 0,
      peerName: (json['peer_name'] ?? '').toString().trim().isEmpty
          ? 'HamQadam Member'
          : json['peer_name'].toString(),
      peerPhoto: json['peer_photo']?.toString(),
      isVideo: json['is_video'] == true,
      direction: CallLogDirection.values.firstWhere(
        (CallLogDirection d) => d.name == json['direction'],
        orElse: () => CallLogDirection.incoming,
      ),
      outcome: CallLogOutcome.values.firstWhere(
        (CallLogOutcome o) => o.name == json['outcome'],
        orElse: () => CallLogOutcome.missed,
      ),
      startedAt: startedAt,
      durationSeconds: _asInt(json['duration_seconds']) ?? 0,
      seen: json['seen'] == true,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
