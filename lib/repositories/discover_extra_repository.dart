import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/search_filter_profile_model.dart';

/// One `POST /matches/swipe` answer: what was recorded, and whether the two
/// likes lined up into a match.
class SwipeResult {
  const SwipeResult({
    required this.userId,
    required this.action,
    required this.isMatch,
    this.matchedProfile,
    this.summary = const <String, int>{},
  });

  final int userId;

  /// 'like' | 'pass' — echoed by the server so the UI never has to assume.
  final String action;
  final bool isMatch;

  /// The other member's card, sent only when [isMatch] is true.
  final SearchProfileModel? matchedProfile;

  /// likes_sent / passes_sent / matches counters.
  final Map<String, int> summary;
}

/// The deck plus the counters that head it.
class SwipeDeck {
  const SwipeDeck({
    required this.candidates,
    required this.total,
    required this.remaining,
    this.summary = const <String, int>{},
  });

  final List<SearchProfileModel> candidates;
  final int total;
  final int remaining;
  final Map<String, int> summary;

  bool get isEmpty => candidates.isEmpty;
}

/// One row of "Recently Viewed": the profile, plus when it was opened.
///
/// `GET /profile-views` wraps each profile in a view row
/// (`{id, viewed_at, view_type, profile: {...}}`) and `id` there is the VIEW's
/// id, not the member's. Reading the wrapper as a profile would put the wrong
/// id on the card and open somebody else's sheet on tap, so the two are kept
/// apart here.
class ViewedProfile {
  const ViewedProfile({
    required this.profile,
    this.viewedAt,
    this.viewType = 'sent',
  });

  final SearchProfileModel profile;
  final DateTime? viewedAt;

  /// 'sent' = profiles I opened, 'received' = members who opened mine.
  final String viewType;
}

/// Interest-Based Recommendations: the ranked cards plus the member's own
/// interest words, which the empty state needs to explain itself.
class InterestMatches {
  const InterestMatches({
    required this.matches,
    this.yourInterests = const <String>[],
    this.reason,
  });

  final List<SearchProfileModel> matches;
  final List<String> yourInterests;

  /// `no_profile_interests` when the viewer has nothing filled in yet.
  final String? reason;
}

/// Everything the Discover filter module asks for beyond the plain search:
/// swipe matching, interest-based recommendations, recently viewed profiles
/// and clearing search history.
class DiscoverExtraRepository {
  DiscoverExtraRepository(this._client);

  final ApiClient _client;

  // --------------------------------------------------------------------------
  // Swipe matching
  // --------------------------------------------------------------------------

