import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/features/discover/widgets/compatibility_section.dart';
import 'package:hamqadam/models/public_profile_model.dart';

/// The exact payload `GET /profiles/{id}/compatibility` returns on the
/// `ai_sidecar` branch of ProfileController: the matchmaking model's
/// `criterion_matches` list, verbatim from a live call to
/// https://matchmaking.hamqadam.com/match.
const String _aiResponse = '''
{
  "profile_id": 5,
  "compatibility_percentage": 81,
  "compatibility_explanation": "Satisfied in both directions: Age, Diet, Height, Religion",
  "compatibility_reasons": [
    "Satisfied in both directions: Age, Diet, Height, Religion",
    "Height 162cm is within preferred range 150-175cm",
    "Religion matches: Islam"
  ],
  "score_breakdown": [
    {"criterion": "religion", "score": 100, "status": "match",
     "reason": "Religion matches: Islam", "is_hard_constraint": true,
     "applicable": true, "candidate_value": "Islam", "preference_value": "Islam"},
    {"criterion": "age", "score": 100, "status": "match",
     "reason": "Age 26 is within preferred range 22-30", "applicable": true},
    {"criterion": "height", "score": 90, "status": "match",
     "reason": "Height 162cm is within preferred range 150-175cm", "applicable": true},
    {"criterion": "profession", "score": 20, "status": "mismatch",
     "reason": "Teacher is not among the preferred professions", "applicable": true},
    {"criterion": "family_structure", "score": 0, "status": "unknown",
     "reason": "Not provided", "applicable": true}
  ],
  "calculated_at": "2026-09-12T17:30:00.000000Z",
  "source": "ai_sidecar"
}
''';

/// The other shape the same endpoint can return: a stored rule-based row,
/// where `score_breakdown` is a MAP of dimension -> score rather than a list.
const String _storedResponse = '''
{
  "profile_id": 9,
  "compatibility_percentage": 64,
  "compatibility_explanation": "Scored from your saved preferences.",
  "compatibility_reasons": [],
  "score_breakdown": {"religion": 100, "age": 80, "education": 40},
  "calculated_at": "2026-09-10T09:00:00.000000Z",
  "source": "stored"
}
''';

CompatibilityModel _parse(String raw) =>
    CompatibilityModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);

Future<void> _pump(WidgetTester tester, CompatibilityModel? model) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CompatibilitySection(future: Future<CompatibilityModel?>.value(model)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CompatibilityModel parsing', () {
    test('reads the AI list-shaped breakdown', () {
      final CompatibilityModel m = _parse(_aiResponse);

      expect(m.percentage, 81);
      expect(m.isAi, isTrue);
      expect(m.sourceLabel, 'AI matchmaking');
      expect(m.reasons.length, 3);
      expect(m.breakdown.length, 5, reason: 'every criterion must survive parsing');

      final CompatibilityCriterion religion = m.breakdown.first;
      expect(religion.name, 'religion');
      expect(religion.label, 'Religion');
      expect(religion.isMatch, isTrue);
      expect(religion.isHardConstraint, isTrue);
      expect(religion.reason, 'Religion matches: Islam');

      // Met, unmet and unknown must be separated correctly: an unknown
      // criterion is not a failure and must not be shown as one.
      expect(m.matched.map((CompatibilityCriterion c) => c.name),
          containsAll(<String>['religion', 'age', 'height']));
      expect(m.unmatched.map((CompatibilityCriterion c) => c.name), <String>['profession']);
      expect(m.unmatched.any((CompatibilityCriterion c) => c.name == 'family_structure'), isFalse);
    });

    test('reads the stored map-shaped breakdown', () {
      final CompatibilityModel m = _parse(_storedResponse);

      expect(m.percentage, 64);
      expect(m.isAi, isFalse);
      expect(m.sourceLabel, 'Saved score');
      expect(m.breakdown.length, 3);
      expect(m.breakdown.map((CompatibilityCriterion c) => c.name),
          containsAll(<String>['religion', 'age', 'education']));
      // score >= 70 counts as met when the backend sends no explicit status.
      expect(m.matched.map((CompatibilityCriterion c) => c.name),
          containsAll(<String>['religion', 'age']));
    });

    test('a malformed breakdown degrades to empty instead of throwing', () {
      expect(CompatibilityCriterion.parseBreakdown(null), isEmpty);
      expect(CompatibilityCriterion.parseBreakdown('nonsense'), isEmpty);
      expect(CompatibilityCriterion.parseBreakdown(<dynamic>[1, 'x']), isEmpty);
    });
  });

  group('CompatibilitySection rendering', () {
    testWidgets('renders the AI score, reasons and criteria', (WidgetTester tester) async {
      await _pump(tester, _parse(_aiResponse));

      // The reference design: accent bar + "81% compatibility" headline under
      // a "Why this match?" header, with the checklist beneath.
      expect(find.text('Why this match?'), findsOneWidget);
      expect(find.text('81% compatibility'), findsOneWidget);
      expect(find.text('AI matchmaking · Very high compatibility'), findsOneWidget);
      expect(find.text('Why?'), findsOneWidget);

      // Both sides of the verdict are on screen, not just the flattering half.
      expect(find.text('Religion'), findsOneWidget);
      expect(find.text('Profession'), findsOneWidget);
    });

    testWidgets('renders a stored rule-based score', (WidgetTester tester) async {
      await _pump(tester, _parse(_storedResponse));

      expect(find.text('64% compatibility'), findsOneWidget);
      expect(find.text('Saved score · High compatibility'), findsOneWidget);
    });

    testWidgets('shows nothing for a zero score', (WidgetTester tester) async {
      await _pump(tester, const CompatibilityModel(profileId: 1, percentage: 0));
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('shows nothing when the score cannot be loaded', (WidgetTester tester) async {
      await _pump(tester, null);
      expect(find.byType(Container), findsNothing);
    });
  });
}
