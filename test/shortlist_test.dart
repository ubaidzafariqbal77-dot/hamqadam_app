import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/shortlist_model.dart';
import 'package:hamqadam/models/search_filter_profile_model.dart';

void main() {
  group('ShortlistModel Tests', () {
    test('parses ShortlistToggleResult from POST /proposals/shortlists correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'user_id': 10,
        'shortlisted': true,
        'shortlist_id': 6,
        'coin_balance': 14,
      };

      final ShortlistToggleResult result = ShortlistToggleResult.fromJson(json);

      expect(result.userId, 10);
      expect(result.shortlisted, true);
      expect(result.shortlistId, 6);
      expect(result.coinBalance, 14);
    });

    test('parses ShortlistCheckResult from GET /proposals/shortlists/{id}/check correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'user_id': 10,
        'is_shortlisted': true,
      };

      final ShortlistCheckResult result = ShortlistCheckResult.fromJson(json);

      expect(result.userId, 10);
      expect(result.isShortlisted, true);
    });

    test('parses ShortlistPage from GET /proposals/shortlists response JSON correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{
            'id': 10,
            'code': '2026078',
            'name': 'Ayesha Khan',
            'photo': null,
            'membership': 1,
            'approved': true,
            'age': 28,
            'gender': '2',
            'marital_status_id': 1,
            'height': '5.4',
            'religion_id': 1,
            'caste_id': 5,
            'city_id': 1,
            'state_id': 1,
            'country_id': 1,
            'verification': <String, dynamic>{
              'identity_verified': false,
              'verified_at': null,
            },
            'compatibility_percentage': 6,
            'last_active_at': null,
            'created_at': '2026-07-12T03:44:38.000000Z',
          }
        ],
        'meta': <String, dynamic>{
          'current_page': 1,
          'from': 1,
          'last_page': 1,
          'per_page': 20,
          'to': 1,
          'total': 1,
        },
        'success': true,
      };

      final ShortlistPage page = ShortlistPage.fromJson(json);

      expect(page.profiles.length, 1);
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
      expect(page.total, 1);
      expect(page.hasMore, false);

      final SearchProfileModel profile = page.profiles.first;
      expect(profile.id, 10);
      expect(profile.name, 'Ayesha Khan');
      expect(profile.code, '2026078');
      expect(profile.age, 28);
      expect(profile.compatibilityPercentage, 6);
    });
  });
}
