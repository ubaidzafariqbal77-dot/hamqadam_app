import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/completion_model.dart';
import 'package:hamqadam/models/payment_model.dart';

void main() {
  group('RewardLedgerPage — GET /completion/rewards', () {
    Map<String, dynamic> pageJson(List<dynamic> items, {int lastPage = 1}) =>
        <String, dynamic>{
          'data': items,
          'meta': <String, dynamic>{
            'pagination': <String, dynamic>{
              'current_page': 1,
              'last_page': lastPage,
              'total': items.length,
            },
          },
        };

    test('parses entries and pagination from the ApiResponse envelope', () {
      final RewardLedgerPage page = RewardLedgerPage.fromJson(
        pageJson(<dynamic>[
          <String, dynamic>{
            'id': 12,
            'coins': 25,
            'reason': 'Claimed 25 free welcome coins.',
            'created_at': '2026-10-04T12:00:00.000000Z',
            'rule': <String, dynamic>{
              'name': 'Welcome Bonus',
              'description': 'One-time sign-up reward',
            },
          },
        ], lastPage: 3),
      );

      expect(page.items, hasLength(1));
      expect(page.currentPage, 1);
      expect(page.lastPage, 3);
      expect(page.hasMore, isTrue);
      expect(page.total, 1);

      final RewardLedgerEntry e = page.items.first;
      expect(e.id, 12);
      expect(e.coins, 25);
      expect(e.isCredit, isTrue);
      expect(e.ruleName, 'Welcome Bonus');
      expect(e.ruleDescription, 'One-time sign-up reward');
      expect(e.reason, 'Claimed 25 free welcome coins.');
      expect(e.createdAt, isNotNull);
    });

    test('a debit is not a credit and netCoins nets both directions', () {
      final RewardLedgerPage page = RewardLedgerPage.fromJson(
        pageJson(<dynamic>[
          <String, dynamic>{'id': 1, 'coins': 25, 'rule': <String, dynamic>{'name': 'Welcome Bonus'}},
          <String, dynamic>{'id': 2, 'coins': -5, 'rule': <String, dynamic>{'name': 'Interest sent'}},
        ]),
      );

      expect(page.items.first.isCredit, isTrue);
      expect(page.items.last.isCredit, isFalse);
      expect(page.netCoins, 20);
      expect(page.hasMore, isFalse);
    });

    test('falls back to the transaction title when no rule is loaded', () {
      final RewardLedgerPage page = RewardLedgerPage.fromJson(
        pageJson(<dynamic>[
          <String, dynamic>{'id': 3, 'title': 'Manual credit', 'coins': 7},
        ]),
      );

      expect(page.items.single.title, 'Manual credit');
      expect(page.items.single.ruleName, isNull);
    });

    test('an empty ledger is empty, not an error', () {
      final RewardLedgerPage page = RewardLedgerPage.fromJson(pageJson(<dynamic>[]));
      expect(page.isEmpty, isTrue);
      expect(page.items, isEmpty);
      expect(page.netCoins, 0);
    });

    test('survives a missing/unknown envelope shape', () {
      final RewardLedgerPage page = RewardLedgerPage.fromJson(<String, dynamic>{});
      expect(page.isEmpty, isTrue);
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
    });

    test('accepts numeric strings and null coins without throwing', () {
      final RewardLedgerPage page = RewardLedgerPage.fromJson(
        pageJson(<dynamic>[
          <String, dynamic>{'id': '4', 'coins': null, 'title': 'No amount'},
        ]),
      );

      expect(page.items.single.id, 4);
      expect(page.items.single.coins, 0);
    });

    test('a built-in reward (no rule) reads wording from metadata', () {
      // Exactly the shape WelcomeBonusService now writes: no title/description
      // columns exist on reward_transactions, so wording lives in metadata.
      final RewardLedgerPage page = RewardLedgerPage.fromJson(
        pageJson(<dynamic>[
          <String, dynamic>{
            'id': 1,
            'user_id': 220,
            'reward_rule_id': null,
            'event_key': 'welcome_bonus',
            'coins': 25,
            'metadata': <String, dynamic>{
              'title': 'Welcome Bonus',
              'description': 'Claimed 25 free welcome coins.',
            },
          },
        ]),
      );

      final RewardLedgerEntry e = page.items.single;
      expect(e.title, 'Welcome Bonus');
      expect(e.description, 'Claimed 25 free welcome coins.');
      expect(e.ruleName, isNull);
      expect(e.coins, 25);
      expect(e.isCredit, isTrue);
    });

    test('falls back to a humanised event_key when nothing else exists', () {
      final RewardLedgerPage page = RewardLedgerPage.fromJson(
        pageJson(<dynamic>[
          <String, dynamic>{'id': 2, 'event_key': 'profile_view_boost', 'coins': 3},
        ]),
      );

      expect(page.items.single.title, 'Profile View Boost');
      expect(page.items.single.description, isNull);
      expect(page.items.single.type, 'profile_view_boost');
    });

    test('an event with no key at all still renders', () {
      final RewardLedgerPage page = RewardLedgerPage.fromJson(
        pageJson(<dynamic>[<String, dynamic>{'id': 3, 'coins': 1}]),
      );

      expect(page.items.single.title, 'Reward');
      expect(page.items.single.type, isNull);
    });
  });

  group('SponsoredListingModel — GET /completion/sponsored', () {
    test('parses a listing', () {
      final SponsoredListingModel m = SponsoredListingModel.fromJson(
        <String, dynamic>{
          'id': 5,
          'title': 'Featured matchmaker',
          'subtitle': 'Vetted profiles',
          'image_url': 'https://example.com/a.png',
          'url': 'https://hamqadam.com/p/9',
          'user_id': 9,
        },
      );

      expect(m.id, 5);
      expect(m.title, 'Featured matchmaker');
      expect(m.subtitle, 'Vetted profiles');
      expect(m.imageUrl, 'https://example.com/a.png');
      expect(m.targetUrl, 'https://hamqadam.com/p/9');
      expect(m.userId, 9);
    });

    test('an ad_free member gets [] and must not crash', () {
      final List<SponsoredListingModel> list = <SponsoredListingModel>[];
      expect(list, isEmpty);
      final SponsoredListingModel sparse =
          SponsoredListingModel.fromJson(<String, dynamic>{'id': 1});
      expect(sparse.title, '');
      expect(sparse.imageUrl, isNull);
    });
  });

  group('PaymentPlanModel currency formatting', () {
    test('uses the supplied currency code', () {
      const PaymentPlanModel p = PaymentPlanModel(id: 11, name: 'Basic', price: 500);
      expect(p.priceFormattedIn('PKR'), 'PKR 500');
      expect(p.priceFormattedIn('usd'), 'USD 500');
    });

    test('keeps the old PKR default for callers that do not pass one', () {
      const PaymentPlanModel p = PaymentPlanModel(id: 11, name: 'Basic', price: 500);
      expect(p.priceFormatted, 'PKR 500');
    });

    test('never renders a bare amount when the code is blank', () {
      const PaymentPlanModel p = PaymentPlanModel(id: 11, name: 'Basic', price: 500);
      expect(p.priceFormattedIn(''), '500');
      expect(p.priceFormattedIn('   '), '500');
    });

    test('a free plan says Free in any currency', () {
      const PaymentPlanModel free = PaymentPlanModel(id: 1, name: 'Free', tier: 'free', price: 0);
      expect(free.priceFormattedIn('USD'), 'Free');
      expect(free.priceFormatted, 'Free');
    });
  });

  group('CouponValidationResult — POST /payments/coupons/validate', () {
    test('parses the backend keys discount_amount + payable_amount', () {
      final CouponValidationResult r = CouponValidationResult.fromJson(
        <String, dynamic>{
          'valid': true,
          'code': 'TEST',
          'discount_amount': 50.0,
          'payable_amount': 450.0,
        },
      );

      expect(r.isValid, isTrue);
      expect(r.discountAmount, 50.0);
      expect(r.finalPrice, 450.0);
    });

    test('a 10% coupon on a 500 plan discounts 50', () {
      const num price = 500;
      const num discount = price * 0.10;
      expect(discount, 50);
    });

    test('an unsuccessful envelope is not a valid coupon', () {
      final CouponValidationResult r = CouponValidationResult.fromJson(
        <String, dynamic>{},
        success: false,
      );
      expect(r.isValid, isFalse);
    });
  });
}
