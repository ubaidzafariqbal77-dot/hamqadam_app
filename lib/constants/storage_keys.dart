/// Keys for secure storage and non-sensitive shared preferences.
///
/// Anything under [secure*] is stored via flutter_secure_storage. Draft data
/// stored in SharedPreferences must never contain passwords, tokens or
/// identity documents.
class StorageKeys {
  const StorageKeys._();

  // Secure (flutter_secure_storage)
  static const String authToken = 'hq_auth_token';
  static const String authUser = 'hq_auth_user';

  // Fingerprint login: the member's saved email/password, re-encrypted at rest
  // by the OS keychain/keystore, plus the flag that says they opted in.
  static const String biometricEmail = 'hq_biometric_email';
  static const String biometricPassword = 'hq_biometric_password';
  static const String biometricEnabled = 'hq_biometric_enabled';

  // Non-sensitive (SharedPreferences)
  static const String currentUser = 'hq_current_user'; // full user JSON
  static const String registrationDraftPrefix = 'hq_reg_draft_';
  static const String lastKnownNextStep = 'hq_reg_next_step';
  static const String lookupCachePrefix = 'hq_lookup_';
  static const String onboardingSeen = 'hq_onboarding_seen';
}
