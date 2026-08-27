import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/profile_view_model.dart';
import 'package:hamqadam/models/public_profile_model.dart';

void main() {
  group('ProfileViewsModel Tests', () {
    test('parses ProfileViewSummary from JSON correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'remaining_profile_viewer_view': 5,
        'used_profile_views': 3,
        'package_validity': '2026-07-22',
        'is_active': true,
        'current_package_id': '1',
      };

      final ProfileViewSummary summary = ProfileViewSummary.fromJson(json);

      expect(summary.remainingViews, 5);
      expect(summary.usedViews, 3);
      expect(summary.packageValidity, '2026-07-22');
      expect(summary.isActive, true);
      expect(summary.currentPackageId, '1');
    });

    test('parses ProfileViewSummary from GET /profile-views/balance correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'current_package': <String, dynamic>{
          'id': 1,
          'name': 'Default',
          'tier': null,
          'price': 0,
          'validity_days': 10,
          'is_recurring': false,
        },
        'package_validity': '2026-07-22',
        'is_active': false,
        'remaining_profile_viewer_view': 0,
        'used_profile_views': 0,
      };

      final ProfileViewSummary summary = ProfileViewSummary.fromJson(json);

      expect(summary.packageName, 'Default');
      expect(summary.currentPackageId, 1);
      expect(summary.remainingViews, 0);
      expect(summary.usedViews, 0);
      expect(summary.packageValidity, '2026-07-22');
      expect(summary.isActive, false);
    });

    test('parses PublicProfileModel from POST /profile-views/{profileID} correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'profile': <String, dynamic>{
          'id': 66,
          'code': '20260866',
          'name': 'Younis Gopang',
          'photo': 'https://hamqadam.com/public/uploads/all/6a8b54c88c68e.jpeg',
          'membership': 1,
          'approved': true,
          'age': 25,
          'gender': '1',
          'marital_status_id': 1,
          'height': 5,
          'religion_id': 1,
          'caste_id': 8,
          'city_id': 31496,
          'state_id': 2728,
          'country_id': 166,
          'verification': <String, dynamic>{
            'identity_verified': true,
            'verified_at': '2026-08-23T20:15:06.000000Z',
          },
          'compatibility_percentage': null,
          'last_active_at': null,
          'created_at': '2026-08-23T20:15:04.000000Z',
        },
        'profile_view': <String, dynamic>{
          'consumed': false,
          'already_viewed': false,
          'remaining_profile_viewer_view': 0,
          'package_validity': '2026-07-22',
          'is_active': false,
        },
      };

      final PublicProfileModel profile = PublicProfileModel.fromJson(json);

      expect(profile.id, 66);
      expect(profile.displayName, 'Younis Gopang');
      expect(profile.identityVerified, true);
      expect(profile.meta, isNotNull);
      expect(profile.meta!.alreadyViewed, false);
      expect(profile.meta!.consumed, false);
      expect(profile.meta!.packageValidity, '2026-07-22');
    });

    test('parses ProfileViewsPage from API response JSON correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'success': true,
        'data': <dynamic>[
          <String, dynamic>{
            'id': 5,
            'viewed_at': '2026-08-27T09:05:16.000000Z',
            'view_type': 'received',
            'profile': <String, dynamic>{
              'id': 66,
              'code': '20260866',
              'name': 'Younis Gopang',
              'photo': 'https://hamqadam.com/public/uploads/all/6a8b54c88c68e.jpeg',
              'membership': 1,
              'approved': true,
              'age': 25,
              'gender': '1',
              'marital_status_id': 1,
              'height': 5,
              'religion_id': 1,
              'caste_id': 8,
              'city_id': 31496,
              'state_id': 2728,
              'country_id': 166,
              'verification': <String, dynamic>{
                'identity_verified': true,
                'verified_at': '2026-08-23T20:15:06.000000Z',
              },
              'compatibility_percentage': null,
              'last_active_at': null,
              'created_at': '2026-08-23T20:15:04.000000Z',
            },
          }
        ],
        'meta': <String, dynamic>{
          'current_page': 1,
          'last_page': 2,
          'per_page': 20,
          'total': 25,
        },
        'summary': <String, dynamic>{
          'remaining_profile_viewer_view': 4,
          'used_profile_views': 1,
          'package_validity': '2026-07-22',
          'is_active': true,
          'current_package_id': '1',
        },
      };

      final ProfileViewsPage page = ProfileViewsPage.fromJson(json);

      expect(page.items.length, 1);
      expect(page.currentPage, 1);
      expect(page.lastPage, 2);
      expect(page.total, 25);
      expect(page.hasMore, true);

      final ProfileViewItem item = page.items.first;
      expect(item.id, 5);
      expect(item.viewType, 'received');
      expect(item.viewedAt, isNotNull);
      expect(item.profile.id, 66);
      expect(item.profile.displayName, 'Younis Gopang');
      expect(item.profile.isVerified, true);
      expect(item.profile.age, 25);

      expect(page.summary, isNotNull);
      expect(page.summary!.remainingViews, 4);
      expect(page.summary!.usedViews, 1);
      expect(page.summary!.isActive, true);
    });
  });
}
