// End-to-end: the real Step 13 screen -> BioAiProfile -> Bio AI service.
//
// Needs the Bio AI service running (port 8100) and a simulator/emulator:
//   flutter test integration_test/bio_ai_e2e_test.dart -d <device> \
//     --dart-define=BIO_AI_BASE_URL=http://127.0.0.1:8100
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'package:hamqadam/constants/app_lookups.dart';
import 'package:hamqadam/controllers/lookup_controller.dart';
import 'package:hamqadam/core/dependency/app_dependencies.dart';
import 'package:hamqadam/core/storage/registration_buffer.dart';
import 'package:hamqadam/features/registration/steps/step13_about.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI button writes a template-based bio from earlier steps', (
    WidgetTester tester,
  ) async {
    await AppDependencies.init();
    // Ids differ between the bundled and the live lists, so look them up by
    // name exactly as the location step would have stored them.
    final LookupController lookup = Get.find<LookupController>();
    Future<int> idOf(String key, String name, {int? parentId}) async {
      await lookup.load(key, parentId: parentId);
      return lookup.itemsOf(key, parentId: parentId).firstWhere((e) => e.name == name).id;
    }

    final int country = await idOf(LookupKeys.countries, 'Pakistan');
    final int state = await idOf(LookupKeys.states, 'Punjab', parentId: country);
    final int city = await idOf(LookupKeys.cities, 'Lahore', parentId: state);
    Get.find<RegistrationBuffer>().put(<String, dynamic>{
      'full_name': 'Ali Raza',
      'date_of_birth': '1997-04-12',
      'gender': 1,
      'country_id': country,
      'state_id': state,
      'city_id': city,
      'marital_status_id': 1,
      'job_title': 'Software Engineer',
      'organization': 'Systems Ltd',
      'years_of_experience': 4,
      'hobbies': <String>['Reading', 'Cricket'],
    });

    await tester.pumpWidget(const GetMaterialApp(home: Step13View()));
    await tester.pumpAndSettle();
    final Step13Controller c = Get.find<Step13Controller>();

    Future<String> tapAi() async {
      final String before = c.aboutMe.text;
      await tester.tap(find.text('Write with AI'));
      for (int i = 0; i < 600 && (c.generating.value || c.aboutMe.text == before); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return c.aboutMe.text;
    }

    final String first = await tapAi();
    debugPrint('BIO#1 (${first.length} chars):\n$first');
    expect(first, startsWith("I'm someone who believes that the right person"));
    expect(first.length, lessThanOrEqualTo(Step13Controller.maxChars));
    expect(first.split('\n\n'), hasLength(3));
    expect(first.split('\n\n')[1], startsWith("I'm Ali. "));

    final String second = await tapAi();
    debugPrint('BIO#2 (${second.length} chars):\n$second');
    expect(second, isNot(first));
    expect(second.length, lessThanOrEqualTo(Step13Controller.maxChars));
  });
}
