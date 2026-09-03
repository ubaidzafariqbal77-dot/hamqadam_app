// Regression test for the client report: "jab me register ki traf jao to phr me
// login ki traf nahi a pata" — once you entered signup you could not get back
// to the login screen.
//
// Step 1 was the only step that passed no `onBack` to [StepScaffold], so its
// back chevron and its bottom "Back" button were absent, and the scaffold's
// `PopScope(canPop: false)` swallowed the system back gesture into a no-op.
// [StepController.back] compounded it by guarding on `stepNumber > 1`, so even
// wiring the button up would have done nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hamqadam/controllers/auth_controller.dart';
import 'package:hamqadam/controllers/registration_controller.dart';
import 'package:hamqadam/core/api/api_client.dart';
import 'package:hamqadam/core/network/network_info.dart';
import 'package:hamqadam/core/storage/current_user_service.dart';
import 'package:hamqadam/core/storage/profile_completion_service.dart';
import 'package:hamqadam/core/storage/registration_buffer.dart';
import 'package:hamqadam/core/storage/secure_storage_service.dart';
import 'package:hamqadam/repositories/auth_repository.dart';
import 'package:hamqadam/repositories/registration_repository.dart';
import 'package:hamqadam/widgets/step_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a real [RegistrationController]. None of its dependencies is touched
/// by the navigation code under test — they only have to exist.
Future<RegistrationController> _controller() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final SecureStorageService storage = SecureStorageService();
  final ApiClient client = ApiClient(storage: storage, networkInfo: NetworkInfo());
  final AuthRepository auth = AuthRepository(client);
  return RegistrationController(
    buffer: RegistrationBuffer(prefs),
    authRepository: auth,
    registrationRepository: RegistrationRepository(client),
    authController: AuthController(
      authRepository: auth,
      storage: storage,
      currentUser: CurrentUserService(prefs),
    ),
    completion: ProfileCompletionService(prefs),
  );
}

/// The bottom "Back" button. Its label is bilingual, so it renders as a
/// `Text.rich` ("Back  |  واپس") that `find.text` cannot match exactly.
final Finder _backButton = find.textContaining('Back', findRichText: true);

/// A stand-in for a signup step, wired exactly the way the real steps are.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.onBack});
  final int number;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: number,
      totalSteps: 18,
      title: 'Step $number',
      subtitle: '',
      busy: false.obs,
      primaryLabel: 'Continue',
      onPrimary: () async {},
      onBack: onBack,
      children: const <Widget>[Text('body')],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RegistrationController reg;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
    reg = await _controller();
    Get.put<RegistrationController>(reg);
  });

  tearDown(Get.reset);

  Widget app({required Widget step}) {
    return GetMaterialApp(
      initialRoute: '/login',
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(name: '/login', page: () => const Scaffold(body: Text('LOGIN'))),
        GetPage<dynamic>(name: '/step1', page: () => step),
      ],
    );
  }

  testWidgets('backing out of step 1 returns to login', (WidgetTester tester) async {
    await tester.pumpWidget(app(step: _Step(number: 1, onBack: reg.goToPreviousStep)));
    await tester.pumpAndSettle();

    // Login pushes step 1, exactly as the "Create account" row does.
    Get.toNamed<void>('/step1');
    await tester.pumpAndSettle();
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('LOGIN'), findsNothing);

    await tester.tap(_backButton);
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('step 1 offers a back control at all', (WidgetTester tester) async {
    // The bug was the absence of this button, not its behaviour: with no
    // `onBack` the scaffold renders the Continue button alone.
    await tester.pumpWidget(app(step: _Step(number: 1, onBack: reg.goToPreviousStep)));
    await tester.pumpAndSettle();
    Get.toNamed<void>('/step1');
    await tester.pumpAndSettle();

    expect(_backButton, findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
  });

  testWidgets('the system back gesture leaves step 1 too', (WidgetTester tester) async {
    await tester.pumpWidget(app(step: _Step(number: 1, onBack: reg.goToPreviousStep)));
    await tester.pumpAndSettle();
    Get.toNamed<void>('/step1');
    await tester.pumpAndSettle();

    // `PopScope(canPop: false)` routes the gesture through `onBack`; before the
    // fix that call chain ended in a `return` and the screen never changed.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('a later step still steps back through signup', (WidgetTester tester) async {
    // Leaving the flow must stay specific to step 1.
    reg.currentStep.value = 3;
    await tester.pumpWidget(app(step: _Step(number: 3, onBack: reg.goToPreviousStep)));
    await tester.pumpAndSettle();
    Get.toNamed<void>('/step1');
    await tester.pumpAndSettle();

    await tester.tap(_backButton);
    await tester.pumpAndSettle();

    expect(reg.currentStep.value, 2);
  });

  test('leaving step 1 keeps the answers already given', () async {
    reg.buffer.put(<String, dynamic>{'on_behalf': 1, 'gender': 2});
    reg.currentStep.value = 1;
    reg.exitToLogin();
    expect(reg.buffer.getInt('on_behalf'), 1);
    expect(reg.buffer.getInt('gender'), 2);
  });
}
