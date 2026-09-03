// Regression tests for the issues reported from client testing (APP-004,
// APP-005/6/7, APP-008, APP-009, APP-010, APP-011).
//
// The profile fixture is a REAL capture of the reporting account, taken from
// the live backend while the bugs were reproducible. It is the exact state that
// produced the two headline complaints:
//
//   member.profile_completion_percentage = 100   (server says complete)
//   member.verification_status           = submitted  (manual review pending)
//   user.approved                        = true       (set at registration)
//   verification.ai.status               = approved   (pre-screen only)
//
// so a fixture that ever stops showing that combination has stopped testing
// what it was written for.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/constants/api_options.dart';
import 'package:hamqadam/constants/feature_access.dart';
import 'package:hamqadam/constants/income_options.dart';
import 'package:hamqadam/controllers/finalizing_controller.dart';
import 'package:hamqadam/controllers/registration_payload.dart';
import 'package:hamqadam/core/storage/registration_buffer.dart';
import 'package:hamqadam/core/storage/profile_completion_service.dart';
import 'package:hamqadam/models/lookup_item_model.dart';
import 'package:hamqadam/models/profile_model.dart';
import 'package:hamqadam/models/verification_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _data(String name) {
  final File f = File('dev_stubs/api_samples/$name.json');
  final Map<String, dynamic> body =
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final dynamic data = body['data'];
  return data is Map<String, dynamic> ? data : <String, dynamic>{};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _finalizeFixTests();
  _salaryRangeTests();

  final ProfileModel complete =
      ProfileModel.fromJson(_data('profile_complete_in_review'));

  group('APP-004 — profile completion survives a re-login', () {
    late ProfileCompletionService completion;

    setUp(() async {
      // A fresh install / post-logout state: nothing remembered locally.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      completion = ProfileCompletionService(await SharedPreferences.getInstance());
    });

    test('fixture still carries the reported state', () {
      expect(complete.member.profileCompletion, 100);
      expect(complete.member.verificationStatus, 'submitted');
      expect(complete.user.approved, isTrue);
      expect(complete.verification.ai.status, 'approved');
    });

    test('starts empty, then adopts the server percentage', () {
      expect(completion.percent, 0);

      completion.reconcile(complete);

      // The bug: this used to come back as 5 of 15 local sections (~31%)
      // because only five sections were reconciled and the server value was
      // ignored entirely.
      expect(completion.percent, 100);
      expect(completion.isComplete, isTrue);
      expect(completion.pendingCount, 0,
          reason: 'a 100% profile must not still list sections as outstanding');
    });

    test('survives a restart without the profile being re-fetched', () async {
      completion.reconcile(complete);

      // Rebuild from the same backing store, as a cold launch would.
      final ProfileCompletionService restarted =
          ProfileCompletionService(await SharedPreferences.getInstance());

      expect(restarted.percent, 100);
    });

    test('a partially-filled profile is not rounded up to complete', () {
      final ProfileModel partial = ProfileModel.fromJson(_data('profile'));
      expect(partial.member.profileCompletion, lessThan(100));

      completion.reconcile(partial);

      expect(completion.percent, partial.member.profileCompletion);
      expect(completion.isComplete, isFalse);
      expect(completion.pendingCount, greaterThan(0));
    });
  });

  group('APP-008 / APP-010 — approved account vs. identity verification', () {
    test('an AI pass alone does NOT mark the identity verified', () {
      final ProfileVerification v = complete.verification;

      expect(v.ai.isApproved, isTrue, reason: 'pre-screen passed');
      expect(v.inManualReview, isTrue, reason: 'a human has not decided yet');

      // The bug: identityVerified used to be `documentsVerified || ai.isApproved`,
      // so this account showed a verified badge while still in manual review.
      expect(v.identityVerified, isFalse);
      expect(v.aiClearedAwaitingReview, isTrue);
    });

    test('user.approved does not imply a verified identity', () {
      // `approved` is set to 1 at registration, so it means "account usable",
      // never "identity checked".
      expect(complete.user.approved, isTrue);
      expect(complete.verification.identityVerified, isFalse);
    });

    test('only a moderator approval flips the badge', () {
      final ProfileVerification approved = ProfileVerification.fromJson(
        <String, dynamic>{
          'status': 'verified',
          'ai': <String, dynamic>{'status': 'approved'},
        },
      );
      expect(approved.identityVerified, isTrue);
      expect(approved.inManualReview, isFalse);
    });
  });

  group('APP-011 — individual and overall verification statuses', () {
    final VerificationModel record =
        VerificationModel.fromJson(_data('verification_current'));

    test('parses the whole record, not just a status string', () {
      expect(record.status, 'submitted');
      expect(record.documents, hasLength(3));
      expect(record.hasCnicFront, isTrue);
      expect(record.hasCnicBack, isTrue);
      expect(record.hasSelfie, isTrue);
      expect(record.faceMatchStatus, 'matched');
      expect(record.faceMatchScore, isNotNull);
    });

    test('each check reports its own status', () {
      expect(record.checklist, hasLength(3));
      expect(record.cnicStatus, VerificationItemStatus.inReview);
      expect(record.selfieStatus, VerificationItemStatus.inReview);
      // Face match has a verdict of its own, so it resolves ahead of the review.
      expect(record.livenessStatus, VerificationItemStatus.passed);
    });

    test('the overall status is the reviewer decision', () {
      expect(record.overallStatus, VerificationItemStatus.inReview);
      expect(record.isApproved, isFalse);
      expect(record.canSubmit, isFalse,
          reason: 'the API answers 409 while a request is open');
    });

    test('a missing record reads as nothing submitted', () {
      final VerificationModel none = VerificationModel.none();
      expect(none.exists, isFalse);
      expect(none.overallStatus, VerificationItemStatus.missing);
      expect(none.canSubmit, isTrue);
    });
  });

  group('APP-009 — feature access matrix', () {
    test('manual review keeps own-account features open', () {
      const FeatureAccess review = FeatureAccess(VerificationGate.inManualReview);

      expect(review.can(AppFeature.editProfile), isTrue);
      expect(review.can(AppFeature.partnerPreferences), isTrue);
      expect(review.can(AppFeature.uploadPhotos), isTrue);
      expect(review.can(AppFeature.browseProfiles), isTrue);
    });

    test('manual review holds back anything that reaches another member', () {
      const FeatureAccess review = FeatureAccess(VerificationGate.inManualReview);

      expect(review.can(AppFeature.sendInterest), isFalse);
      expect(review.can(AppFeature.chat), isFalse);
      expect(review.can(AppFeature.sendProposal), isFalse);
      expect(review.can(AppFeature.viewContactDetails), isFalse);

      // The two deliberate exceptions.
      expect(review.can(AppFeature.viewFullProfile), isTrue);
      expect(review.can(AppFeature.respondToInterest), isTrue);
    });

    test('a blocked feature always explains itself', () {
      const FeatureAccess review = FeatureAccess(VerificationGate.inManualReview);
      expect(review.reasonFor(AppFeature.sendInterest), isNotNull);
      expect(review.reasonFor(AppFeature.editProfile), isNull);
    });

    test('verification cannot be resubmitted while it is in review', () {
      expect(
        const FeatureAccess(VerificationGate.inManualReview)
            .can(AppFeature.submitVerification),
        isFalse,
      );
      expect(
        const FeatureAccess(VerificationGate.rejected)
            .can(AppFeature.submitVerification),
        isTrue,
      );
    });

    test('the gate is read off the document workflow, not the AI pre-screen', () {
      expect(VerificationGate.of(complete.verification),
          VerificationGate.inManualReview);
    });
  });

  group('APP-005 / APP-006 / APP-007 — the missing option lists', () {
    test('income bands are contiguous and ordered', () {
      final List<IncomeBand> bands = IncomeBand.bands;
      expect(bands, isNotEmpty);
      for (int i = 0; i < bands.length - 1; i++) {
        expect(bands[i].max, isNotNull);
        expect(bands[i].max! + 1, bands[i + 1].min,
            reason: 'band ${i + 1} must start where band $i ends');
      }
      expect(bands.last.max, isNull, reason: 'the top band is open-ended');
    });

    test('a stored amount maps back to its band', () {
      // `annual_income` is a decimal, so it never equals a band id exactly.
      expect(IncomeBand.labelFor(1200000), 'PKR 10 – 15 Lac');
      expect(IncomeBand.labelFor(50000000), 'Above PKR 1 Crore');
      expect(IncomeBand.labelFor(null), isNull);
    });

    test('an income band submits a number the API accepts', () {
      final IncomeBand band = IncomeBand.bands[3];
      expect(band.item.apiValue, isA<int>());
      expect(band.item.apiValue, band.min);
    });

    test('sibling options cover none, 1..10 and an overflow row', () {
      expect(SiblingOptions.options.first.name, 'None');
      expect(SiblingOptions.options, hasLength(SiblingOptions.maxListed + 2));
      expect(SiblingOptions.labelFor(0), 'None');
      expect(SiblingOptions.labelFor(3), '3');
      expect(SiblingOptions.labelFor(25), 'More than 10');
    });
  });
}

