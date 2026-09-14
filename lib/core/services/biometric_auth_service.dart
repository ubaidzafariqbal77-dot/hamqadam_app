import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import '../../constants/app_strings.dart';
import '../../constants/storage_keys.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';

/// Fingerprint / Face unlock login.
///
/// When a member opts in after a successful password login, their email and
/// password are stored in the OS-protected keychain/keystore
/// ([flutter_secure_storage] — encrypted at rest, never in plain
/// SharedPreferences). On the next launch, tapping "Fingerprint login" (or
/// tapping the fingerprint card on the login screen) shows the system
/// BiometricPrompt; on success the stored credentials are replayed through the
/// normal login API, so a fresh Sanctum token is issued — the old token is
/// never persisted for reuse.
///
/// Device-side security notes:
/// - [canUse] is false when the device has no biometric hardware, none is
///   enrolled, or there is no device credential fallback.
/// - The stored password is cleared on logout / logout-all / deactivation, and
///   when Android reports the biometric enrollment changed
///   (Keystore invalidation), the prompt simply fails and the member falls
///   back to typing their password.
class BiometricAuthService {
  BiometricAuthService({required this.storage, LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final SecureStorageService storage;
  final LocalAuthentication _localAuth;

  /// Whether fingerprint login can be offered on this device right now.
  Future<bool> canUse() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      final List<BiometricType> available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (e) {
      AppLogger.w('biometric capability check failed: $e');
      return false;
    }
  }

  /// Whether the member has opted in and saved credentials exist.
  Future<bool> isEnabled() async {
    try {
      final String? flag = await storage.readString(StorageKeys.biometricEnabled);
      if (flag != '1') return false;
      final String? email = await storage.readString(StorageKeys.biometricEmail);
      final String? password = await storage.readString(
        StorageKeys.biometricPassword,
      );
      return (email ?? '').isNotEmpty && (password ?? '').isNotEmpty;
    } catch (e) {
      AppLogger.w('biometric flag read failed: $e');
      return false;
    }
  }

  /// Saves the member's credentials for future fingerprint logins.
  Future<void> enable({required String email, required String password}) async {
    await storage.writeString(StorageKeys.biometricEmail, email.trim());
    await storage.writeString(StorageKeys.biometricPassword, password);
    await storage.writeString(StorageKeys.biometricEnabled, '1');
  }

  /// Removes stored credentials (logout, logout-all, deactivate, or the member
  /// turning the feature down).
  Future<void> disable() async {
    await storage.delete(StorageKeys.biometricEmail);
    await storage.delete(StorageKeys.biometricPassword);
    await storage.delete(StorageKeys.biometricEnabled);
  }

  /// Shows the system biometric prompt purely to verify a live fingerprint
  /// (used when turning the feature on from the drawer). Returns true when the
  /// scan succeeds.
  Future<bool> verifyOnly() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Verify your fingerprint to enable fingerprint login',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            biometricHint: '',
            cancelButton: 'Cancel',
            signInTitle: 'Verify it\'s you',
          ),
          IOSAuthMessages(cancelButton: 'Cancel'),
        ],
      );
    } catch (e) {
      AppLogger.w('biometric verify failed: $e');
      return false;
    }
  }

  /// Shows the system biometric prompt and returns the saved credentials on
  /// success, or null when the member cancelled / failed / nothing is saved.
  Future<({String email, String password})?> authenticate() async {
    if (!await isEnabled()) return null;
    try {
      final bool ok = await _localAuth.authenticate(
        localizedReason: 'Fingerprint se login karein — ${AppStrings.appName}',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            biometricHint: '',
            cancelButton: 'Cancel',
            goToSettingsButton: 'Settings',
            signInTitle: 'Verify it\'s you',
            biometricRequiredTitle: 'Fingerprint required',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
            lockOut: 'Try again later.',
          ),
        ],
      );
      if (!ok) return null;

      final String? email = await storage.readString(StorageKeys.biometricEmail);
      final String? password = await storage.readString(
        StorageKeys.biometricPassword,
      );
      if ((email ?? '').isEmpty || (password ?? '').isEmpty) return null;
      return (email: email!, password: password!);
    } catch (e) {
      // Common when fingerprints were re-enrolled (Keystore invalidated).
      AppLogger.w('biometric auth failed: $e');
      return null;
    }
  }
}
