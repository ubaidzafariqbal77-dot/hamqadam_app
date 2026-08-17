/// Named routes for the whole app.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  // ---- Registration steps 1..18 (see product document) ----------------------
  static const String accountFor = '/register/account-for'; // 1
  static const String basicInfo = '/register/basic-info'; // 2
  static const String religionLanguage = '/register/religion-language'; // 3
  static const String location = '/register/location'; // 4
  static const String contact = '/register/contact'; // 5
  static const String caste = '/register/caste'; // 6
  static const String maritalStatus = '/register/marital-status'; // 7
  static const String education = '/register/education'; // 8
  static const String physical = '/register/physical'; // 9
  static const String career = '/register/career'; // 10
  static const String security = '/register/security'; // 11 (creates account)
  static const String photos = '/register/photos'; // 12
  static const String about = '/register/about'; // 13
  static const String verification = '/register/verification'; // 14
  static const String interests = '/register/interests'; // 15 (optional)
  static const String familyInfo = '/register/family-info'; // 16 (optional)
  static const String familyDetails = '/register/family-details'; // 17 (optional)
  static const String partnerPreferences = '/register/partner'; // 18

  static const String finalizing = '/register/finalizing';

  /// Email OTP screen shown after the single `register/complete` submission.
  static const String verifyEmail = '/register/verify-email';

  static const String registrationCompleted = '/register/completed';
  static const String home = '/home';

  /// "Complete your profile" — hub for the sections skipped during signup.
  static const String profileCompletion = '/profile/completion';

  /// step number (1-based) -> route.
  static const List<String> stepRoutes = <String>[
    accountFor, // 1
    basicInfo, // 2
    religionLanguage, // 3
    location, // 4
    contact, // 5
    caste, // 6
    maritalStatus, // 7
    education, // 8
    physical, // 9
    career, // 10
    security, // 11
    photos, // 12
    about, // 13
    verification, // 14
    interests, // 15
    familyInfo, // 16
    familyDetails, // 17
    partnerPreferences, // 18
  ];

  static String routeForStep(int step) {
    if (step < 1 || step > stepRoutes.length) return accountFor;
    return stepRoutes[step - 1];
  }
}
