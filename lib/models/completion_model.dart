/// Response models for the backend "Completion Center".
///
/// These endpoints return raw Eloquent models (no API Resource on the server),
/// so every field is optional and parsed defensively: a column the admin has
/// not filled in yet must never break the screen that renders it.

/// One row of `GET /completion/rewards` — a reward ledger entry.
class RewardLedgerEntry {
  const RewardLedgerEntry({
    this.id = 0,
    this.title = '',
    this.description,
    this.coins = 0,
    this.type,
    this.status,
    this.ruleName,
    this.ruleDescription,
    this.reason,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? description;

  /// Signed coin delta: positive credits, negative debits.
  final int coins;
  final String? type;
  final String? status;

  /// Name of the [RewardRule] that granted it, when the server eager-loaded it.
  final String? ruleName;
  final String? ruleDescription;
  final String? reason;
  final DateTime? createdAt;

  bool get isCredit => coins >= 0;

  factory RewardLedgerEntry.fromJson(Map<String, dynamic> json) {
    final dynamic rule = json['rule'];
    final Map<String, dynamic> ruleMap =
        rule is Map<String, dynamic> ? rule : const <String, dynamic>{};
    final dynamic meta = json['metadata'];
    final Map<String, dynamic> metaMap =
        meta is Map<String, dynamic> ? meta : const <String, dynamic>{};

    // `reward_transactions` has no title/description columns: a built-in reward
    // carries its wording in `metadata`, an admin-configured one in the related
    // `reward_rule`. Fall through both, then to the event key itself.
    final String eventKey = (json['event_key'] ?? '') as String;

    return RewardLedgerEntry(
      id: _asInt(json['id']) ?? 0,
      title: (ruleMap['name'] ??
              metaMap['title'] ??
              json['title'] ??
              json['label'] ??
              _titleCase(eventKey)) as String,
      description: (ruleMap['description'] ??
              metaMap['description'] ??
              metaMap['note'] ??
              json['description'] ??
              json['note']) as String?,
      coins: _asInt(json['coins'] ?? json['amount'] ?? json['value']) ?? 0,
      type: json['type'] as String? ?? (eventKey.isEmpty ? null : eventKey),
      status: json['status'] as String?,
      ruleName: ruleMap['name'] as String?,
      ruleDescription: ruleMap['description'] as String?,
      reason: (json['reason'] ?? metaMap['reason']) as String?,
      createdAt: _asDate(json['created_at'] ?? json['occurred_at']),
    );
  }
}

/// Paginated reward ledger (`GET /completion/rewards`).
class RewardLedgerPage {
  const RewardLedgerPage({
    this.items = const <RewardLedgerEntry>[],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  final List<RewardLedgerEntry> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
  bool get isEmpty => items.isEmpty;

  /// Net coin movement across the page — positive means the member gained more
  /// than they spent.
  int get netCoins =>
      items.fold<int>(0, (int sum, RewardLedgerEntry e) => sum + e.coins);

  factory RewardLedgerPage.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final List<dynamic> list = rawData is List ? rawData : <dynamic>[];
    final dynamic meta = json['meta'];
    final dynamic pagination = meta is Map ? meta['pagination'] : null;

    return RewardLedgerPage(
      items: list
          .whereType<Map<String, dynamic>>()
          .map(RewardLedgerEntry.fromJson)
          .toList(),
      currentPage: _asInt(pagination is Map ? pagination['current_page'] : null) ?? 1,
      lastPage: _asInt(pagination is Map ? pagination['last_page'] : null) ?? 1,
      total: _asInt(pagination is Map ? pagination['total'] : null) ?? list.length,
    );
  }
}

/// One row of `GET /completion/sponsored`. The server already filters out
/// members whose plan carries the `ad_free` flag, so an empty list is normal.
class SponsoredListingModel {
  const SponsoredListingModel({
    this.id = 0,
    this.title = '',
    this.subtitle,
    this.description,
    this.imageUrl,
    this.targetUrl,
    this.userId,
  });

  final int id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String? targetUrl;
  final int? userId;

  factory SponsoredListingModel.fromJson(Map<String, dynamic> json) {
    return SponsoredListingModel(
      id: _asInt(json['id']) ?? 0,
      title: (json['title'] ?? json['name'] ?? json['company'] ?? '') as String,
      subtitle: (json['subtitle'] ?? json['tagline']) as String?,
      description: json['description'] as String?,
      imageUrl: (json['image'] ?? json['image_url'] ?? json['logo']) as String?,
      targetUrl: (json['url'] ?? json['target_url'] ?? json['link']) as String?,
      userId: _asInt(json['user_id']),
    );
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

DateTime? _asDate(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

/// `welcome_bonus` -> `Welcome Bonus`, for events with no rule and no wording.
String _titleCase(String slug) {
  final String trimmed = slug.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  if (trimmed.isEmpty) return 'Reward';
  return trimmed
      .split(' ')
      .map((String w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
