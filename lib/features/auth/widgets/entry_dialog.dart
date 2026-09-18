import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/routes/app_routes.dart';
import '../../../widgets/app_button.dart';

/// The Create Account / Login hand-off dialog (reference screen 5).
///
/// Shown from the onboarding hand-off page and from the "Proposals for you"
/// preview — anywhere a first-time visitor is asked how they want to continue.
/// Tapping outside dismisses it.
class EntryDialog extends StatelessWidget {
  const EntryDialog({
    super.key,
    required this.onCreateAccount,
    required this.onLogin,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  /// Convenience for showing the dialog above the current route. Both actions
  /// follow the standard first-run flow: pop the dialog, then replace the
  /// whole stack (the preview/onboarding behind it is never worth going back
  /// to once the visitor has chosen).
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xFF5E2A44).withValues(alpha: 0.35),
      builder: (BuildContext dialogContext) {
        return Center(
          child: EntryDialog(
            onCreateAccount: () {
              Navigator.of(dialogContext).pop();
              Get.offAllNamed<dynamic>(AppRoutes.accountFor);
            },
            onLogin: () {
              Navigator.of(dialogContext).pop();
              Get.offAllNamed<dynamic>(AppRoutes.login);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.78),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFB4487B).withValues(alpha: 0.22),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Logo mark.
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/icons/logo.png',
                    width: 78,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.primary,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Welcome to ${AppStrings.appName}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A respectful path to marriage. How would you like to continue?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.lightTextSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Create Account',
                  icon: Icons.favorite_rounded,
                  onPressed: onCreateAccount,
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onLogin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Login',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
