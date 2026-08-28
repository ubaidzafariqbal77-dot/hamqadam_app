/// Represents a user entity inside a Proposal (Sender or Recipient).
class ProposalMember {
  const ProposalMember({
    required this.id,
    this.code,
    this.name = 'HamQadam Member',
    this.photo,
    this.membership,
    this.approved = false,
  });

  final int id;
  final String? code;
  final String name;
  final String? photo;
  final int? membership;
  final bool approved;

  String get displayName => name.isNotEmpty ? name : (code ?? 'Member #$id');

  String get initial {
    if (name.isNotEmpty) return name.trim()[0].toUpperCase();
    return 'H';
  }

  bool get hasPhoto => photo != null && photo!.trim().isNotEmpty;

  factory ProposalMember.fromJson(Map<String, dynamic> json) {
    return ProposalMember(
      id: _asInt(json['id']),
      code: json['code'] as String?,
      name: json['name'] as String? ?? 'HamQadam Member',
      photo: json['photo'] as String?,
      membership: _asIntOrNull(json['membership']),
      approved: _asBool(json['approved']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'name': name,
        'photo': photo,
        'membership': membership,
        'approved': approved,
      };
}

/// Status of a proposal.
enum ProposalStatus {
  pending,
  accepted,
  rejected,
  withdrawn,
  cancelled,
  unknown,
}

/// Represents a marriage proposal between two members (`GET /proposals`).
class ProposalModel {
  const ProposalModel({
    required this.id,
    this.status = 'pending',
    this.statusValue = 0,
    this.initialNote,
    this.compatibilityPercentage,
    this.sender,
    this.recipient,
    this.respondedAt,
    this.withdrawnAt,
    this.cancelledAt,
    this.expiresAt,
    this.expiredAt,
    this.expiresInSeconds,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String status;
  final int statusValue;
  final String? initialNote;
  final int? compatibilityPercentage;
  final ProposalMember? sender;
  final ProposalMember? recipient;
  final DateTime? respondedAt;
  final DateTime? withdrawnAt;
  final DateTime? cancelledAt;
  final DateTime? expiresAt;
  final DateTime? expiredAt;
  final int? expiresInSeconds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProposalStatus get parsedStatus {
    switch (status.toLowerCase()) {
      case 'pending':
        return ProposalStatus.pending;
      case 'accepted':
        return ProposalStatus.accepted;
      case 'rejected':
      case 'declined':
        return ProposalStatus.rejected;
      case 'withdrawn':
        return ProposalStatus.withdrawn;
      case 'cancelled':
      case 'canceled':
        return ProposalStatus.cancelled;
      default:
        return ProposalStatus.unknown;
    }
  }

  bool get isPending => parsedStatus == ProposalStatus.pending;
  bool get isAccepted => parsedStatus == ProposalStatus.accepted;
  bool get isRejected => parsedStatus == ProposalStatus.rejected;
  bool get isWithdrawn => parsedStatus == ProposalStatus.withdrawn;
  bool get isCancelled => parsedStatus == ProposalStatus.cancelled;

  /// Returns true if this proposal was sent by [userId].
  bool isSentBy(int userId) => sender?.id == userId;

  /// Returns true if this proposal was received by [userId].
  bool isReceivedBy(int userId) => recipient?.id == userId;

  /// Returns the other party member relative to [currentUserId].
  ProposalMember? otherParty(int currentUserId) {
    if (sender?.id == currentUserId) {
      return recipient;
    }
    return sender;
  }

  String get statusLabel {
    switch (parsedStatus) {
      case ProposalStatus.pending:
        return 'Pending';
      case ProposalStatus.accepted:
        return 'Accepted';
      case ProposalStatus.rejected:
        return 'Declined';
      case ProposalStatus.withdrawn:
        return 'Withdrawn';
      case ProposalStatus.cancelled:
        return 'Cancelled';
      case ProposalStatus.unknown:
        return status.toUpperCase();
    }
  }

  factory ProposalModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawSender = json['sender'];
    final dynamic rawRecipient = json['recipient'];

    return ProposalModel(
      id: _asInt(json['id']),
      status: json['status'] as String? ?? 'pending',
      statusValue: _asInt(json['status_value']),
      initialNote: json['initial_note'] as String?,
      compatibilityPercentage: _asIntOrNull(json['compatibility_percentage']),
      sender: rawSender is Map<String, dynamic> ? ProposalMember.fromJson(rawSender) : null,
      recipient: rawRecipient is Map<String, dynamic> ? ProposalMember.fromJson(rawRecipient) : null,
      respondedAt: _asDate(json['responded_at']),
      withdrawnAt: _asDate(json['withdrawn_at']),
      cancelledAt: _asDate(json['cancelled_at']),
      expiresAt: _asDate(json['expires_at']),
      expiredAt: _asDate(json['expired_at']),
      expiresInSeconds: _asIntOrNull(json['expires_in_seconds']),
      createdAt: _asDate(json['created_at']),
      updatedAt: _asDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'status': status,
        'status_value': statusValue,
        'initial_note': initialNote,
        'compatibility_percentage': compatibilityPercentage,
        'sender': sender?.toJson(),
        'recipient': recipient?.toJson(),
        'responded_at': respondedAt?.toIso8601String(),
        'withdrawn_at': withdrawnAt?.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'expired_at': expiredAt?.toIso8601String(),
        'expires_in_seconds': expiresInSeconds,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

/// Paginated proposals response (`GET /proposals`).
class ProposalPage {
  const ProposalPage({
    this.proposals = const <ProposalModel>[],
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 20,
    this.total = 0,
  });

  final List<ProposalModel> proposals;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
  bool get isEmpty => proposals.isEmpty;
  bool get isNotEmpty => proposals.isNotEmpty;

  factory ProposalPage.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final List<dynamic> list = rawData is List ? rawData : <dynamic>[];
    final dynamic meta = json['meta'];

    return ProposalPage(
      proposals: list
          .whereType<Map<String, dynamic>>()
          .map(ProposalModel.fromJson)
          .toList(),
      currentPage: meta is Map ? (meta['current_page'] as int? ?? 1) : 1,
      lastPage: meta is Map ? (meta['last_page'] as int? ?? 1) : 1,
      perPage: meta is Map ? (meta['per_page'] as int? ?? 20) : 20,
      total: meta is Map ? (meta['total'] as int? ?? list.length) : list.length,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int _asInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool _asBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is int) return v == 1;
  if (v is String) {
    final String s = v.trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
  }
  return fallback;
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}
