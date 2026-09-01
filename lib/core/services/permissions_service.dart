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
