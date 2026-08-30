import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/payment_model.dart';

void main() {
  group('PaymentModel Tests', () {
    test('parses PaymentPlanModel list from GET /payments/plans correctly', () {
      final List<dynamic> jsonList = <dynamic>[
        <String, dynamic>{
          'id': 1,
          'name': 'Default',
          'tier': null,
          'price': 0,
          'validity_days': 10,
          'is_recurring': false,
          'features': <String, dynamic>{
            'coins': 5,
            'messaging_interests': 5,
            'photo_gallery': 2,
            'contacts': 0,
            'profile_viewers': 0,
            'profile_image_views': 0,
            'gallery_image_views': 0,
            'auto_profile_match': false,
            'auto_horoscope_profile_match': false,
          },
          'feature_flags': <dynamic>[],
        },
        <String, dynamic>{
          'id': 8,
          'name': 'Basic Free',
          'tier': 'free',
          'price': 10,
          'validity_days': 365,
          'is_recurring': false,
          'features': <String, dynamic>{
            'coins': 25,
            'messaging_interests': 25,
            'photo_gallery': 10,
            'contacts': 0,
            'profile_viewers': 10,
            'profile_image_views': 0,
            'gallery_image_views': 0,
            'auto_profile_match': true,
            'auto_horoscope_profile_match': true,
          },
          'feature_flags': <String, dynamic>{
            'ai_matching': true,
            'advanced_search': true,
          },
        }
      ];

      final List<PaymentPlanModel> plans = jsonList
          .whereType<Map<String, dynamic>>()
          .map(PaymentPlanModel.fromJson)
          .toList();

      expect(plans.length, 2);
      expect(plans.first.id, 1);
      expect(plans.first.isFree, true);
      expect(plans.first.features.coins, 5);

      expect(plans.last.id, 8);
      expect(plans.last.name, 'Basic Free');
      expect(plans.last.tier, 'free');
      expect(plans.last.price, 10);
      expect(plans.last.validityDays, 365);
      expect(plans.last.features.coins, 25);
      expect(plans.last.features.autoProfileMatch, true);
      expect(plans.last.featureFlags.aiMatching, true);
      expect(plans.last.featureFlags.advancedSearch, true);
    });

    test('parses CurrentPackageData from GET /payments/current correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'current_package': <String, dynamic>{
          'id': 8,
          'name': 'Basic Free',
          'tier': 'free',
          'price': 10,
          'validity_days': 365,
          'is_recurring': false,
          'features': <String, dynamic>{
            'coins': 25,
            'messaging_interests': 25,
            'photo_gallery': 10,
            'contacts': 0,
            'profile_viewers': 10,
            'profile_image_views': 0,
            'gallery_image_views': 0,
            'auto_profile_match': true,
            'auto_horoscope_profile_match': true,
          },
          'feature_flags': <String, dynamic>{
            'ai_matching': true,
            'advanced_search': true,
          },
        },
        'package_validity': '2027-08-23',
        'is_active': true,
        'remaining': <String, dynamic>{
          'coins': 9,
          'contact_view': 0,
          'profile_viewer_view': 6,
          'profile_image_view': 0,
          'gallery_image_view': 0,
          'photo_gallery': 10,
        },
      };

      final CurrentPackageData current = CurrentPackageData.fromJson(json);

      expect(current.isActive, true);
      expect(current.packageValidity, '2027-08-23');
      expect(current.currentPackage?.id, 8);
      expect(current.remaining.coins, 9);
      expect(current.remaining.profileViewerView, 6);
      expect(current.remaining.photoGallery, 10);
    });

    test('parses PaymentUsagePage from GET /payments/usage correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{
            'id': 12,
            'feature': 'profile_viewer_view',
            'feature_label': 'Profile Viewer View',
            'amount': 1,
            'reference_type': 'App\\Models\\ProfileViewer',
            'reference_id': 8,
            'note': 'Used 1 profile view coin.',
            'created_at': '2026-08-27T14:03:49.000000Z',
          },
          <String, dynamic>{
            'id': 11,
            'feature': 'shortlist',
            'feature_label': 'Shortlist',
            'amount': 5,
            'reference_type': 'App\\Models\\Shortlist',
            'reference_id': 7,
            'note': 'Used 5 coin(s) to shortlist member.',
            'created_at': '2026-08-27T14:03:24.000000Z',
          }
        ],
        'meta': <String, dynamic>{
          'current_page': 1,
          'from': 1,
          'last_page': 1,
          'per_page': 20,
          'to': 2,
          'total': 2,
        },
        'summary': <String, dynamic>{
          'purchased_coins': 25,
          'used_coins': 20,
          'remaining_coins': 9,
        },
        'success': true,
      };

      final PaymentUsagePage page = PaymentUsagePage.fromJson(json);

      expect(page.items.length, 2);
      expect(page.items.first.feature, 'profile_viewer_view');
      expect(page.items.first.amount, 1);
      expect(page.items.last.feature, 'shortlist');
      expect(page.items.last.amount, 5);
      expect(page.summary.purchasedCoins, 25);
      expect(page.summary.usedCoins, 20);
      expect(page.summary.remainingCoins, 9);
    });

    test('parses PaymentHistoryItem and Invoice correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 16,
        'payment_code': 'REG-260823-211527-9934',
        'invoice_number': 'INV-REG-20260823211527-66',
        'package': <String, dynamic>{
          'id': 8,
          'name': 'Basic Free',
          'tier': 'free',
          'price': 10,
          'validity_days': 365,
          'is_recurring': false,
        },
        'payment_method': 'registration_reward',
        'payment_status': 'Paid',
        'gateway_status': 'paid',
        'gateway_reference': null,
        'amount': 0,
        'discount_amount': 10,
        'payable_amount': 0,
        'currency': 'PKR',
        'paid_at': '2026-08-23T20:15:27.000000Z',
        'subscription_ends_at': '2027-08-23T20:15:27.000000Z',
        'created_at': '2026-08-23T20:15:27.000000Z',
      };

      final PaymentHistoryItem item = PaymentHistoryItem.fromJson(json);

      expect(item.id, 16);
      expect(item.paymentCode, 'REG-260823-211527-9934');
      expect(item.invoiceNumber, 'INV-REG-20260823211527-66');
      expect(item.isPaid, true);
      expect(item.package?.name, 'Basic Free');
      expect(item.currency, 'PKR');
    });

    test('parses CouponValidationResult correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'discount_amount': 20,
        'final_price': 80,
        'message': 'Coupon valid',
      };

      final CouponValidationResult result = CouponValidationResult.fromJson(json, success: true);

      expect(result.isValid, true);
      expect(result.discountAmount, 20);
      expect(result.finalPrice, 80);
    });

    test('parses CheckoutResult correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'success': true,
        'message': 'Payment initiated.',
        'data': <String, dynamic>{
          'payment_code': 'PAY-12345',
          'invoice_number': 'INV-12345',
          'payment_status': 'pending',
          'instructions': 'Please complete payment on your device.',
        },
      };

      final CheckoutResult result = CheckoutResult.fromJson(json, success: true);

      expect(result.success, true);
      expect(result.paymentCode, 'PAY-12345');
      expect(result.invoiceNumber, 'INV-12345');
      expect(result.instructions, 'Please complete payment on your device.');
    });
  });
}
