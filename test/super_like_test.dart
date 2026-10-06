import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/payment_model.dart';

void main() {
  group('PaymentPlanFeatureFlags — the gate for Super Like', () {
    test('reads the JSON object shape the admin package form saves', () {
      // Exactly what GET /payments/current returns today:
      // {"ai_matching":true,"advanced_search":false,"priority_interest":true}
      final PaymentPlanFeatureFlags f = PaymentPlanFeatureFlags.fromJson(
        <String, dynamic>{
          'ai_matching': true,
          'advanced_search': false,
          'priority_interest': true,
        },
      );

      expect(f.priorityInterest, isTrue);
      expect(f.has('priority_interest'), isTrue);
      expect(f.aiMatching, isTrue);
      expect(f.advancedSearch, isFalse);
      expect(f.flags, contains('priority_interest'));
    });

    test('a flag switched off is NOT granted', () {
      final PaymentPlanFeatureFlags f = PaymentPlanFeatureFlags.fromJson(
        <String, dynamic>{'priority_interest': false, 'ai_matching': true},
      );

      expect(f.priorityInterest, isFalse);
      expect(f.has('priority_interest'), isFalse);
      // The key is absent from `flags` so an explicit false cannot leak through.
      expect(f.flags, isNot(contains('priority_interest')));
    });

    test('a free plan without the flag cannot send a Super Like', () {
      final PaymentPlanFeatureFlags f = PaymentPlanFeatureFlags.fromJson(
        <String, dynamic>{'ai_matching': true, 'advanced_search': false},
      );

      expect(f.priorityInterest, isFalse);
    });

    test('tolerates the plain-list shape', () {
      final PaymentPlanFeatureFlags f = PaymentPlanFeatureFlags.fromJson(
        <dynamic>['priority_interest', 'advanced_search'],
      );

      expect(f.priorityInterest, isTrue);
      expect(f.advancedSearch, isTrue);
    });

    test('empty / null / garbage never grants anything', () {
      for (final dynamic raw in <dynamic>[null, '', 0, <String, dynamic>{}]) {
        final PaymentPlanFeatureFlags f = PaymentPlanFeatureFlags.fromJson(raw);
        expect(f.priorityInterest, isFalse, reason: 'raw: $raw');
        expect(f.flags, isEmpty, reason: 'raw: $raw');
      }
    });

    test('ad_free is read the same way, for the sponsored-listing gate', () {
      expect(
        PaymentPlanFeatureFlags.fromJson(<String, dynamic>{'ad_free': true}).adFree,
        isTrue,
      );
      expect(
        PaymentPlanFeatureFlags.fromJson(<String, dynamic>{'ad_free': false}).adFree,
        isFalse,
      );
    });

    test('an unknown new flag works with no app change (forward compatible)', () {
      // The whole point of keeping the set: a flag added server-side tomorrow
      // is usable today via has(), with no new Dart field.
      final PaymentPlanFeatureFlags f = PaymentPlanFeatureFlags.fromJson(
        <String, dynamic>{'some_future_flag': true},
      );

      expect(f.has('some_future_flag'), isTrue);
    });

    test('parses from a real plan payload', () {
      final PaymentPlanModel plan = PaymentPlanModel.fromJson(<String, dynamic>{
        'id': 12,
        'name': 'Gold',
        'tier': 'gold',
        'price': 2000,
        'validity_days': 30,
        'is_recurring': false,
        'features': <String, dynamic>{'coins': 100},
        'feature_flags': <String, dynamic>{
          'ai_matching': true,
          'advanced_search': true,
          'profile_boost': true,
        },
      });

      expect(plan.featureFlags.advancedSearch, isTrue);
      expect(plan.featureFlags.has('profile_boost'), isTrue);
      expect(plan.featureFlags.priorityInterest, isFalse);
      expect(plan.priceFormattedIn('PKR'), 'PKR 2000');
    });
  });
}