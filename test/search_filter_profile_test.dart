import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/search_filter_profile_model.dart';

void main() {
  group('SearchFilterProfileModel Tests', () {
    test('parses SearchProfileModel correctly from response JSON', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 3,
        'code': '2026073',
        'name': 'Ubaid Zafar',
        'photo': null,
        'membership': 1,
        'approved': true,
        'age': 27,
        'gender': '1',
        'marital_status_id': null,
        'height': null,
        'religion_id': null,
        'caste_id': null,
        'city_id': null,
        'state_id': null,
        'country_id': null,
        'verification': <String, dynamic>{
          'identity_verified': false,
          'verified_at': null,
        },
        'compatibility_percentage': null,
        'last_active_at': null,
        'created_at': '2026-07-05T10:35:51.000000Z',
      };

      final SearchProfileModel profile = SearchProfileModel.fromJson(json);

      expect(profile.id, 3);
      expect(profile.code, '2026073');
      expect(profile.displayName, 'Ubaid Zafar');
      expect(profile.initial, 'U');
      expect(profile.age, 27);
      expect(profile.ageLabel, '27 yrs');
      expect(profile.gender, '1');
      expect(profile.approved, true);
      expect(profile.identityVerified, false);
      expect(profile.membership, 1);
    });

    test('parses SearchProfilesPage correctly with pagination meta', () {
      final Map<String, dynamic> fullResponse = <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 3,
            'code': '2026073',
            'name': 'Ubaid Zafar',
            'photo': null,
            'membership': 1,
            'approved': true,
            'age': 27,
            'gender': '1',
            'marital_status_id': null,
            'height': null,
            'religion_id': null,
            'caste_id': null,
            'city_id': null,
            'state_id': null,
            'country_id': null,
            'verification': <String, dynamic>{
              'identity_verified': false,
              'verified_at': null,
            },
            'compatibility_percentage': null,
            'last_active_at': null,
            'created_at': '2026-07-05T10:35:51.000000Z',
          }
        ],
        'links': <String, dynamic>{
          'first': 'https://hamqadam.com/api/v1/search/profiles?page=1',
          'last': 'https://hamqadam.com/api/v1/search/profiles?page=1',
          'prev': null,
          'next': null,
        },
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

      final SearchProfilesPage page = SearchProfilesPage.fromJson(fullResponse);

      expect(page.profiles.length, 1);
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
      expect(page.perPage, 20);
      expect(page.total, 1);
      expect(page.hasMore, false);
      expect(page.isNotEmpty, true);
    });

    test('SearchFilterModel converts to expected query params matching URL requirement', () {
      // GET /search/profiles?age_min=24&age_max=32&verified_only=1&photo_only=1&compatibility_min=70&nearby=1&sort=compatibility
      const SearchFilterModel filter = SearchFilterModel(
        ageMin: 24,
        ageMax: 32,
        verifiedOnly: true,
        photoOnly: true,
        compatibilityMin: 70,
        nearby: true,
        sort: 'compatibility',
      );

      final Map<String, dynamic> params = filter.toQueryParams(page: 1, perPage: 20);

      expect(params['age_min'], 24);
      expect(params['age_max'], 32);
      expect(params['verified_only'], 1);
      expect(params['photo_only'], 1);
      expect(params['compatibility_min'], 70);
      expect(params['nearby'], 1);
      expect(params['sort'], 'compatibility');
      expect(params['page'], 1);
      expect(params['per_page'], 20);
      expect(filter.activeFilterCount, 7);
    });
  });
}
