import 'search_filter_profile_model.dart';

/// Result from `POST /proposals/shortlists`.
class ShortlistToggleResult {
  const ShortlistToggleResult({
    required this.userId,
    required this.shortlisted,
    this.shortlistId,
    this.coinBalance,
  });

  final int userId;
  final bool shortlisted;
  final int? shortlistId;
  final int? coinBalance;

  factory ShortlistToggleResult.fromJson(Map<String, dynamic> json) {
    return ShortlistToggleResult(
      userId: json['user_id'] as int? ?? 0,
      shortlisted: json['shortlisted'] as bool? ?? false,
      shortlistId: json['shortlist_id'] as int?,
      coinBalance: json['coin_balance'] as int?,
    );
  }
}

/// Result from `GET /proposals/shortlists/{userId}/check`.
class ShortlistCheckResult {
  const ShortlistCheckResult({
    required this.userId,
    required this.isShortlisted,
  });

  final int userId;
  final bool isShortlisted;

  factory ShortlistCheckResult.fromJson(Map<String, dynamic> json) {
    return ShortlistCheckResult(
      userId: json['user_id'] as int? ?? 0,
      isShortlisted: json['is_shortlisted'] as bool? ?? false,
    );
  }
}

/// Paginated response from `GET /proposals/shortlists`.
class ShortlistPage {
  const ShortlistPage({
    this.profiles = const <SearchProfileModel>[],
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 20,
    this.total = 0,
  });

  final List<SearchProfileModel> profiles;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
  bool get isEmpty => profiles.isEmpty;
  bool get isNotEmpty => profiles.isNotEmpty;

  factory ShortlistPage.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final List<dynamic> list = rawData is List ? rawData : <dynamic>[];
    final dynamic meta = json['meta'];

    return ShortlistPage(
      profiles: list
          .whereType<Map<String, dynamic>>()
          .map(SearchProfileModel.fromJson)
          .toList(),
      currentPage: meta is Map ? (meta['current_page'] as int? ?? 1) : 1,
      lastPage: meta is Map ? (meta['last_page'] as int? ?? 1) : 1,
      perPage: meta is Map ? (meta['per_page'] as int? ?? 20) : 20,
      total: meta is Map ? (meta['total'] as int? ?? list.length) : list.length,
    );
  }
}
