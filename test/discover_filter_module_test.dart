// The Discover filter module: Swipe Matching, Interest-Based Recommendations,
// New Profiles, Recently Viewed, Search History and the four flags the filter
// sheet now sends.
//
// The payloads below are the API's own shapes (captured from the local backend
// while building this), so a rename on either side fails here instead of
// silently emptying a screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/controllers/swipe_controller.dart';
import 'package:hamqadam/core/api/api_client.dart';
import 'package:hamqadam/core/network/network_info.dart';
import 'package:hamqadam/core/storage/secure_storage_service.dart';
import 'package:hamqadam/features/discover/widgets/discover_profile_card.dart';
import 'package:hamqadam/models/search_filter_profile_model.dart';
import 'package:hamqadam/repositories/discover_extra_repository.dart';
import 'package:hamqadam/repositories/search_extra_repository.dart';

ApiClient _client() => ApiClient(
      storage: SecureStorageService(),
      networkInfo: NetworkInfo(),
    );

Map<String, dynamic> _profileJson({
  int id = 58,
  String name = 'Ayesha Khan',
  int? compatibility,
  int? interestScore,
  List<String> shared = const <String>[],
}) {
  return <String, dynamic>{
    'id': id,
    'code': '20260848',
    'name': name,
    'photo': 'https://cdn.example.com/$id.jpg',
    'approved': false,
    'age': 28,
    'gender': '2',
    'height': '5.4',
    'city_id': 48377,
    'verification': <String, dynamic>{'identity_verified': true},
    'compatibility_percentage': compatibility,
    'last_active_at': null,
    'created_at': '2026-09-20T10:00:00.000000Z',
    'interest_score': interestScore,
    'shared_interests': shared,
  };
}

/// Serves deck/interest/undo answers without touching the network.
class _FakeDiscoverRepo extends DiscoverExtraRepository {
  _FakeDiscoverRepo() : super(_client());

  List<SearchProfileModel> deckCards = <SearchProfileModel>[];
  SwipeResult? swipeAnswer;
  Object? swipeError;
  SearchProfileModel? restore;

  final List<bool> swipes = <bool>[];

  @override
  Future<SwipeDeck> fetchSwipeDeck({
    int perPage = 20,
    bool photoOnly = false,
    bool verifiedOnly = false,
    bool excludeViewed = false,
  }) async {
    return SwipeDeck(
      candidates: deckCards,
      total: deckCards.length,
      remaining: deckCards.length,
      summary: const <String, int>{'likes_sent': 0, 'passes_sent': 0, 'matches': 0},
    );
  }

  @override
  Future<SwipeResult> swipe({required int userId, required bool like}) async {
    swipes.add(like);
    if (swipeError != null) throw swipeError!;
    return swipeAnswer ??
        SwipeResult(userId: userId, action: like ? 'like' : 'pass', isMatch: false);
  }

  @override
  Future<SearchProfileModel?> undoSwipe() async => restore;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SearchFilterModel filter flags', () {
    test('the four new switches reach the query', () {
      const SearchFilterModel filter = SearchFilterModel(
        excludeViewed: true,
        newProfiles: true,
        mutualMatch: true,
        onlineNow: true,
      );

      final Map<String, dynamic> query = filter.toQueryParams();
      expect(query['exclude_viewed'], 1);
      expect(query['new_profiles'], 1);
      expect(query['mutual_match'], 1);
      expect(query['online_now'], 1);
    });

    test('they stay out of the query when off', () {
      final Map<String, dynamic> query =
          const SearchFilterModel().toQueryParams();
      expect(query.containsKey('exclude_viewed'), isFalse);
      expect(query.containsKey('new_profiles'), isFalse);
      expect(query.containsKey('mutual_match'), isFalse);
      expect(query.containsKey('online_now'), isFalse);
    });

    test('each one counts as an active filter (so the badge lights up)', () {
      expect(const SearchFilterModel().activeFilterCount, 0);
      expect(const SearchFilterModel(excludeViewed: true).activeFilterCount, 1);
      expect(
        const SearchFilterModel(
          excludeViewed: true,
          newProfiles: true,
          mutualMatch: true,
          onlineNow: true,
        ).activeFilterCount,
        4,
      );
    });

    test('copyWith can turn one on without touching the rest', () {
      const SearchFilterModel base = SearchFilterModel(newProfiles: true);
      final SearchFilterModel next = base.copyWith(excludeViewed: true);
      expect(next.excludeViewed, isTrue);
      expect(next.newProfiles, isTrue);
      expect(next.mutualMatch, isFalse);
    });

