import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/app_logger.dart';

/// Requests all required permissions at app startup so the user is never
/// prompted mid-action. Permissions that are already granted are skipped.
///
/// Order matters: notification permission is requested first (Android 13+)
/// because it's the least intrusive; camera/microphone come next because
/// they're needed for calls and profile features.
class PermissionsService {
  const PermissionsService._();
  static final PermissionsService instance = PermissionsService._();

  /// Requests all permissions the app needs. Safe to call multiple times —
  /// already-granted permissions are no-ops.
  Future<void> requestAll() async {
    try {
      // 1. Notifications (Android 13+, iOS) — request first so tray works
      await _requestIfNeeded(Permission.notification);

      // 2. Camera (profile photos, video calls, verification)
      await _requestIfNeeded(Permission.camera);

      // 3. Microphone (audio/video calls)
      await _requestIfNeeded(Permission.microphone);

      // 4. Photos / Storage (profile photos, gallery)
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android 13+: granular media permissions
        await _requestIfNeeded(Permission.photos);
        await _requestIfNeeded(Permission.videos);
      } else {
        // iOS: single photo library permission
        await _requestIfNeeded(Permission.photos);
      }

      // 5. Contacts (find people you know)
      await _requestIfNeeded(Permission.contacts);

      AppLogger.i('✅ All startup permissions requested');
    } catch (e) {
      AppLogger.w('Permission request error: $e');
    }
  }

  /// Asks Android to stop battery-optimising this app.
  ///
  /// ## Why a calling app needs this
  ///
  /// Measured on an Infinix X6853 (Android 15) on 2026-09-02: pushes arrive
  /// with the app in the foreground, in the background, and even after the
  /// process has been killed — but **not** once the app has been
  /// *force-stopped*, which is a different state:
  ///
  /// ```
  /// reason=10 (USER REQUESTED) subreason=21 (FORCE STOP)
  /// Killing …:com.app.hamqadam (adj 400): stop com.app.hamqadam due to from pid 24719
  /// ```
  ///
  /// A force-stopped app carries `FLAG_STOPPED`, and Android delivers it no
  /// broadcasts at all — FCM included — until the member opens it again. No
  /// amount of client or server code changes that. What did the force-stopping
  /// was the OEM cleaner (`com.transsion.phonemaster`), and being off the
  /// battery-optimisation list is what invites it.
  ///
  /// Asked once, and only after there is a session, so it is not the first
  /// thing a new member sees. `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is
  /// declared in the manifest for it; Google's policy allows it for apps whose
  /// core function is calling, which this is.
  Future<void> requestCallReliability({required bool alreadyAsked}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final PermissionStatus status =
          await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) {
        AppLogger.i('Battery optimisation already disabled for this app.');
        return;
      }
      if (alreadyAsked) {
        AppLogger.i(
          'Battery optimisation is on and the member has already been asked '
          'once; not prompting again. Calls may be missed after the OEM '
          'cleaner force-stops the app.',
        );
        return;
      }

      final PermissionStatus result =
          await Permission.ignoreBatteryOptimizations.request();
      AppLogger.i('Battery optimisation exemption result: $result');
    } catch (e) {
      // Some OEMs have no such dialog; nothing to fall back to from here.
      AppLogger.w('Could not request the battery-optimisation exemption: $e');
    }
  }

  /// Whether Android is still allowed to battery-optimise (and therefore
  /// force-stop) this app. The UI can use this to explain missed calls.
  Future<bool> get isBatteryOptimised async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return !(await Permission.ignoreBatteryOptimizations.status).isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Requests a single permission if it's not already granted.
  Future<void> _requestIfNeeded(Permission permission) async {
    final PermissionStatus status = await permission.status;
    if (status.isGranted || status.isLimited) return;

    final PermissionStatus result = await permission.request();
    if (result.isGranted || result.isLimited) {
      AppLogger.d('✅ ${permission.toString()} granted');
    } else if (result.isPermanentlyDenied) {
      AppLogger.w('⚠️ ${permission.toString()} permanently denied — user must enable in Settings');
    } else {
      AppLogger.d('⏭️ ${permission.toString()} denied (non-permanent)');
    }
  }
}
