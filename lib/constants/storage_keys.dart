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

  // Non-sensitive (SharedPreferences)
  static const String currentUser = 'hq_current_user'; // full user JSON
  static const String registrationDraftPrefix = 'hq_reg_draft_';
  static const String lastKnownNextStep = 'hq_reg_next_step';
  static const String lookupCachePrefix = 'hq_lookup_';
  static const String themeMode = 'hq_theme_mode';
  static const String onboardingSeen = 'hq_onboarding_seen';
}
