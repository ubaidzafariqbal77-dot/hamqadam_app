import 'package:get/get.dart';

import 'bounce_page_transition.dart';
import '../../features/auth/views/forgot_password_view.dart';
import '../../features/auth/views/home_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/onboarding_view.dart';
import '../../features/auth/views/registration_completed_view.dart';
import '../../features/auth/views/splash_view.dart';
import '../../features/profile/views/profile_completion_view.dart';
import '../../features/registration/finalizing_view.dart';
import '../../features/registration/steps/step01_account_for.dart';
import '../../features/registration/steps/step02_basic_info.dart';
import '../../features/registration/steps/step03_religion_language.dart';
import '../../features/registration/steps/step04_location.dart';
import '../../features/registration/steps/step05_contact.dart';
import '../../features/registration/steps/step06_caste.dart';
import '../../features/registration/steps/step07_marital_status.dart';
import '../../features/registration/steps/step08_education.dart';
import '../../features/registration/steps/step09_physical.dart';
import '../../features/registration/steps/step10_career.dart';
import '../../features/registration/steps/step11_security.dart';
import '../../features/registration/steps/step12_photos.dart';
import '../../features/registration/steps/step13_about.dart';
import '../../features/registration/steps/step14_verification.dart';
import '../../features/registration/steps/step15_interests.dart';
import '../../features/registration/steps/step16_family_info.dart';
import '../../features/registration/steps/step17_family_details.dart';
import '../../features/registration/steps/step18_partner.dart';
import 'app_routes.dart';

/// GetX page table. Controllers are created/disposed by their own views
/// (no Bindings), so no `binding:` is used here.
///
/// Every route gets the shared bottom-to-top bounce transition
/// ([BounceUpPageTransition]) applied centrally below — no need to repeat it on
/// each page. `customTransition` is the highest-priority transition in GetX, so
/// it overrides the app's `defaultTransition` for all pushes.
class AppPages {
  const AppPages._();

  /// One shared bounce transition instance applied to every route.
  static final BounceUpPageTransition _bounce = BounceUpPageTransition();

  /// Builds a route with the shared bottom-to-top bounce transition, so no
  /// screen has to opt in individually.
  static GetPage<dynamic> _page(String name, GetPageBuilder page) {
    return GetPage<dynamic>(
      name: name,
      page: page,
      customTransition: _bounce,
      transitionDuration: BounceMotion.duration,
    );
  }

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    _page(AppRoutes.splash, () => const SplashView()),
    _page(AppRoutes.onboarding, () => const OnboardingView()),
    _page(AppRoutes.login, () => const LoginView()),
    _page(AppRoutes.forgotPassword, () => const ForgotPasswordView()),

    // Registration steps 1..18.
    _page(AppRoutes.accountFor, () => const Step01View()),
    _page(AppRoutes.basicInfo, () => const Step02View()),
    _page(AppRoutes.religionLanguage, () => const Step03View()),
    _page(AppRoutes.location, () => const Step04View()),
    _page(AppRoutes.contact, () => const Step05View()),
    _page(AppRoutes.caste, () => const Step06View()),
    _page(AppRoutes.maritalStatus, () => const Step07View()),
    _page(AppRoutes.education, () => const Step08View()),
    _page(AppRoutes.physical, () => const Step09View()),
    _page(AppRoutes.career, () => const Step10View()),
    _page(AppRoutes.security, () => const Step11View()),
    _page(AppRoutes.photos, () => const Step12View()),
    _page(AppRoutes.about, () => const Step13View()),
    _page(AppRoutes.verification, () => const Step14View()),
    _page(AppRoutes.interests, () => const Step15View()),
    _page(AppRoutes.familyInfo, () => const Step16View()),
    _page(AppRoutes.familyDetails, () => const Step17View()),
    _page(AppRoutes.partnerPreferences, () => const Step18View()),

    _page(AppRoutes.finalizing, () => const FinalizingView()),
    _page(AppRoutes.registrationCompleted, () => const RegistrationCompletedView()),
    _page(AppRoutes.home, () => const HomeView()),
    _page(AppRoutes.profileCompletion, () => const ProfileCompletionView()),
  ];
}
