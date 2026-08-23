/// AI identity-verification state, from `GET /verification/ai/status`.
///
/// The model behind it (ai-modals.hamqadam.com) runs face, document and fraud
/// analysis and returns a *recommendation*. The backend owns the decision, so
/// treat [recommendation] as advisory and [status] as the answer.
///
/// Registration never waits for it: the signup response reports `pending` and
/// the check completes out of band, which is why the app polls this endpoint.
class AiVerificationModel {
  const AiVerificationModel({
    required this.status,
    this.recommendation,
    this.attempts = 0,
    this.verifiedAt,
    this.lastAttemptAt,
    this.canRetry = true,
    this.message,
    this.lastError,
  });

  /// not_started | pending | approved | rejected | manual_review | failed
  final String status;

  /// APPROVE | REJECT | MANUAL_REVIEW — the model's own wording, or null when
  /// no attempt has completed.
  final String? recommendation;

  final int attempts;
  final DateTime? verifiedAt;
  final DateTime? lastAttemptAt;

  /// Server's view of whether running it again could help.
  final bool canRetry;

  /// Human-readable line the server already localised for display.
  final String? message;

  /// Populated when the last attempt failed (model unreachable, no usable
  /// image, …) rather than returning a verdict.
  final String? lastError;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';
  bool get needsManualReview => status == 'manual_review';
  bool get hasFailed => status == 'failed';
  bool get notStarted => status == 'not_started';

  /// Nothing verified yet but the member can act — drives the "Verify now"
  /// button rather than [canRetry] alone, which is true even before a first run.
  bool get showsAction => !isApproved && canRetry;

  /// True while the check is still expected to finish on its own.
  bool get isSettled => isApproved || isRejected;

  factory AiVerificationModel.fromJson(Map<String, dynamic> json) {
    return AiVerificationModel(
      status: (json['status'] ?? 'not_started').toString(),
      recommendation: json['recommendation']?.toString(),
      attempts: _asInt(json['attempts']),
      verifiedAt: _asDate(json['verified_at']),
      lastAttemptAt: _asDate(json['last_attempt_at']),
      // Absent means "no reason to think a retry is pointless".
      canRetry: json.containsKey('can_retry') ? _asBool(json['can_retry']) : true,
      message: json['message']?.toString(),
      lastError: json['last_error']?.toString(),
    );
  }

  /// The block embedded in `GET /profile` under `verification.ai` — same shape
  /// minus `can_retry` / `message`, which only the status endpoint returns.
  factory AiVerificationModel.fromProfileBlock(Map<String, dynamic> json) =>
      AiVerificationModel.fromJson(json);

  factory AiVerificationModel.notStarted() => const AiVerificationModel(status: 'not_started');
}

/// One row of `GET /verification/ai/history`.
class AiVerificationAttempt {
  const AiVerificationAttempt({
    required this.id,
    required this.source,
    required this.status,
    this.recommendation,
    this.identityConfidence,
    this.fraudRiskScore,
    this.fraudRiskLevel,
    this.faceDetected,
    this.imagesSent = const <String>[],
    this.errorMessage,
    this.createdAt,
  });

  final int id;

  /// registration_api | registration_web | document_submit | manual_retry
  final String source;

  /// pending | completed | failed | skipped
  final String status;

  final String? recommendation;
  final double? identityConfidence;
  final double? fraudRiskScore;
  final String? fraudRiskLevel;

  /// Null when the attempt never reached the detector.
  final bool? faceDetected;

  /// Which images the server managed to send, e.g.
  /// `[cnic_image, live_selfie, profile_image]`. A single `live_selfie` means
  /// only the profile photo was available, so no identity comparison happened.
  final List<String> imagesSent;

  final String? errorMessage;
  final DateTime? createdAt;

  bool get comparedIdentity => imagesSent.length > 1;

  /// Label for the trigger, in the app's wording rather than the DB's.
  String get sourceLabel => switch (source) {
    'registration_api' => 'During registration',
    'registration_web' => 'During web signup',
    'document_submit' => 'Document submission',
    'manual_retry' => 'Manual retry',
    _ => source,
  };

  factory AiVerificationAttempt.fromJson(Map<String, dynamic> json) {
    return AiVerificationAttempt(
      id: _asInt(json['id']),
      source: (json['source'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      recommendation: json['recommendation']?.toString(),
      identityConfidence: _asDouble(json['identity_confidence_score']),
      fraudRiskScore: _asDouble(json['fraud_risk_score']),
      fraudRiskLevel: json['fraud_risk_level']?.toString(),
      faceDetected: json['face_detected'] == null ? null : _asBool(json['face_detected']),
      imagesSent: _asStringList(json['images_sent']),
      errorMessage: json['error_message']?.toString(),
      createdAt: _asDate(json['created_at']),
    );
  }
}

/// Result of `POST /verification/ai/run`.
class AiVerificationRunResult {
  const AiVerificationRunResult({
    required this.status,
    required this.message,
    this.recommendation,
    this.usedDocuments = false,
    this.serviceReachable = true,
  });

  final String status;
  final String message;
  final String? recommendation;

  /// True when the CNIC + selfie from registration were used, so the model
  /// could actually compare identities rather than just inspect one photo.
  final bool usedDocuments;

  /// False when the model host could not be reached at all — worth telling the
  /// member to try later rather than to re-upload anything.
  final bool serviceReachable;

  bool get isApproved => status == 'approved';

  factory AiVerificationRunResult.fromJson(Map<String, dynamic> json, {String? fallbackMessage}) {
    return AiVerificationRunResult(
      status: (json['status'] ?? 'failed').toString(),
      message: (json['message'] ?? fallbackMessage ?? '').toString(),
      recommendation: json['recommendation']?.toString(),
      usedDocuments: _asBool(json['used_documents']),
      serviceReachable: json.containsKey('service_reachable')
          ? _asBool(json['service_reachable'])
          : true,
    );
  }
}

// ---- Parsing helpers (tolerant of string / int / bool shapes) --------------

int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final String s = '$v'.toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse('$v');
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v.map((dynamic e) => '$e').where((String e) => e.isNotEmpty).toList(growable: false);
  }
  return const <String>[];
}
