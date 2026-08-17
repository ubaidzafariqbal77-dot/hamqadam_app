/// Centralised list of every API endpoint used by the app.
///
/// Paths are relative to [ApiConfig.baseUrl] (which already ends in `/api/v1`).
class ApiEndpoints {
  const ApiEndpoints._();

  // ---- Auth -----------------------------------------------------------------
  static const String register = '/auth/register'; // legacy full-payload signup
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

  // ---- Registration (single complete submission + email OTP) ----------------
  /// The whole 18-step payload in ONE `multipart/form-data` request. Public:
  /// it creates the draft account and returns the Sanctum token.
  static const String registerComplete = '/auth/register/complete';

  /// Emails a verification code to the freshly registered account (bearer).
  static const String registerRequestOtp = '/auth/register/request-otp';

  /// Confirms that code and finalises the registration (bearer).
  static const String registerVerifyOtp = '/auth/register/verify-otp';

  // ---- Step-wise registration (deprecated, kept for section edits) ----------
  /// Metadata for the whole flow (`GET`).
  static const String registerSteps = '/auth/register/steps';

  /// Server-authoritative progress (`GET`).
  static const String registerStatus = '/auth/register/status';

  /// The public legacy step 1 (creates a draft member). The app no longer calls
  /// it — registration goes through [registerComplete].
  static const String registerStep1 = '/auth/register/step1';

  /// Authenticated per-step save, used to re-save one profile section after
  /// signup. Step 1 uses this form too, so editing a section can never create a
  /// second account.
  static String registerStep(int step) => '/auth/register/step/$step';

  // ---- Verification ---------------------------------------------------------
  static const String verificationCurrent = '/verification/current';
  static const String verificationHistory = '/verification/history';
  static const String verificationSubmit = '/verification/submit';

  // ---- Profile / Privacy ----------------------------------------------------
  static const String profile = '/profile';
  static const String profilePrivacy = '/profile/privacy';
  static const String profileVisibility = '/profile/visibility';

  // ---- Dropdowns ------------------------------------------------------------
  /// Single endpoint that returns EVERY dropdown list (dynamic + hardcoded).
  static const String dropdownReferenceData = '/profile/dropdown-reference-data';
}
