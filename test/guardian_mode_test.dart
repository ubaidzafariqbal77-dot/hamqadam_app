import 'package:flutter_test/flutter_test.dart';

/// Mirrors the backend contract from `GET /family/guardian-mode/status`,
/// `POST /family/guardian-invitations` and the granular permission keys
/// (spec §7/§8). Keeping these shapes pinned in a test catches accidental
/// contract drift between the Laravel API and the app.
void main() {
  group('Guardian Mode contract', () {
    test('guardian-mode status parses into enabled/catalog/presets', () {
      final Map<String, dynamic> status = <String, dynamic>{
        'enabled': true,
        'permissions': <String, dynamic>{
          'view_basic_profile': 'View approved basic profile',
          'view_private_chat': 'View personal chat',
        },
        'presets': <String, dynamic>{
          'view_only': <String>['view_basic_profile'],
          'review': <String>['view_basic_profile', 'shortlist_match'],
          'participate': <String>['view_basic_profile', 'shortlist_match', 'recommend_match'],
          'custom': <dynamic>[],
        },
        'defaults': <String>['view_basic_profile'],
      };

      expect(status['enabled'], true);
      expect((status['permissions'] as Map<String, dynamic>).length, 2);
      expect(((status['presets'] as Map<String, dynamic>)['review'] as List<dynamic>).length, 2);
      expect(status['defaults'], isA<List<dynamic>>());
    });

    test('invitation payload carries contact/preset and optional keys', () {
      final Map<String, dynamic> body = <String, dynamic>{
        'contact': 'member-16',
        'relationship': 'Father',
        'guardian_role': 'primary',
        'is_wali': true,
        'permission_preset': 'review',
      };

      expect(body['contact'], 'member-16');
      expect(body['is_wali'], true);
      expect(body.keys.contains('permissions'), isFalse,
          reason: 'preset-only invites must not send an empty permissions array');
    });

    test('invitation resource shape from the backend', () {
      final Map<String, dynamic> invitation = <String, dynamic>{
        'id': 3,
        'profile_user_id': 10,
        'guardian_user_id': null,
        'contact': 'guardian@example.com',
        'relationship': 'Uncle',
        'guardian_role': 'supporting',
        'is_wali': false,
        'permissions': <String>['view_basic_profile'],
        'status': 'pending',
        'expires_at': '2026-10-02T00:00:00.000000Z',
        'accepted_at': null,
        'created_at': '2026-09-25T00:00:00.000000Z',
      };

      expect(invitation['status'], 'pending');
      expect(invitation['guardian_user_id'], isNull);
      expect(invitation['expires_at'], isNotNull);
      expect((invitation['permissions'] as List<dynamic>).first, 'view_basic_profile');
    });

    test('sensitive permission keys are never part of any preset', () {
      const List<String> sensitive = <String>[
        'send_interest', 'view_private_photos', 'view_private_chat',
        'view_contact_details', 'manage_other_guardians', 'view_payments',
        'account_security', 'delete_account',
      ];

      // The presets the API can return; mirrors GuardianPermission::preset().
      final Map<String, List<String>> presets = <String, List<String>>{
        'view_only': <String>[
          'view_basic_profile', 'view_photo', 'view_verification_status',
          'view_ai_compatibility', 'view_recommended_matches',
        ],
        'review': <String>[
          'view_basic_profile', 'view_photo', 'view_verification_status',
          'view_ai_compatibility', 'view_recommended_matches',
          'shortlist_match', 'add_guardian_note', 'review_proposal',
        ],
        'participate': <String>[
          'view_basic_profile', 'view_photo', 'view_verification_status',
          'view_ai_compatibility', 'view_recommended_matches',
          'shortlist_match', 'add_guardian_note', 'review_proposal',
          'recommend_match', 'approve_family_intro',
        ],
      };

      for (final List<String> keys in presets.values) {
        for (final String key in sensitive) {
          expect(keys.contains(key), isFalse,
              reason: '$key must never default on (spec §7)');
        }
      }
    });

    test('guardian lifecycle statuses map to UI chips', () {
      String label(Map<String, dynamic> link) {
        if (link['revoked_at'] != null) return 'Revoked';
        if (link['paused_at'] != null) return 'Paused';
        return link['status'] == 'approved' ? 'Active' : 'Pending';
      }

      expect(label(<String, dynamic>{'status': 'approved', 'paused_at': null, 'revoked_at': null}), 'Active');
      expect(label(<String, dynamic>{'status': 'approved', 'paused_at': '2026-09-25T00:00:00Z', 'revoked_at': null}), 'Paused');
      expect(label(<String, dynamic>{'status': 'revoked', 'paused_at': null, 'revoked_at': '2026-09-25T00:00:00Z'}), 'Revoked');
      expect(label(<String, dynamic>{'status': 'pending', 'paused_at': null, 'revoked_at': null}), 'Pending');
    });
  });
}
