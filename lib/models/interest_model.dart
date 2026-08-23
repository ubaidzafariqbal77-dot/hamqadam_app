import '../constants/app_constants.dart';

/// Coin wallet for express interest, from `GET /interests/coin-balance` and
/// echoed by the send/list endpoints.
///
/// Sending costs [costPerInterest] coins from [remainingInterest]; responding
/// to one is free. The cost is admin-configurable, so never hardcode it.
class InterestCoinBalance {
  const InterestCoinBalance({
    this.remainingInterest = 0,
    this.costPerInterest = 1,
    this.canSend = false,
  });

  final int remainingInterest;
  final int costPerInterest;

  /// Server's own verdict; trust it over comparing the two numbers locally.
  final bool canSend;

  /// How many more interests the current balance affords.
  int get affordable => costPerInterest <= 0 ? 0 : remainingInterest ~/ costPerInterest;

  factory InterestCoinBalance.fromJson(Map<String, dynamic> json) {
    return InterestCoinBalance(
      remainingInterest: _asInt(json['remaining_interest']),
      costPerInterest: _asInt(json['cost_per_interest'], fallback: 1),
      canSend: _asBool(json['can_send']),
    );
  }

  factory InterestCoinBalance.empty() => const InterestCoinBalance();
}

/// The other party on an interest, as returned inside each row.
class InterestMember {
  const InterestMember({
    required this.id,
    this.code,
    this.name,
    this.photo,
    this.gender,
    this.cityId,
    this.verificationStatus,
    this.aiVerificationStatus,
  });

  final int id;
  final String? code;
  final String? name;
  final String? photo;
  final String? gender;
  final int? cityId;
  final String? verificationStatus;
  final String? aiVerificationStatus;

  String get displayName => (name ?? '').trim().isEmpty ? 'HamQadam Member' : name!.trim();
  String get initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'H';
  String? get photoUrl => ApiConfig.mediaUrl(photo);

  /// Either verification path counts, matching the badge shown elsewhere.
  bool get isVerified => verificationStatus == 'verified' || aiVerificationStatus == 'approved';

  factory InterestMember.fromJson(Map<String, dynamic> json) {
    return InterestMember(
      id: _asInt(json['id']),
      code: json['code']?.toString(),
      name: json['name']?.toString(),
      photo: json['photo']?.toString(),
      gender: json['gender']?.toString(),
      cityId: _asIntOrNull(json['city_id']),
      verificationStatus: json['verification_status']?.toString(),
      aiVerificationStatus: json['ai_verification_status']?.toString(),
    );
  }
}

/// One express-interest row from `/interests/sent` or `/interests/received`.
class InterestModel {
  const InterestModel({
    required this.id,
    required this.direction,
    required this.status,
    this.statusLabel,
    this.initialNote,
    this.canRespond = false,
    this.canWithdraw = false,
    this.member,
    this.respondedAt,
    this.withdrawnAt,
    this.expiresAt,
    this.createdAt,
  });

  final int id;

  /// sent | received — from the signed-in member's point of view.
  final String direction;

  /// 0 pending, 1 accepted, 2 rejected, 3 withdrawn, 4 cancelled, 5 expired.
  final int status;

  /// Server-provided label; prefer it over mapping [status] in the UI.
  final String? statusLabel;

  final String? initialNote;

  /// Only the recipient of a pending interest may accept or reject.
  final bool canRespond;

  /// Only the sender of a pending interest may withdraw.
  final bool canWithdraw;

  final InterestMember? member;
  final DateTime? respondedAt;
  final DateTime? withdrawnAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get isPending => status == 0;
  bool get isAccepted => status == 1;
  bool get isRejected => status == 2;
  bool get isWithdrawn => status == 3;
  bool get isSent => direction == 'sent';

  /// Accepting opens the chat thread, so the UI can offer "Message" only here.
  bool get canChat => isAccepted;

  factory InterestModel.fromJson(Map<String, dynamic> json) {
    return InterestModel(
      id: _asInt(json['id']),
      direction: (json['direction'] ?? '').toString(),
      status: _asInt(json['status']),
      statusLabel: json['status_label']?.toString(),
      initialNote: json['initial_note']?.toString(),
      canRespond: _asBool(json['can_respond']),
      canWithdraw: _asBool(json['can_withdraw']),
      member: json['member'] is Map<String, dynamic>
          ? InterestMember.fromJson(json['member'] as Map<String, dynamic>)
          : null,
      respondedAt: _asDate(json['responded_at']),
      withdrawnAt: _asDate(json['withdrawn_at']),
      expiresAt: _asDate(json['expires_at']),
      createdAt: _asDate(json['created_at']),
    );
  }
}

/// A page of interests plus the extras the list endpoints attach.
class InterestPage {
  const InterestPage({
    this.interests = const <InterestModel>[],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.pendingCount = 0,
    this.coinBalance,
  });

  final List<InterestModel> interests;
  final int currentPage;
  final int lastPage;
  final int total;

  /// Only `/interests/received` returns this.
  final int pendingCount;

  /// Only `/interests/sent` returns this.
  final InterestCoinBalance? coinBalance;

  bool get hasMore => currentPage < lastPage;
  bool get isEmpty => interests.isEmpty;

  factory InterestPage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> meta = json['meta'] is Map<String, dynamic>
        ? json['meta'] as Map<String, dynamic>
        : <String, dynamic>{};
    return InterestPage(
      interests: (json['interests'] is List ? json['interests'] as List<dynamic> : <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(InterestModel.fromJson)
          .toList(growable: false),
      currentPage: _asInt(meta['current_page'], fallback: 1),
      lastPage: _asInt(meta['last_page'], fallback: 1),
      total: _asInt(meta['total']),
      pendingCount: _asInt(json['pending_count']),
      coinBalance: json['coin_balance'] is Map<String, dynamic>
          ? InterestCoinBalance.fromJson(json['coin_balance'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Merge for pagination: keeps existing rows and appends the next page.
  InterestPage merge(InterestPage next) => InterestPage(
    interests: <InterestModel>[...interests, ...next.interests],
    currentPage: next.currentPage,
    lastPage: next.lastPage,
    total: next.total,
    pendingCount: next.pendingCount,
    coinBalance: next.coinBalance ?? coinBalance,
  );
}

/// Result of `POST /interests`.
class InterestSendResult {
  const InterestSendResult({
    required this.message,
    this.interest,
    this.coinsSpent = 0,
    this.coinBalance,
  });

  final String message;
  final InterestModel? interest;
  final int coinsSpent;
  final InterestCoinBalance? coinBalance;

  factory InterestSendResult.fromJson(Map<String, dynamic> json, {String? message}) {
    return InterestSendResult(
      message: (message ?? '').toString(),
      interest: json['interest'] is Map<String, dynamic>
          ? InterestModel.fromJson(json['interest'] as Map<String, dynamic>)
          : null,
      coinsSpent: _asInt(json['coins_spent']),
      coinBalance: json['coin_balance'] is Map<String, dynamic>
          ? InterestCoinBalance.fromJson(json['coin_balance'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Status filter values the list endpoints accept.
class InterestStatusFilter {
  const InterestStatusFilter._();

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String withdrawn = 'withdrawn';
  static const String cancelled = 'cancelled';
  static const String expired = 'expired';
}

// ---- Parsing helpers -------------------------------------------------------

int _asInt(dynamic v, {int fallback = 0}) => v is int ? v : int.tryParse('$v') ?? fallback;

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
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