/// Correcting a field the finalizing screen rejected must return the user to
/// finalizing — not drop them back into the forward flow to walk every
/// remaining step again.
void _finalizeFixTests() {
  group('Finalize — rejected fields resolve to their screen', () {
    test('each rejected field names itself readably', () {
      const RejectedField income = RejectedField(
        field: 'annual_income',
        message: 'The annual income field is required.',
      );
      expect(income.label, 'Annual income');

      // A trailing `_id` is plumbing, not something the user chose.
      const RejectedField religion = RejectedField(
        field: 'religion_id',
        message: 'Invalid religion.',
      );
      expect(religion.label, 'Religion');

      // Laravel reports nested errors as `known_languages.0`.
      const RejectedField nested = RejectedField(
        field: 'known_languages.0',
        message: 'Invalid language.',
      );
      expect(nested.label, 'Known languages');
    });

    test('a field maps to the screen that collected it', () {
      expect(RegSteps.uiStepForField('religion_id'), 3);
      expect(RegSteps.uiStepForField('email'), 5);
      expect(RegSteps.uiStepForField('marital_status_id'), 7);
      expect(RegSteps.uiStepForField('annual_income'), 10);
      // Nested keys resolve to the same screen as their parent.
      expect(RegSteps.uiStepForField('known_languages.0'),
          RegSteps.uiStepForField('known_languages'));
    });

    test('an unmappable field is reported but not tappable', () {
      const RejectedField unknown = RejectedField(
        field: 'something_the_app_does_not_collect',
        message: 'Rejected.',
      );
      expect(unknown.uiStep, isNull);
      expect(RegSteps.uiStepForField(unknown.field), isNull);
    });
  });
}

