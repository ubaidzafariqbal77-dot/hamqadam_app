import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/controllers/registration_payload.dart';
import 'package:hamqadam/core/storage/registration_buffer.dart';
import 'package:hamqadam/core/validators/app_validators.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Step 2 collects one `full_name` field instead of a first/last pair. Two
/// things have to keep holding: the validation stays as strict as requiring both
/// old fields, and a draft saved before the change still resumes with its name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('full name validation', () {
    test('accepts a normal two-part name', () {
      expect(AppValidators.fullName('Ahmed Khan'), isNull);
      expect(AppValidators.fullName("Zoya D'Souza"), isNull);
      expect(AppValidators.fullName('Mary-Jane Watson'), isNull);
      expect(AppValidators.fullName('Muhammad Ali Jinnah'), isNull);
    });

    test('still requires both parts, as the two old fields did', () {
      expect(AppValidators.fullName('Ahmed'), 'Please enter your first and last name');
      // Trailing space is not a second name.
      expect(AppValidators.fullName('Ahmed   '), 'Please enter your first and last name');
    });

    test('rejects empty, numeric and over-long names', () {
      expect(AppValidators.fullName(''), 'Full name is required');
      expect(AppValidators.fullName(null), 'Full name is required');
      expect(AppValidators.fullName('Ahmed Khan 2'), 'Full name cannot contain numbers');
      expect(AppValidators.fullName('A ${'b' * 120}'), contains('under 100'));
    });

    test('collapses runs of whitespace before judging or storing', () {
      expect(AppValidators.collapseSpaces('  Ahmed    Khan  '), 'Ahmed Khan');
      expect(AppValidators.fullName('Ahmed     Khan'), isNull);
    });
  });

  group('reading the name back out of the buffer', () {
    late RegistrationBuffer buffer;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      buffer = RegistrationBuffer(await SharedPreferences.getInstance());
    });

    test('uses full_name when step 2 has been filled in', () {
      buffer.put(<String, dynamic>{'full_name': 'Ahmed Khan'});
      expect(RegPayload.fullName(buffer), 'Ahmed Khan');
    });

    test('falls back to a pre-change draft holding first_name/last_name', () {
      buffer.put(<String, dynamic>{'first_name': 'Ahmed', 'last_name': 'Khan'});
      expect(RegPayload.fullName(buffer), 'Ahmed Khan');
    });

    test('full_name wins over a stale legacy pair', () {
      buffer.put(<String, dynamic>{
        'first_name': 'Old',
        'last_name': 'Name',
        'full_name': 'Ahmed Khan',
      });
      expect(RegPayload.fullName(buffer), 'Ahmed Khan');
    });

    test('is null when nothing has been entered, so the field is omitted', () {
      expect(RegPayload.fullName(buffer), isNull);
    });

    test('a half-filled legacy draft still yields the part that exists', () {
      buffer.put(<String, dynamic>{'first_name': 'Ahmed'});
      expect(RegPayload.fullName(buffer), 'Ahmed');
    });
  });
}
