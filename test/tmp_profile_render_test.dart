// TEMPORARY visual harness — renders ProfileView with a realistic
// `GET /profile` payload so the layout can be inspected without a login.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hamqadam/controllers/lookup_controller.dart';
import 'package:hamqadam/controllers/profile_controller.dart';
import 'package:hamqadam/core/api/api_client.dart';
import 'package:hamqadam/core/api/api_response.dart';
import 'package:hamqadam/core/network/network_info.dart';
import 'package:hamqadam/core/storage/profile_completion_service.dart';
import 'package:hamqadam/core/storage/secure_storage_service.dart';
import 'package:hamqadam/core/theme/app_theme.dart';
import 'package:hamqadam/features/profile/views/profile_view.dart';
import 'package:hamqadam/models/profile_model.dart';
import 'package:hamqadam/repositories/lookup_repository.dart';
import 'package:hamqadam/repositories/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, dynamic> _payload = <String, dynamic>{
  'user': <String, dynamic>{
    'id': 66,
    'code': 'HQ-000066',
    'first_name': 'Younis',
    'last_name': 'Gopang',
    'name': 'Younis Gopang',
    'email': 'hr.yirsystem@gmail.com',
    'phone': '+923336677485',
    'photo': 'https://hamqadam.com/public/uploads/all/6a8b54c88c68e.jpeg',
    'approved': true,
    'blocked': false,
    'deactivated': false,
  },
  'member': <String, dynamic>{
    'gender': 1,
    'date_of_birth': '2001-08-24 00:00:00',
    'about_me': 'Software engineer from Karachi. Family oriented, practising, and looking '
        'for a partner who values honesty and kindness.',
    'ai_generated_bio': null,
    'marital_status_id': 1,
    'children': null,
    'on_behalf_id': 1,
    'annual_salary_range_id': null,
    'mother_tongue': 6,
    'known_languages': <int>[6, 1],
    'travel_preferences': null,
    'future_goals': null,
    'hide_profile': false,
    'verification_status': 'submitted',
    'profile_completion_percentage': 100,
  },
  'religion_and_language': <String, dynamic>{
    'religion_id': 1,
    'sect_main_id': 2,
    'school_of_thought_id': 9,
    'tradition_id': null,
    'mother_tongue': 6,
    'languages_spoken_fluently': <int>[],
    'prayer_frequency': null,
    'religious_practice_level': null,
    'hijab_beard_preference': null,
  },
  'caste': <String, dynamic>{'caste_id': 8, 'sub_caste_id': 27},
  'location': <String, dynamic>{
    'country_id': 166,
    'state_id': 2728,
    'city_id': 31496,
    'area': 'Shamsabad',
  },
  'education': <String, dynamic>{
    'education_level_id': 6,
    'degree_id': 1,
    'field_of_study_id': 7,
    'institution_id': 21,
    'education_status': 'completed',
    'graduation_year': 2024,
  },
  'career': <String, dynamic>{
    'employment_status': 'private',
    'profession_category_id': 3,
    'profession_id': 39,
    'job_title': 'Flutter Engineer',
    'organization': 'Gopang Systems',
    'years_of_experience': 3,
    'annual_income': 2000000,
  },
  'physical': <String, dynamic>{'height': 5.6, 'diet': 'Non-Vegetarian', 'complexion': null},
  'lifestyle_and_interests': <String, dynamic>{
    'hobbies': <String>['Reading', 'Traveling', 'Cooking', 'Gardening', 'Yoga'],
    'smoking': null,
  },
  'family': <String, dynamic>{
    'father_occupation': 'Died',
    'mother_occupation': 'Homemaker / Housewife',
    'siblings_brothers': 2,
    'siblings_sisters': 1,
    'live_with_family': 'yes',
    'family_values': 'moderate',
  },
  'marriage_expectations': <String, dynamic>{
    'marriage_timeline': 'immediate',
    'expects_spouse_to_work': 'yes',
    'willing_to_work_after_marriage': null,
  },
  'photos': <String, dynamic>{
    'profile_photo': 'https://hamqadam.com/public/uploads/all/6a8b54c88c68e.jpeg',
    'cover_photo': null,
    'gallery': <String>['https://hamqadam.com/a.jpg', 'https://hamqadam.com/b.jpg'],
  },
  'verification': <String, dynamic>{
    'status': 'submitted',
    'ai': <String, dynamic>{'status': 'pending'},
  },
  'privacy': <String, dynamic>{
    'show_photo': true,
    'show_gallery': true,
    'show_contact': false,
    'show_email': false,
    'show_phone': false,
    'show_location': true,
    'allow_profile_view_notifications': true,
  },
  'registration': <String, dynamic>{'completion_percentage': 100, 'steps': <String>[]},
};

Future<void> _loadFonts() async {
  final FontLoader loader = FontLoader('PlusJakartaSans');
  for (final String f in <String>['Regular', 'Medium', 'Bold', 'ExtraBold']) {
    final File file = File('assets/fonts/Plus_Jakarta_Sans/PlusJakartaSans-$f.ttf');
    if (!file.existsSync()) continue;
    final Uint8List bytes = await file.readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile screen golden', (WidgetTester tester) async {
    late final ProfileController pc;
    late final ProfileCompletionService completion;

    // Real I/O (fonts, the bundled lookup asset, the isolate that parses it)
    // cannot progress inside the fake-async zone testWidgets runs in.
    // connectivity_plus has no implementation in tests; NetworkInfo listens to
    // it on construction, which would otherwise log a MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (MethodCall call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall call) async => <String>['wifi'],
    );

    await tester.runAsync(() async {
      await _loadFonts();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final ApiClient client = ApiClient(
        storage: SecureStorageService(),
        networkInfo: NetworkInfo(),
      );
      final LookupController lookup = LookupController(LookupRepository(client));
      await lookup.preloadReference();
      for (final String key in ProfileController.lookupKeysUsed) {
        await lookup.ensure(key);
      }

      completion = ProfileCompletionService(prefs);
      pc = ProfileController(ProfileRepository(client), lookup, completion);
    });

    Get.put<ProfileCompletionService>(completion);
    // The state is set by hand below, so the controller's own fetch is skipped.
    pc.state.value = ApiState<ProfileModel>.success(ProfileModel.fromJson(_payload));
    Get.put<ProfileController>(pc, permanent: true);

    tester.view.physicalSize = const Size(1080, 3800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(Get.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: ProfileView()),
      ),
    );
    pc.state.value = ApiState<ProfileModel>.success(ProfileModel.fromJson(_payload));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // ignore: avoid_print
    print('TEXT: ${tester.widgetList<Text>(find.byType(Text)).map((Text t) => t.data ?? '').join(' | ')}');

    await expectLater(
      find.byType(ProfileView),
      matchesGoldenFile('goldens/profile_dark_1.png'),
    );
    for (int i = 2; i <= 5; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -1150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(ProfileView),
        matchesGoldenFile('goldens/profile_dark_$i.png'),
      );
    }
  });
}
