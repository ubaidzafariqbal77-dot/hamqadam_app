import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/constants/api_endpoints.dart';
import 'package:hamqadam/constants/api_options.dart';
import 'package:hamqadam/controllers/registration_payload.dart';
import 'package:hamqadam/core/storage/registration_buffer.dart';
import 'package:hamqadam/models/lookup_item_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the contract documented at https://hamqadam.com/api-docs:
/// the step endpoints, the UI↔API step map, and the value conversions.
void main() {

  group('registration endpoints', () {
    test('registration is one complete submission plus an email OTP', () {
      expect(ApiEndpoints.registerComplete, '/auth/register/complete');
      expect(ApiEndpoints.registerRequestOtp, '/auth/register/request-otp');
      expect(ApiEndpoints.registerVerifyOtp, '/auth/register/verify-otp');
    });

    test('the per-section save endpoint is authenticated for every step', () {
      // Step 1 must NOT fall back to the public `/step1`, or re-saving that
      // section after signup would create a second account.
      expect(ApiEndpoints.registerStep(1), '/auth/register/step/1');
      expect(ApiEndpoints.registerStep(2), '/auth/register/step/2');
      expect(ApiEndpoints.registerStep(18), '/auth/register/step/18');
    });
  });

  group('complete-payload field ownership', () {
    test('every field maps back to the screen that collected it', () {
      expect(RegSteps.uiStepForField('on_behalf'), 1);
      expect(RegSteps.uiStepForField('city_id'), 4);
      expect(RegSteps.uiStepForField('email'), 5);
      expect(RegSteps.uiStepForField('password_confirmation'), 11);
      expect(RegSteps.uiStepForField('selfie_verification'), 14);
      expect(RegSteps.uiStepForField('deal_breakers'), 18);
    });

    test('array members carry their parent field index', () {
      expect(RegSteps.uiStepForField('additional_photos.0'), 12);
      expect(RegSteps.uiStepForField('hobbies.2'), 15);
    });

    test('an unknown field resolves to null rather than a wrong screen', () {
      expect(RegSteps.uiStepForField('something_new'), isNull);
    });
  });

  group('UI step ↔ API step', () {
    test('the first ten screens map one-to-one', () {
      for (int step = 1; step <= 10; step++) {
        expect(RegSteps.apiStep(step), step);
      }
    });

    test('the reordered screens map to their documented API step', () {
      expect(RegSteps.apiStep(11), 18); // account security
      expect(RegSteps.apiStep(12), 11); // photos
      expect(RegSteps.apiStep(13), 12); // about
      expect(RegSteps.apiStep(14), 13); // identity verification
      expect(RegSteps.apiStep(15), 14); // interests
      expect(RegSteps.apiStep(16), 15); // family information
      expect(RegSteps.apiStep(17), 16); // family details
      expect(RegSteps.apiStep(18), 17); // partner preferences
    });

    test('uiStep is the inverse of apiStep', () {
      for (int step = 1; step <= RegSteps.total; step++) {
        expect(RegSteps.uiStep(RegSteps.apiStep(step)), step);
      }
    });

    test('only interests and the two family screens are skippable', () {
      final List<int> optional = <int>[
        for (int s = 1; s <= RegSteps.total; s++)
          if (RegSteps.isOptional(s)) s,
      ];
      expect(optional, <int>[15, 16, 17]);
    });

    test('photos and identity verification are the multipart steps', () {
      expect(RegSteps.isMultipart(12), isTrue);
      expect(RegSteps.isMultipart(14), isTrue);
      expect(RegSteps.isMultipart(13), isFalse);
    });
  });

  group('complete registration payload', () {
    late RegistrationBuffer buffer;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      buffer = RegistrationBuffer(await SharedPreferences.getInstance());
    });

    test('carries every documented field name from the buffered answers', () async {
      buffer.put(<String, dynamic>{
        'on_behalf': 1,
        'gender': 2,
        'marriage_timeline': 'within_6_months',
        'willing_to_work_after_marriage': 'depends_on_mutual_understanding',
        'expects_spouse_to_work': 'depends_on_mutual_understanding',
        'first_name': 'Ayesha',
        'last_name': 'Khan',
        'date_of_birth': '1998-04-15',
        'religion_id': 1,
        'mother_tongue': 1,
        'country_id': 166,
        'state_id': 2728,
        'city_id': 85568,
        'phone': '03001234567',
        'email': 'Ayesha@Example.com',
        'marital_status_id': 1,
        'education_status': 'completed',
        'graduation_year': 2024,
        'height_cm': 163,
        'diet': 'Vegetarian',
        'about_me': 'Family-oriented.',
        'cnic_number': '12345-6789012-3',
        'hobbies': <String>['Reading', 'Music'],
        'partner_age_min': 27,
        'password': 'Password123!',
        'password_confirmation': 'Password123!',
        'profile_photo': '/tmp/main.jpg',
        'gallery': <String>['/tmp/a.jpg', '/tmp/b.jpg'],
        'cnic_front': '/tmp/front.jpg',
        'cnic_back': '/tmp/back.jpg',
        'selfie': '/tmp/selfie.jpg',
      });

      final Map<String, dynamic> p = await RegPayload.complete(buffer);

      // Names are joined, the phone is split, the email lower-cased and the
      // height converted to the documented feet notation.
      expect(p['full_name'], 'Ayesha Khan');
      expect(p['country_code'], '+92');
      expect(p['phone'], '3001234567');
      expect(p['email'], 'ayesha@example.com');
      expect(p['email_verify'], 'ayesha@example.com');
      expect(p['height'], 5.4);

      // A completed education sends `graduation_year`, not the expected one.
      expect(p['graduation_year'], 2024);
      expect(p.containsKey('expected_graduation_year'), isFalse);

      // hobbies is ONE comma-separated string in the documented payload,
      // while deal_breakers stays an array.
      expect(p['hobbies'], 'Reading, Music');
      expect(p.isNotEmpty, isTrue);
    });

    test('an in-progress degree sends expected_graduation_year instead', () async {
      buffer.put(<String, dynamic>{
        'education_status': 'in_progress',
        'graduation_year': 2027,
      });
      final Map<String, dynamic> p = await RegPayload.complete(buffer);
      expect(p['expected_graduation_year'], 2027);
      expect(p.containsKey('graduation_year'), isFalse);
    });

    test('unanswered optional steps are omitted, never sent as null', () async {
      buffer.put(<String, dynamic>{'on_behalf': 1, 'area': '   '});
      final Map<String, dynamic> p = await RegPayload.complete(buffer);
      expect(p.containsKey('father_occupation'), isFalse);
      expect(p.containsKey('family_city'), isFalse);
      expect(p.containsKey('area'), isFalse); // blank strings too
      expect(p['on_behalf'], 1);
    });
  });

  group('value conversions', () {
    test('height is sent in feet', () {
      expect(ApiValues.heightFromCm(163), 5.4); // the documented sample
      expect(ApiValues.heightFromCm(168), 5.6);
      expect(ApiValues.heightFromCm(null), isNull);
    });

    test('phone is split into country code and number', () {
      expect(ApiValues.splitPhone('03001234567').countryCode, '+92');
      expect(ApiValues.splitPhone('03001234567').phone, '3001234567');
      expect(ApiValues.splitPhone('+923001234567').phone, '3001234567');
      expect(ApiValues.splitPhone('+14155552671').countryCode, '+1');
    });
  });

  group('hardcoded dropdowns', () {
    test('carry the exact documented values', () {
      expect(
        ApiOptions.marriageTimeline.map((LookupItem o) => o.code),
        <String>['immediate', 'within_3_months', 'within_6_months', 'within_1_year'],
      );
      expect(
        ApiOptions.workIntent.map((LookupItem o) => o.code),
        <String>['yes', 'no', 'depends_on_mutual_understanding'],
      );
      expect(
        ApiOptions.employmentStatus.map((LookupItem o) => o.code),
        <String>[
          'government',
          'private',
          'civil',
          'defence',
          'self_employed',
          'unemployed',
          'retired',
        ],
      );
      expect(
        ApiOptions.educationStatus.map((LookupItem o) => o.code),
        <String>['completed', 'in_progress', 'dropped'],
      );
      expect(
        ApiOptions.familyValues.map((LookupItem o) => o.code),
        <String>['Elite', 'High', 'Middle', 'Aspiring', 'Poor'],
      );
    });

    test('label ↔ value round-trips', () {
      const List<LookupItem> options = ApiOptions.employmentStatus;
      expect(ApiOptions.labelOf(options, 'self_employed'), 'Self-Employed');
      expect(ApiOptions.valueOfLabel(options, 'Self-Employed'), 'self_employed');
    });
  });

  group('lookup parsing', () {
    test('reads numeric ids and the typed parent key', () {
      final LookupItem city = LookupItem.fromJson(
        <String, dynamic>{'id': 85568, 'name': 'Lahore', 'state_id': 2728},
      );
      expect(city.id, 85568);
      expect(city.parentId, 2728);
      expect(city.apiValue, 85568);
    });

    test('reads string ids as option codes', () {
      final LookupItem hobby =
          LookupItem.fromJson(<String, dynamic>{'id': 'Reading', 'name': 'Reading'});
      expect(hobby.isOption, isTrue);
      expect(hobby.apiValue, 'Reading');
    });
  });
}
