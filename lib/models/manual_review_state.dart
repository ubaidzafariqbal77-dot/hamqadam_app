/// The server's manual-review gate state, returned in the `review` node of
/// every 423 response and by `GET /auth/manual-review/status`.
///
/// When the AI identity check flags an account, the backend puts it under a
/// 12-hour manual review. During that window every mutating endpoint answers
/// `423` (`manual_review_read_only`) with this state attached; only logout and
/// the manual-review contact endpoint stay open.
class ManualReviewState {
  const ManualReviewState({
    required this.underReview,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.expired = false,
    this.remainingSeconds,
    this.contactUrl,
  });

  /// True while the gate is active.
  final bool underReview;

  /// Machine status, e.g. `manual_review`.
  final String? status;

  final DateTime? startedAt;
  final DateTime? expiresAt;

  /// The review window ran out without a decision — the member must contact
  /// support instead of waiting.
  final bool expired;

  /// Seconds left on the review window, when the server supplies it.
  final int? remainingSeconds;

  /// Where the member can reach support (`contact_url`).
  final String? contactUrl;

  bool get isActive => underReview;

  static DateTime? _date(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  factory ManualReviewState.fromJson(Map<String, dynamic> json) {
    int? seconds;
    final dynamic raw = json['remaining_seconds'];
    if (raw is num) seconds = raw.round();
    return ManualReviewState(
      underReview: json['under_review'] == true || json['status'] == 'manual_review',
      status: json['status']?.toString(),
      startedAt: _date(json['started_at']),
      expiresAt: _date(json['expires_at']),
      expired: json['expired'] == true,
      remainingSeconds: seconds,
      contactUrl: json['contact_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'under_review': underReview,
        'status': status,
        'started_at': startedAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'expired': expired,
        'remaining_seconds': remainingSeconds,
        'contact_url': contactUrl,
      };
}
