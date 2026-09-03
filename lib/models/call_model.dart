import '../constants/app_constants.dart';

/// The call payload the backend sends — over HTTP from `POST /calls` and its
/// sibling actions, and over Pusher as the body of `call-incoming`,
/// `call-accepted`, `call-rejected`, `call-cancelled`, `call-ended`,
/// `call-busy` and `call-missed`.
///
/// Both shapes are the same object (`CallService::payload()`), so one parser
/// serves both, and a mobile call is logged exactly like a web one.

/// One participant of a call, as `CallService::userPayload()` builds it.
class CallParticipant {
  const CallParticipant({required this.id, this.code, this.name, this.photo});

  final int id;
  final String? code;
  final String? name;
  final String? photo;

  String get displayName => (name ?? '').trim().isEmpty ? 'HamQadam Member' : name!.trim();

  /// Absolute URL. The backend already sends one, but a relative path from an
  /// older build still resolves.
  String? get photoUrl => ApiConfig.mediaUrl(photo);

  factory CallParticipant.fromJson(Map<String, dynamic> json) => CallParticipant(
        id: _asInt(json['id']),
        code: json['code']?.toString(),
        name: json['name']?.toString(),
        photo: json['photo']?.toString(),
      );
}

/// Agora credentials for ONE participant of ONE call.
///
/// Minted server-side per call with the app certificate and bound to [uid], so
/// it cannot be shared between users and expires on its own. This replaces the
/// app-wide temporary token that used to be compiled into the call screen.
class RtcCredentials {
  const RtcCredentials({
    required this.appId,
    required this.channel,
    required this.token,
    required this.uid,
    this.expiresAt,
    this.expiresIn,
  });

  final String appId;
  final String channel;
  final String token;
  final int uid;
  final DateTime? expiresAt;
  final int? expiresIn;

  bool get isUsable => appId.isNotEmpty && channel.isNotEmpty && token.isNotEmpty;

  static RtcCredentials? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final RtcCredentials rtc = RtcCredentials(
      appId: (json['app_id'] ?? '').toString(),
      channel: (json['channel'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      uid: _asInt(json['uid']),
      expiresAt: _asDate(json['expires_at']),
      expiresIn: json['expires_in'] == null ? null : _asInt(json['expires_in']),
    );
    return rtc.isUsable ? rtc : null;
  }
}

/// Server-side call status (`App\Enums\CallStatus`).
enum CallStatus {
  calling,
  ringing,
  accepted,
  connected,
  rejected,
  cancelled,
  missed,
  busy,
  ended,
  unknown;

  static CallStatus parse(String? raw) => switch ((raw ?? '').toLowerCase()) {
        'calling' => CallStatus.calling,
        'ringing' => CallStatus.ringing,
        'accepted' => CallStatus.accepted,
        'connected' => CallStatus.connected,
        'rejected' => CallStatus.rejected,
        'cancelled' || 'canceled' => CallStatus.cancelled,
        'missed' => CallStatus.missed,
        'busy' => CallStatus.busy,
        'ended' => CallStatus.ended,
        _ => CallStatus.unknown,
      };

  /// Still ringing or talking — anything else means the call is over.
  bool get isLive => this == CallStatus.calling ||
      this == CallStatus.ringing ||
      this == CallStatus.accepted ||
      this == CallStatus.connected;

  bool get isOver => !isLive && this != CallStatus.unknown;
}

/// One call row.
class CallModel {
  const CallModel({
    required this.id,
    required this.threadId,
    required this.agoraChannel,
    required this.callType,
    required this.status,
    this.caller,
    this.receiver,
    this.ringExpiresAt,
    this.answeredAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.endedByUserId,
    this.actorId,
    this.message,
  });

  final int id;

  /// `conversation_id` on the server; the app calls it a thread everywhere else.
  final int threadId;

  final String agoraChannel;

  /// `audio` or `video`.
  final String callType;

  final CallStatus status;
  final CallParticipant? caller;
  final CallParticipant? receiver;

  /// When an unanswered call turns into a missed one.
  final DateTime? ringExpiresAt;

  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int? endedByUserId;

  /// Who triggered the action this payload describes.
  final int? actorId;

  /// Human sentence the server attached, e.g. "Call declined."
  final String? message;

  bool get isVideo => callType.toLowerCase() == 'video';

  /// Seconds left before the server marks this call missed, floored at zero.
  int get secondsUntilRingExpiry {
    final DateTime? expiry = ringExpiresAt;
    if (expiry == null) return 0;
    final int left = expiry.difference(DateTime.now()).inSeconds;
    return left > 0 ? left : 0;
  }

  /// The other party, given who is looking.
  CallParticipant? peerFor(int myUserId) =>
      caller?.id == myUserId ? receiver : caller;

  bool isReceiver(int myUserId) => receiver?.id == myUserId;
  bool isCaller(int myUserId) => caller?.id == myUserId;

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: _asInt(json['id']),
      // `thread_id` is the alias the payload adds; `conversation_id` is the column.
      threadId: _asInt(json['thread_id'] ?? json['conversation_id']),
      agoraChannel: (json['agora_channel'] ?? '').toString(),
      callType: (json['call_type'] ?? 'audio').toString(),
      status: CallStatus.parse(json['status']?.toString()),
      caller: _participant(json['caller']),
      receiver: _participant(json['receiver']),
      ringExpiresAt: _asDate(json['ring_expires_at']),
      answeredAt: _asDate(json['answered_at']),
      endedAt: _asDate(json['ended_at']),
      durationSeconds: _asInt(json['duration_seconds']),
      endedByUserId: json['ended_by_user_id'] == null ? null : _asInt(json['ended_by_user_id']),
      actorId: json['actor_id'] == null ? null : _asInt(json['actor_id']),
      message: json['message']?.toString(),
    );
  }

  static CallParticipant? _participant(dynamic raw) {
    // An absent participant serialises as `[]`, not `null`.
    if (raw is Map<String, dynamic> && raw.isNotEmpty) {
      return CallParticipant.fromJson(raw);
    }
    return null;
  }
}

/// A `{call, rtc}` envelope — what every call endpoint returns and what every
/// call broadcast carries. `rtc` is null on broadcasts: the server deliberately
/// withholds the token there so each side fetches its own.
class CallSession {
  const CallSession({required this.call, this.rtc, this.reused = false});

  final CallModel call;
  final RtcCredentials? rtc;

  /// True when `POST /calls` returned an already-running call instead of
  /// starting a new one.
  final bool reused;

  static CallSession? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final dynamic rawCall = json['call'];
    if (rawCall is! Map<String, dynamic>) return null;
    return CallSession(
      call: CallModel.fromJson(rawCall),
      rtc: RtcCredentials.fromJson(
        json['rtc'] is Map<String, dynamic> ? json['rtc'] as Map<String, dynamic> : null,
      ),
      reused: json['reused'] == true,
    );
  }
}

int _asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

DateTime? _asDate(dynamic v) {
  final String s = (v ?? '').toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}