/// The two issues the client hit on the finalizing screen and on step 1.
///
/// `GET /auth/register/steps` lists step 10 as
/// `["annual_salary_range_id", "employment_status", "profession_category_id",
///   "profession_id", "job_title", "organization", "years_of_experience"]` —
/// the numeric `annual_income` is gone. The app was still sending only
/// `annual_income`, so every submission came back with
/// "The annual salary range id field is required.", and because
/// `annual_salary_range_id` was not in the field→screen map the error rendered
/// as an untappable row: retry re-sent the same payload, forever.
void _salaryRangeTests() {
  group('Finalize — annual_salary_range_id (client report)', () {
    late RegistrationBuffer buffer;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      buffer = RegistrationBuffer(await SharedPreferences.getInstance());
    });

    test('the id the step collects reaches the submitted payload', () async {
      buffer.put(<String, dynamic>{
        'annual_salary_range_id': 8,
        'employment_status': 'private',
        'profession_category_id': 1,
      });

      final Map<String, dynamic> p = await RegPayload.complete(buffer);

      expect(p['annual_salary_range_id'], 8);
    });

    test('a career section save carries it too', () {
      buffer.put(<String, dynamic>{'annual_salary_range_id': 3});
      expect(RegPayload.career(buffer)['annual_salary_range_id'], 3);
    });

    test('the rejected field is tappable and names its screen', () {
      // Was null, which is what made the row a dead end on the finalizing
      // screen — the client could only "Try again" into the same rejection.
      expect(RegSteps.uiStepForField('annual_salary_range_id'), 10);

      const RejectedField f = RejectedField(
        field: 'annual_salary_range_id',
        message: 'The annual salary range id field is required.',
        uiStep: 10,
      );
      expect(f.label, 'Annual salary range');
    });

    test('the offered ids are the ones the server accepts', () {
      // Verified against POST /auth/register/complete: 1..16 pass `exists`,
      // 17 and above come back "The selected annual salary range id is
      // invalid." The labels are provisional; the ids are not.
      expect(SalaryRangeOptions.options.length, 16);
      expect(
        SalaryRangeOptions.options.map((LookupItem i) => i.id).toList(),
        List<int>.generate(16, (int i) => i + 1),
      );
      expect(SalaryRangeOptions.options.every((LookupItem i) => i.name.isNotEmpty), isTrue);
    });

    test('an id outside the server range is not treated as a selection', () {
      expect(SalaryRangeOptions.isValid(1), isTrue);
      expect(SalaryRangeOptions.isValid(16), isTrue);
      expect(SalaryRangeOptions.isValid(17), isFalse);
      expect(SalaryRangeOptions.isValid(0), isFalse);
      expect(SalaryRangeOptions.isValid(null), isFalse);
    });
  });
}
