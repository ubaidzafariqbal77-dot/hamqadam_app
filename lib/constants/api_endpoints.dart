/// Centralised list of every API endpoint used by the app.
///
/// Paths are relative to [ApiConfig.baseUrl] (which already ends in `/api/v1`).
class ApiEndpoints {
  const ApiEndpoints._();

  // ---- Auth -----------------------------------------------------------------
  static const String register = '/auth/register'; // step 1
  static const String loginEmail = '/auth/login/email';
  static const String requestMobileOtp = '/auth/otp/mobile';
  static const String loginMobile = '/auth/login/mobile';
  static const String loginGoogle = '/auth/login/google';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String deleteAccount = '/auth/account';

  // ---- Step-wise registration ----------------------------------------------
  static const String registerStatus = '/auth/register/status';

  /// Steps 2..10 follow the `/auth/register/stepN` pattern.
  static String registerStep(int step) => '/auth/register/step$step';

  // ---- Verification (step 11) -----------------------------------------------
  static const String verificationCurrent = '/verification/current';
  static const String verificationHistory = '/verification/history';
  static const String verificationSubmit = '/verification/submit';

  // ---- Profile / Privacy (step 12) ------------------------------------------
  static const String profile = '/profile';
  static const String profilePrivacy = '/profile/privacy';
  static const String profileVisibility = '/profile/visibility';

  // ---- Lookups (not officially documented — see LookupRepository) -----------
  // The app tries these conventional endpoints first and falls back to bundled
  // data when the backend returns 404/redirect. Keep them centralised so a
  // future backend rollout is a one-line change.
  static const String lookupBase = '/lookups';
  static String lookup(String key) => '$lookupBase/$key';
}
