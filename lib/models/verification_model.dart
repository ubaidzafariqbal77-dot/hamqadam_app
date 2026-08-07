/// Current verification record from `GET /verification/current`.
class VerificationModel {
  const VerificationModel({required this.status, this.rejectionReason, this.type});

  /// pending | approved | rejected | none
  final String status;
  final String? rejectionReason;
  final String? type;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get canResubmit => status == 'rejected' || status == 'none';

  factory VerificationModel.fromJson(Map<String, dynamic> json) {
    return VerificationModel(
      status: (json['status'] ?? 'none').toString().toLowerCase(),
      rejectionReason: (json['rejection_reason'] ?? json['reason'] ?? json['remarks'])?.toString(),
      type: json['type']?.toString(),
    );
  }

  factory VerificationModel.none() => const VerificationModel(status: 'none');
}