    test('a saved search keeps the flags it was saved with', () {
      final SearchFilterModel restored = SearchExtraRepository.savedToFilter(
        <String, dynamic>{
          'age_min': 24,
          'exclude_viewed': 1,
          'new_profiles': true,
          'mutual_match': 1,
          'online_now': true,
          'partner_preference': 'true',
        },
      );

      expect(restored.ageMin, 24);
      expect(restored.excludeViewed, isTrue);
      expect(restored.newProfiles, isTrue);
      expect(restored.mutualMatch, isTrue);
      expect(restored.onlineNow, isTrue);
      expect(restored.partnerPreferenceFilter, isTrue);
    });
  });

  group('SwipeDeck parsing', () {
    test('reads the candidates, counters and remaining count', () {
      final SwipeDeck deck = DiscoverExtraRepository.deckFromJson(
        <String, dynamic>{
          'candidates': <dynamic>[_profileJson(), _profileJson(id: 66, name: 'Sara')],
          'meta': <String, dynamic>{'total': 20, 'remaining': 18, 'returned': 2},
          'summary': <String, dynamic>{'likes_sent': 4, 'passes_sent': 2, 'matches': 1},
        },
      );

      expect(deck.candidates.length, 2);
      expect(deck.candidates.first.name, 'Ayesha Khan');
      expect(deck.total, 20);
      expect(deck.remaining, 18);
      expect(deck.summary['likes_sent'], 4);
      expect(deck.summary['matches'], 1);
    });

    test('an empty deck parses to no cards', () {
      final SwipeDeck deck = DiscoverExtraRepository.deckFromJson(
        <String, dynamic>{'candidates': <dynamic>[], 'meta': <String, dynamic>{}},
      );
      expect(deck.isEmpty, isTrue);
      expect(deck.remaining, 0);
    });

    test('a swipe answer carries the mutual match and its profile', () {
      final SwipeResult result = DiscoverExtraRepository.swipeResultFromJson(
        <String, dynamic>{
          'action': 'like',
          'user_id': 67,
          'is_match': true,
          'matched_user': _profileJson(id: 67, name: 'Mail Delivery Test'),
          'summary': <String, dynamic>{'likes_sent': 2, 'passes_sent': 1, 'matches': 1},
        },
      );

      expect(result.isMatch, isTrue);
      expect(result.action, 'like');
      expect(result.userId, 67);
      expect(result.matchedProfile?.name, 'Mail Delivery Test');
      expect(result.summary['matches'], 1);
    });

    test('an ordinary swipe has no matched profile', () {
      final SwipeResult result = DiscoverExtraRepository.swipeResultFromJson(
        <String, dynamic>{'action': 'pass', 'user_id': 83, 'is_match': false},
      );
      expect(result.isMatch, isFalse);
      expect(result.matchedProfile, isNull);
    });
  });

  group('Interest-Based parsing', () {
    test('reads the score, the shared words and the viewer interests', () {
      final InterestMatches data =
          DiscoverExtraRepository.interestMatchesFromJson(
        <String, dynamic>{
          'matches': <dynamic>[
            _profileJson(
              id: 67,
              name: 'Test Member',
              interestScore: 16,
              shared: <String>['reading', 'travel'],
            ),
          ],
          'meta': <String, dynamic>{'total': 1, 'reason': null},
          'your_interests': <dynamic>[
            <String, dynamic>{
              'field': 'hobbies',
              'label': 'Shared hobbies',
              'items': <dynamic>['reading', 'cooking', 'travel'],
            },
            <String, dynamic>{
              'field': 'life_values',
              'label': 'Shared values',
              'items': <dynamic>['honesty'],
            },
          ],
        },
      );

      expect(data.matches.single.interestScore, 16);
      expect(data.matches.single.sharedInterests, <String>['reading', 'travel']);
      expect(data.yourInterests,
          <String>['reading', 'cooking', 'travel', 'honesty']);
    });

    test('an unfilled profile is reported as the reason, not as an empty list',
        () {
      final InterestMatches data =
          DiscoverExtraRepository.interestMatchesFromJson(
        <String, dynamic>{
          'matches': <dynamic>[],
          'meta': <String, dynamic>{'total': 0, 'reason': 'no_profile_interests'},
          'your_interests': <dynamic>[],
        },
      );

      expect(data.reason, 'no_profile_interests');
      expect(data.yourInterests, isEmpty);
    });
  });

  group('Recently viewed parsing', () {
    test('reads the profile out of the view row, not the row id', () {
      final List<ViewedProfile> views =
          DiscoverExtraRepository.viewedProfilesFrom(<dynamic>[
        <String, dynamic>{
          'id': 991, // the VIEW's id
          'viewed_at': '2026-09-24T10:00:00.000000Z',
          'view_type': 'sent',
          'profile': _profileJson(id: 58, name: 'Ayesha Khan'),
        },
        <String, dynamic>{'id': 992, 'profile': null},
      ]);

      expect(views.length, 1);
      expect(views.single.profile.id, 58);
      expect(views.single.profile.name, 'Ayesha Khan');
      expect(views.single.viewType, 'sent');
      expect(views.single.viewedAt, isNotNull);
    });
  });

  group('SwipeController', () {
    late _FakeDiscoverRepo repo;
    late SwipeController controller;

    SearchProfileModel card(int id) =>
        SearchProfileModel.fromJson(_profileJson(id: id, name: 'Member $id'));

    // No UI is pumped here on purpose: the controller has to survive its
    // answers arriving with no screen attached (the deck was popped, or the app
    // is shutting down), which is exactly the state a bare test runs in.
    setUp(() {
      repo = _FakeDiscoverRepo();
      repo.deckCards = <SearchProfileModel>[card(1), card(2)];
      controller = SwipeController(repo);
    });

    test('loads the deck and keeps the top card last', () async {
      await controller.loadDeck();
      expect(controller.deck.length, 2);
      expect(controller.topCard?.id, 2);
      expect(controller.hasCards, isTrue);
      expect(controller.remaining.value, 2);
    });

    test('a like removes the card and keeps the server counters', () async {
      repo.swipeAnswer = const SwipeResult(
        userId: 2,
        action: 'like',
        isMatch: false,
        summary: <String, int>{'likes_sent': 7, 'passes_sent': 0, 'matches': 0},
      );
      await controller.loadDeck();

      await controller.swipe(controller.topCard!, like: true);

      expect(repo.swipes, <bool>[true]);
      expect(controller.deck.length, 1);
      expect(controller.topCard?.id, 1);
      expect(controller.summary['likes_sent'], 7);
      expect(controller.remaining.value, 1);
    });

    test('a pass reports the pass to the API', () async {
      await controller.loadDeck();
      await controller.swipe(controller.topCard!, like: false);
      expect(repo.swipes, <bool>[false]);
    });

    test('a mutual match is announced once', () async {
      repo.swipeAnswer = SwipeResult(
        userId: 2,
        action: 'like',
        isMatch: true,
        matchedProfile: card(2),
      );
      await controller.loadDeck();

      final List<SearchProfileModel> matches = <SearchProfileModel>[];
      controller.onMatch = matches.add;
      await controller.swipe(controller.topCard!, like: true);

      expect(matches.single.id, 2);
    });

    test('a failed swipe puts the card back where it was', () async {
      repo.swipeError = Exception('offline');
      await controller.loadDeck();
      final SearchProfileModel top = controller.topCard!;

      await controller.swipe(top, like: true);

      expect(controller.deck.length, 2, reason: 'the card must not vanish');
      expect(controller.topCard?.id, top.id);
    });

    test('undo puts the last swiped card back on top', () async {
      repo.restore = card(2);
      await controller.loadDeck();
      await controller.swipe(controller.topCard!, like: true);
      expect(controller.deck.length, 1);

      await controller.undo();

      expect(controller.deck.length, 2);
      expect(controller.topCard?.id, 2);
    });

    test('undo with nothing to restore changes nothing', () async {
      repo.restore = null;
      await controller.loadDeck();
      await controller.undo();
      expect(controller.deck.length, 2);
    });
  });

  group('DiscoverProfileCard', () {
    testWidgets('renders the member, the facts and the interest reason',
        (WidgetTester tester) async {
      final SearchProfileModel profile = SearchProfileModel.fromJson(
        _profileJson(
          id: 67,
          name: 'Test Member',
          compatibility: 74,
          interestScore: 16,
          shared: <String>['reading', 'travel'],
        ),
      );

      await tester.pumpWidget(_wrap(DiscoverProfileCard(
        profile: profile,
        badgeLabel: '${profile.interestScore}% interests',
        footnote: 'You both like: ${profile.sharedInterests.join(', ')}',
      )));

      expect(find.text('Test Member'), findsOneWidget);
      expect(find.text('28 yrs  ·  5\' 4"'), findsOneWidget);
      expect(find.text('74% match'), findsOneWidget);
      expect(find.text('16% interests'), findsOneWidget);
      expect(find.text('You both like: reading, travel'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('a profile with no score shows no chips', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(DiscoverProfileCard(
        profile: SearchProfileModel.fromJson(_profileJson()),
      )));

      expect(find.textContaining('% match'), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });

    testWidgets('tapping it reports back', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(DiscoverProfileCard(
        profile: SearchProfileModel.fromJson(_profileJson()),
        onTap: () => taps++,
      )));

      await tester.tap(find.text('Ayesha Khan'));
      expect(taps, 1);
    });
  });
}
