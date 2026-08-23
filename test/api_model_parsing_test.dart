// Parses REAL captured API responses through the app's models.
//
// These fixtures in dev_stubs/api_samples/ were captured from the running
// backend, not hand-written, so this catches the failure mode that matters:
// a model whose field names or nesting no longer match what the server sends.
// A model can compile perfectly and still silently read every field as null.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/ai_verification_model.dart';
import 'package:hamqadam/models/interest_model.dart';
import 'package:hamqadam/models/partner_preference_model.dart';
import 'package:hamqadam/models/profile_model.dart';
import 'package:hamqadam/models/public_profile_model.dart';

Map<String, dynamic> _data(String name) {
  final File f = File('dev_stubs/api_samples/$name.json');
  final Map<String, dynamic> body = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final dynamic data = body['data'];
  return data is Map<String, dynamic> ? data : <String, dynamic>{};
}

void main() {
  test('GET /profile parses every section', () {
    final ProfileModel p = ProfileModel.fromJson(_data('profile'));

    expect(p.user.id, greaterThan(0), reason: 'user.id must parse');
    expect(p.sections.length, 9, reason: 'nine named groups are rendered');

    // The whole point of the grouped response: registration data must be
    // readable. If every group is empty the field names are wrong.
    final int filled = p.sections.fold<int>(
      0,
      (int sum, ({String key, String title, ProfileSection section}) s) =>
          sum + s.section.filledCount,
    );
    expect(filled, greaterThan(0), reason: 'at least one registration field must come through');

    // verification.ai must never be null — the UI reads it unconditionally.
    expect(p.verification.ai.status, isNotEmpty);
  });

  test('GET /verification/ai/status parses', () {
    final AiVerificationModel s = AiVerificationModel.fromJson(_data('ai_status'));
    expect(s.status, isNotEmpty);
    // canRetry defaults to true when the key is absent, so it is never null.
    expect(s.canRetry, isA<bool>());
  });

  test('GET /verification/ai/history parses', () {
    final dynamic raw = _data('ai_history')['attempts'];
    final List<AiVerificationAttempt> rows = (raw is List ? raw : <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AiVerificationAttempt.fromJson)
        .toList();
    for (final AiVerificationAttempt a in rows) {
      expect(a.id, greaterThan(0));
      expect(a.source, isNotEmpty);
    }
  });

  test('GET /interests/received parses, including pending_count', () {
    final InterestPage page = InterestPage.fromJson(_data('interests_received'));
    expect(page.currentPage, greaterThanOrEqualTo(1));
    expect(page.pendingCount, greaterThanOrEqualTo(0));
    for (final InterestModel i in page.interests) {
      expect(i.id, greaterThan(0));
      expect(i.direction, anyOf('sent', 'received'));
    }
  });

  test('GET /interests/sent carries the coin balance', () {
    final InterestPage page = InterestPage.fromJson(_data('interests_sent'));
    // The sent list is where the wallet rides along; losing it would make the
    // coin bar read zero and wrongly block sending.
    expect(page.coinBalance, isNotNull, reason: '/interests/sent returns coin_balance');
    expect(page.coinBalance!.costPerInterest, greaterThan(0));
  });

  test('GET /interests/coin-balance parses the configured cost', () {
    final InterestCoinBalance b = InterestCoinBalance.fromJson(_data('coin_balance'));
    // Must come from the server: the cost is admin-configurable and was 2 on
    // this install while older code assumed 1.
    expect(b.costPerInterest, greaterThan(0));
    expect(b.canSend, isA<bool>());
  });

  test('GET /partner-preferences un-nests age, height and income', () {
    final Map<String, dynamic> raw = _data('partner_preferences');
    final PartnerPreferenceModel p = PartnerPreferenceModel.fromJson(raw);

    // The read payload nests these; a flat read would silently produce nulls.
    final Map<String, dynamic> age = raw['age'] as Map<String, dynamic>;
    if (age['min'] != null) {
      expect(p.ageMin, isNotNull, reason: 'age.min must map to ageMin');
      expect(p.ageMin.toString(), age['min'].toString());
    }
    final Map<String, dynamic> height = raw['height'] as Map<String, dynamic>;
    if (height['min'] != null) {
      expect(p.heightMin, isNotNull, reason: 'height.min must map to heightMin');
    }

    // And the write shape must flatten + rename, or a save posts nothing the
    // validator recognises.
    final Map<String, dynamic> body = p.toUpdateJson();
    if (p.ageMin != null) {
      expect(body.containsKey('preferred_age_min'), isTrue);
      expect(body.containsKey('age'), isFalse, reason: 'never post the nested read shape');
    }
    if (p.countryId != null) {
      expect(body.containsKey('preferred_country_id'), isTrue);
      expect(body.containsKey('country_id'), isFalse);
    }
    // Nulls are dropped so a partial save cannot blank untouched preferences.
    expect(body.values.any((dynamic v) => v == null), isFalse);
  });

  test('GET /profiles/{id} exposes a badge and NO AI internals', () {
    final Map<String, dynamic> raw = _data('public_profile');
    final PublicProfileModel p = PublicProfileModel.fromJson(raw);
    expect(p.id, greaterThan(0));
    expect(p.identityVerified, isA<bool>());

    // A viewer must not receive another member's verification internals.
    final String encoded = jsonEncode(raw);
    for (final String leak in <String>[
      'recommendation',
      'attempts',
      'last_error',
      'fraud_risk_score',
      'ai_verification_status',
    ]) {
      expect(encoded.contains(leak), isFalse, reason: '$leak must not appear on a public profile');
    }
  });

  test('GET /profiles/{id}/compatibility parses', () {
    final CompatibilityModel c = CompatibilityModel.fromJson(_data('compatibility'));
    expect(c.profileId, greaterThan(0));
    expect(c.percentage, inInclusiveRange(0, 100));
  });
}