  /// `GET /matches/swipe-deck` — the stack of cards still to judge.
  Future<SwipeDeck> fetchSwipeDeck({
    int perPage = 20,
    bool photoOnly = false,
    bool verifiedOnly = false,
    bool excludeViewed = false,
  }) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.matchesSwipeDeck,
      query: <String, dynamic>{
        'per_page': perPage,
        if (photoOnly) 'photo_only': 1,
        if (verifiedOnly) 'verified_only': 1,
        if (excludeViewed) 'exclude_viewed': 1,
      },
    );

    return deckFromJson(res.dataMap);
  }

  /// Parses a `GET /matches/swipe-deck` payload. Public so the shape the app
  /// expects can be asserted against the API's own JSON in tests.
  static SwipeDeck deckFromJson(Map<String, dynamic> data) {
    final List<dynamic> raw = data['candidates'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic> meta = data['meta'] is Map<String, dynamic>
        ? data['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return SwipeDeck(
      candidates: raw
          .whereType<Map<String, dynamic>>()
          .map(SearchProfileModel.fromJson)
          .toList(),
      total: _asInt(meta['total']),
      remaining: _asInt(meta['remaining']),
      summary: _summaryOf(data['summary']),
    );
  }

  /// `POST /matches/swipe` — records one decision.
  Future<SwipeResult> swipe({
    required int userId,
    required bool like,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.matchesSwipe,
      body: <String, dynamic>{
        'user_id': userId,
        'action': like ? 'like' : 'pass',
      },
    );

    return swipeResultFromJson(res.dataMap, fallbackUserId: userId);
  }

  /// Parses a `POST /matches/swipe` payload.
  static SwipeResult swipeResultFromJson(
    Map<String, dynamic> data, {
    int fallbackUserId = 0,
  }) {
    final dynamic matched = data['matched_user'];

    return SwipeResult(
      userId: _asInt(data['user_id'], fallback: fallbackUserId),
      action: data['action'] as String? ?? 'pass',
      isMatch: data['is_match'] as bool? ?? false,
      matchedProfile: matched is Map<String, dynamic>
          ? SearchProfileModel.fromJson(matched)
          : null,
      summary: _summaryOf(data['summary']),
    );
  }

  /// `DELETE /matches/swipe/last` — takes the last card back.
  /// Returns the restored profile, or null when there was nothing to undo.
  Future<SearchProfileModel?> undoSwipe() async {
    final ApiEnvelope res = await _client.delete(ApiEndpoints.matchesSwipeUndo);
    final dynamic restored = res.dataMap['restored_user'];
    return restored is Map<String, dynamic>
        ? SearchProfileModel.fromJson(restored)
        : null;
  }

  // --------------------------------------------------------------------------
  // Interest-based recommendations
  // --------------------------------------------------------------------------

  /// `GET /matches/interest-based` — ranked by shared interests/values.
  Future<InterestMatches> fetchInterestMatches({
    int perPage = 20,
    bool excludeViewed = false,
  }) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.matchesInterestBased,
      query: <String, dynamic>{
        'per_page': perPage,
        if (excludeViewed) 'exclude_viewed': 1,
      },
    );

    return interestMatchesFromJson(res.dataMap);
  }

  /// Parses a `GET /matches/interest-based` payload.
  static InterestMatches interestMatchesFromJson(Map<String, dynamic> data) {
    final List<dynamic> raw = data['matches'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic> meta = data['meta'] is Map<String, dynamic>
        ? data['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return InterestMatches(
      matches: raw
          .whereType<Map<String, dynamic>>()
          .map(SearchProfileModel.fromJson)
          .toList(),
      yourInterests: _wordsOf(data['your_interests']),
      reason: meta['reason'] as String?,
    );
  }

  // --------------------------------------------------------------------------
  // Recently viewed
  // --------------------------------------------------------------------------

  /// `GET /profile-views` — members this account opened recently, newest first.
  Future<List<ViewedProfile>> fetchRecentlyViewed({int perPage = 30}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.profileViews,
      query: <String, dynamic>{'per_page': perPage},
    );

    return viewedProfilesFrom(res.dataList);
  }

  /// Parses the `GET /profile-views` rows. Each row is a VIEW, so the profile
  /// is read out of its `profile` key — never off the row itself, whose `id`
  /// belongs to the view.
  static List<ViewedProfile> viewedProfilesFrom(List<dynamic> rows) {
    final List<ViewedProfile> views = <ViewedProfile>[];
    for (final dynamic item in rows) {
      if (item is! Map<String, dynamic>) continue;
      final dynamic nested = item['profile'];
      if (nested is! Map<String, dynamic>) continue;
      views.add(ViewedProfile(
        profile: SearchProfileModel.fromJson(nested),
        viewedAt: DateTime.tryParse('${item['viewed_at'] ?? ''}'),
        viewType: '${item['view_type'] ?? 'sent'}',
      ));
    }
    return views;
  }

  // --------------------------------------------------------------------------
  // Search history
  // --------------------------------------------------------------------------

  /// `DELETE /search/history` — wipes the history. Returns how many entries
  /// the server removed.
  Future<int> clearSearchHistory() async {
    final ApiEnvelope res = await _client.delete(ApiEndpoints.searchHistory);
    return _asInt(res.dataMap['deleted']);
  }

  /// `DELETE /search/history/{id}` — removes one entry.
  Future<void> deleteSearchHistory(int id) async {
    await _client.delete(ApiEndpoints.searchHistoryDelete(id));
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  /// Counters arrive as ints on a fresh PHP but as strings when the response
  /// passes through multipart-style casts; both are read here.
  static Map<String, int> _summaryOf(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const <String, int>{};
    return <String, int>{
      for (final MapEntry<String, dynamic> entry in raw.entries)
        entry.key: _asInt(entry.value),
    };
  }

  /// `your_interests` is `[{field, label, items: [...]}]` — flattened to the
  /// words themselves, because that is all the UI shows.
  static List<String> _wordsOf(dynamic raw) {
    if (raw is! List<dynamic>) return const <String>[];
    final List<String> words = <String>[];
    for (final dynamic group in raw) {
      if (group is! Map<String, dynamic>) continue;
      final dynamic items = group['items'];
      if (items is! List<dynamic>) continue;
      for (final dynamic item in items) {
        final String word = '$item';
        if (word.isNotEmpty) words.add(word);
      }
    }
    return words;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }
}
