/// Identity-verification records from `GET /verification/current` and
/// `GET /verification/history`.
///
/// The server keeps ONE request row per submission with a `status`
/// (`draft | submitted | under_review | approved | rejected`), the uploaded
/// documents as separate rows (`cnic_front`, `cnic_back`, `selfie`, `face`),
/// and a face-comparison verdict of its own (`face_match_status` /
/// `face_match_score`).
///
/// Only a moderator moves the request to `approved` / `rejected` — see
/// VerificationService::approve on the backend. Everything before that is
/// manual review, no matter what the AI check concluded. That distinction is
/// the whole point of this file: the app used to treat an AI pass as "verified"
/// and showed an approved badge while a human had not looked yet.
library;

import '../constants/app_constants.dart';

/// Where one part of the verification stands.
///
/// Deliberately coarser than the server's own vocabulary: the UI only ever
/// needs to say "we don't have it", "we have it and a human is looking",
/// "it passed" or "it failed".
enum VerificationItemStatus {
  /// Nothing submitted for this item yet.
  missing,

  /// Submitted and waiting on manual review.
  inReview,

  /// Checked and accepted.
  passed,

  /// Checked and rejected.
  failed;

  bool get isPassed => this == VerificationItemStatus.passed;
  bool get isFailed => this == VerificationItemStatus.failed;
  bool get isMissing => this == VerificationItemStatus.missing;
  bool get isInReview => this == VerificationItemStatus.inReview;

  /// Wording shown on the verification card.
  String get label => switch (this) {
    VerificationItemStatus.missing => 'Not submitted',
    VerificationItemStatus.inReview => 'In manual review',
    VerificationItemStatus.passed => 'Verified',
    VerificationItemStatus.failed => 'Rejected',
  };
}

/// One uploaded document row.
class VerificationDocument {
  const VerificationDocument({
    required this.id,
    required this.type,
    this.url,
    this.uploadId,
    this.createdAt,
  });

  final int id;

  /// `cnic_front | cnic_back | selfie | face`
  final String type;

  final String? url;
  final int? uploadId;
  final DateTime? createdAt;

  /// Absolute URL, tolerating a relative path from an older backend build.
  String? get imageUrl => ApiConfig.mediaUrl(url);

  String get label => switch (type) {
    'cnic_front' => 'CNIC — front',
    'cnic_back' => 'CNIC — back',
    'selfie' => 'Selfie',
    'face' => 'Liveness capture',
    _ => type.replaceAll('_', ' '),
  };

  factory VerificationDocument.fromJson(Map<String, dynamic> json) {
    return VerificationDocument(
      id: _asInt(json['id']),
      type: (json['type'] ?? '').toString(),
      url: json['url']?.toString(),
      uploadId: json['upload_id'] == null ? null : _asInt(json['upload_id']),
      createdAt: _asDate(json['created_at']),
    );
  }
}

/// The member's current (latest) verification request.
class VerificationModel {
  const VerificationModel({
    required this.status,
    this.id,
    this.cnicNumber,
    this.faceMatchStatus,
    this.faceMatchScore,
    this.rejectionReason,
    this.reviewerName,
    this.documents = const <VerificationDocument>[],
    this.submittedAt,
    this.reviewedAt,
    this.createdAt,
  });

  final int? id;

  /// `none | draft | submitted | under_review | approved | rejected`.
  ///
  /// `none` is the app's own value for "no request row exists yet"; the server
  /// answers with a null payload in that case.
  final String status;

  final String? cnicNumber;

  /// `pending | matched | mismatched` — the server's face comparison between
  /// the live selfie and the CNIC portrait. This is the liveness/face-match
  /// signal referred to in the verification requirements.
  final String? faceMatchStatus;

  /// 0–100 confidence for [faceMatchStatus].
  final double? faceMatchScore;

  final String? rejectionReason;
  final String? reviewerName;
  final List<VerificationDocument> documents;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  // ---- Overall state --------------------------------------------------------

  bool get exists => status != 'none';

  /// A moderator approved it. This — and ONLY this — means verified.
  bool get isApproved => status == 'approved';

  bool get isRejected => status == 'rejected';

  /// Submitted and sitting with a human reviewer. Note that the server's
  /// `submitted` and `under_review` are the same thing to the member.
  bool get isInManualReview => status == 'submitted' || status == 'under_review';

