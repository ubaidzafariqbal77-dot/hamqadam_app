import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../core/services/biometric_auth_service.dart';
import '../core/utils/app_logger.dart';

/// After a successful password login, offers to remember the member for
/// fingerprint login next time. Shown only when the device can do biometrics
/// and the member has not opted in before (and has not dismissed with
/// "Not now" — that choice is remembered as '0' so the popup never nags).
class BiometricOptInDialog extends StatelessWidget {
  const BiometricOptInDialog({
    super.key,
    required this.service,
    required this.email,
    required this.password,
  });

  final BiometricAuthService service;
  final String email;
  final String password;

  static const String _dismissedKey = 'hq_biometric_dismissed';

  /// Returns true when the member enabled fingerprint login.
  static Future<bool> maybeShow({
    required BiometricAuthService service,
    required String email,
    required String password,
  }) async {
    if (!await service.canUse()) return false;
    if (await service.isEnabled()) return false;

    // The member answered "Not now" on a previous login — never ask again.
    final String? dismissed = await service.storage.readString(_dismissedKey);
    if (dismissed == '0') return false;

    final bool? enabled = await Get.dialog<bool>(
      BiometricOptInDialog(service: service, email: email, password: password),
      barrierDismissible: false,
    );
    return enabled ?? false;
  }

  /// Lets the member change their mind later (used after a "Not now").
  static Future<void> clearDismissed(BiometricAuthService service) =>
      service.storage.delete(_dismissedKey);

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: AppRadius.xlAll,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 16),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Fingerprint medallion.
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: AppColors.brandGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Enable Fingerprint Login?', textAlign: TextAlign.center, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Next time, log in instantly with your fingerprint — no typing your email and password again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).hintColor,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      // Remember the "Not now" so this popup stops appearing.
                      try {
                        await service.storage.writeString(_dismissedKey, '0');
                      } catch (e) {
                        AppLogger.w('biometric dismiss flag failed: $e');
                      }
                      if (context.mounted) Navigator.of(context).pop(false);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: dark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Text('Not now', style: AppTextStyles.label),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await service.enable(email: email, password: password);
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (e) {
                        AppLogger.w('biometric enable failed: $e');
                        if (context.mounted) Navigator.of(context).pop(false);
                      }
                    },
                    child: const Text('Enable'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
