import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/storage/profile_completion_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/bilingual_text.dart';

/// Shown once the buffered profile has been submitted successfully.
class RegistrationCompletedView extends StatelessWidget {
  const RegistrationCompletedView({super.key});

  ProfileCompletionService get _completion => Get.find<ProfileCompletionService>();
  int get _pending => _completion.pendingCount;
  int get _percent => _completion.percent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.brandGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 72),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppStrings.registrationCompleteTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.registrationCompleteMessage,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: Colors.white70),
                ),
                if (_pending > 0) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _SkippedNote(percent: _percent),
                ],
                const Spacer(),
                AppButton(
                  label: 'Explore HamQadam',
                  variant: AppButtonVariant.primary,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => Get.offAllNamed(AppRoutes.home),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells the user what they skipped and where to finish it later.
class _SkippedNote extends StatelessWidget {
  const _SkippedNote({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'Your profile is $percent% complete',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          BiText(
            'You skipped some sections. You can complete them anytime from your profile.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: Colors.white70),
            urduColor: Colors.white70,
          ),
        ],
      ),
    );
  }
}