  /// The moderator's decision has been made either way.
  bool get isFinal => isApproved || isRejected;

  /// Nothing has been sent, or the last attempt was rejected.
  bool get canSubmit => !exists || status == 'draft' || isRejected;

  /// Retained for callers written against the older, thinner model.
  bool get isPending => isInManualReview;
  bool get canResubmit => canSubmit;

  // ---- Per-item state (the verification matrix) -----------------------------

  VerificationDocument? documentOf(String type) {
    for (final VerificationDocument d in documents) {
      if (d.type == type) return d;
    }
    return null;
  }

  bool get hasCnicFront => documentOf('cnic_front') != null;
  bool get hasCnicBack => documentOf('cnic_back') != null;
  bool get hasSelfie => documentOf('selfie') != null;

  /// Resolves an item that has no verdict of its own: it inherits the
  /// moderator's decision on the request as a whole.
  VerificationItemStatus _inherited({required bool submitted}) {
    if (!submitted) return VerificationItemStatus.missing;
    if (isApproved) return VerificationItemStatus.passed;
    if (isRejected) return VerificationItemStatus.failed;
    return VerificationItemStatus.inReview;
  }

  /// CNIC / ID card — needs BOTH sides.
  VerificationItemStatus get cnicStatus =>
      _inherited(submitted: hasCnicFront && hasCnicBack);

  VerificationItemStatus get selfieStatus => _inherited(submitted: hasSelfie);

  /// Liveness / face match. Unlike the other two this has its own verdict from
  /// the server, so a mismatch shows as failed even while the request is still
  /// open for review.
  VerificationItemStatus get livenessStatus {
    if (!hasSelfie) return VerificationItemStatus.missing;
    return switch (faceMatchStatus) {
      'matched' => VerificationItemStatus.passed,
      'mismatched' || 'failed' => VerificationItemStatus.failed,
      _ => _inherited(submitted: true),
    };
  }

  /// The three checks the member is asked about, in display order.
  List<({String label, VerificationItemStatus status})> get checklist =>
      <({String label, VerificationItemStatus status})>[
        (label: 'CNIC / ID card', status: cnicStatus),
        (label: 'Selfie', status: selfieStatus),
        (label: 'Liveness & face match', status: livenessStatus),
      ];

  /// Overall verdict, as the member should read it.
  VerificationItemStatus get overallStatus {
    if (isApproved) return VerificationItemStatus.passed;
    if (isRejected) return VerificationItemStatus.failed;
    if (!exists) return VerificationItemStatus.missing;
    return VerificationItemStatus.inReview;
  }

  /// One line describing where the whole thing stands.
  String get headline {
    if (isApproved) return 'Your identity is verified.';
    if (isRejected) {
      return rejectionReason?.trim().isNotEmpty == true
          ? 'Verification was rejected: ${rejectionReason!.trim()}'
          : 'Verification was rejected. Please submit again.';
    }
    if (isInManualReview) {
      return 'Your documents are in manual review. This usually takes 24–48 hours.';
    }
    return 'Verify your identity to unlock messaging and interests.';
  }

  factory VerificationModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawDocs = json['documents'];
    final dynamic reviewer = json['reviewer'];

    return VerificationModel(
      id: json['id'] == null ? null : _asInt(json['id']),
      status: (json['status'] ?? 'none').toString().toLowerCase(),
      cnicNumber: json['cnic_number']?.toString(),
      faceMatchStatus: json['face_match_status']?.toString(),
      faceMatchScore: _asDouble(json['face_match_score']),
      rejectionReason:
          (json['rejection_reason'] ?? json['reason'] ?? json['remarks'])?.toString(),
      reviewerName: reviewer is Map
          ? (reviewer['name'] ?? reviewer['first_name'])?.toString()
          : reviewer?.toString(),
      documents: rawDocs is List
          ? rawDocs
                .whereType<Map<String, dynamic>>()
                .map(VerificationDocument.fromJson)
                .toList(growable: false)
          : const <VerificationDocument>[],
      submittedAt: _asDate(json['submitted_at']),
      reviewedAt: _asDate(json['reviewed_at']),
      createdAt: _asDate(json['created_at']),
    );
  }

  /// No request row on the server yet.
  factory VerificationModel.none() => const VerificationModel(status: 'none');
}

// ---- Parsing helpers (tolerant of string / int / null shapes) --------------

int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse('$v');
}
