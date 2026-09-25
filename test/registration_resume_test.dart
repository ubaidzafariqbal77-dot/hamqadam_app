// Regression test for the client report: "register karte hue agar main kisi bhi
// step se back back press karke login par aa jaoon, to registered account ka
// username/password dalne par app ki bajaye usi adhoore step par le jata hai."
//
// The draft lives in SharedPreferences, so it outlives the signup that created
// it: back out of every step → login → sign in with a FINISHED account, and
// `resume()` used to route straight to `buffer.lastStep`. The server's
// `registration_completed` verdict (and the draft's own email, when it belongs
// to somebody else) now outranks it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hamqadam/controllers/auth_controller.dart';
import 'package:hamqadam/controllers/registration_controller.dart';
import 'package:hamqadam/core/api/api_client.dart';
import 'package:hamqadam/core/network/network_info.dart';
import 'package:hamqadam/core/routes/app_routes.dart';
import 'package:hamqadam/core/storage/current_user_service.dart';
import 'package:hamqadam/core/storage/profile_completion_service.dart';
import 'package:hamqadam/core/storage/registration_buffer.dart';
import 'package:hamqadam/core/storage/secure_storage_service.dart';
import 'package:hamqadam/models/user_model.dart';
import 'package:hamqadam/repositories/auth_repository.dart';
import 'package:hamqadam/repositories/registration_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A signed-in session without touching the platform keychain — tests have no
/// secure-storage plugin, and `hasToken` is all the routing reads.
class _SignedInStorage extends SecureStorageService {
  @override
  bool get hasToken => true;
}

class _Env {
  _Env(this.reg, this.auth);
  final RegistrationController reg;
  final AuthController auth;
}

/// Real controllers, wired exactly like production — but with a user payload
/// the test chooses, since that payload carries `registration_completed`.
Future<_Env> _env(Map<String, dynamic> user) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final SecureStorageService storage = _SignedInStorage();
  final ApiClient client =
      ApiClient(storage: storage, networkInfo: NetworkInfo());
  final AuthRepository authRepo = AuthRepository(client);
  final CurrentUserService currentUser = CurrentUserService(prefs);

  final AuthController auth = AuthController(
    authRepository: authRepo,
    storage: storage,
    currentUser: currentUser,
  );
  await currentUser.save(user);
  auth.user.value = UserModel.fromJson(user);

  final RegistrationController reg = RegistrationController(
    buffer: RegistrationBuffer(prefs),
    authRepository: authRepo,
    registrationRepository: RegistrationRepository(client),
    authController: auth,
    completion: ProfileCompletionService(prefs),
  );
  return _Env(reg, auth);
}

/// A local draft sitting on step 1 — the state "backed out of signup" leaves.
void _abandonedDraft(RegistrationController reg, {String? email}) {
  reg.buffer.markCompleted(1);
  reg.buffer.lastStep = 1;
  if (email != null) reg.buffer.put(<String, dynamic>{'email': email});
}

Widget _app() {
  return GetMaterialApp(
    initialRoute: AppRoutes.login,
    getPages: <GetPage<dynamic>>[
      GetPage<dynamic>(
        name: AppRoutes.login,
        page: () => const Scaffold(body: Text('LOGIN')),
      ),
      GetPage<dynamic>(
        name: AppRoutes.home,
        page: () => const Scaffold(body: Text('HOME')),
      ),
      GetPage<dynamic>(
        name: AppRoutes.routeForStep(1),
        page: () => const Scaffold(body: Text('STEP1')),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets(
      'a registered account logs in to HOME, not to the abandoned step',
      (WidgetTester tester) async {
    final _Env env = await _env(<String, dynamic>{
      'id': 10,
      'email': 'ayesha@example.com',
      'registration_completed': true,
    });
    _abandonedDraft(env.reg, email: 'ayesha@example.com');

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
    expect(env.auth.hasToken, isTrue);

    await env.reg.resume();
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    // The stale draft is dropped so it cannot prefill the next "Create Account".
    expect(env.reg.buffer.hasDraftInProgress, isFalse);
    expect(env.reg.buffer.isEmpty, isTrue);
  });

  testWidgets('an unfinished account still resumes its own step',
      (WidgetTester tester) async {
    final _Env env = await _env(<String, dynamic>{
      'id': 11,
      'email': 'half.done@example.com',
      'registration_completed': false,
    });
    _abandonedDraft(env.reg, email: 'half.done@example.com');

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await env.reg.resume();
    await tester.pumpAndSettle();

    expect(find.text('STEP1'), findsOneWidget);
    expect(env.reg.buffer.hasDraftInProgress, isTrue);
  });

  testWidgets('a draft belonging to another email is discarded on login',
      (WidgetTester tester) async {
    // Signup started with one address, then the member signed in with a
    // different, unfinished account: those answers are not this session's.
    final _Env env = await _env(<String, dynamic>{
      'id': 12,
      'email': 'member@example.com',
      'registration_completed': false,
    });
    _abandonedDraft(env.reg, email: 'stranger@example.com');

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await env.reg.resumeAfterLogin();
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(env.reg.buffer.isEmpty, isTrue);
  });
}
