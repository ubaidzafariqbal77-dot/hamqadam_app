import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/routes/app_routes.dart';

/// The Login / Create Account hand-off dialog (reference: "Login to View
/// Full Profile").
///
/// Shown from the onboarding hand-off page and from the "Proposals for you"
/// preview — anywhere a first-time visitor is asked how they want to continue.
/// Tapping outside, the ✕, or "Continue as guest?" all dismiss it.
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
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
                // ---- Heart logo mark ------------------------------
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFE5728F),
                  size: 56,
                ),
                const SizedBox(height: AppSpacing.md),

                // ---- Title + subtitle ------------------------------
                Text(
                  'Login to View Full Profile',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1B1B1B),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Please log in or create account to see full details and contact team on WhatsApp',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.lightTextSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ---- Actions: Log in first, Create Account second ---
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onLogin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Log in',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onCreateAccount,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFFE5728F),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Create Account',
                      style: AppTextStyles.button.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ---- Guest link ------------------------------------
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Text.rich(
                    TextSpan(
                      text: 'Continue as guest? ',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      children: <InlineSpan>[
                        TextSpan(
                          text: 'limited view',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.lightTextSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---- Close button (top-right, overlapping card corner) ------
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(
                    Icons.close_rounded,
                    size: 19,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
