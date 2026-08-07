import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/forgot_password_controller.dart';
import '../../../core/utils/view_controller_mixin.dart';
import '../../../repositories/auth_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/app_otp_field.dart';
import '../../../widgets/app_password_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/dismiss_keyboard.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../widgets/premium_app_bar.dart';

/// Forgot / reset password screen: enter email → receive OTP → set new password.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView>
    with ViewController<ForgotPasswordView> {
  late final ForgotPasswordController c;

  @override
  void initState() {
    super.initState();
    c = putVC<ForgotPasswordController>(
      ForgotPasswordController(Get.find<AuthRepository>()),
    );
  }

  @override
  void dispose() {
    deleteVC<ForgotPasswordController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DismissKeyboard(
      child: Obx(
        () => LoadingOverlay(
          isLoading: c.submitting.value,
          // Forgot-password screen is English-only (no Urdu line).
          child: UrduScope(
            enabled: false,
            child: Scaffold(
            appBar: const PremiumAppBar(title: 'Reset password'),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                _Header(otpSent: c.otpSent.value),
                const SizedBox(height: AppSpacing.lg),
                Obx(() => c.generalError.value.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ErrorBanner(message: c.generalError.value),
                      )),
                Obx(() => c.otpSent.value ? _resetStage() : _emailStage()),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  // Stage 1 — email
  Widget _emailStage() {
    return Form(
      key: c.emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextFormField(
            label: AppStrings.email,
            controller: c.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: c.validateEmail,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Send OTP', loading: c.submitting.value, onPressed: c.requestOtp),
        ],
      ),
    );
  }

  // Stage 2 — OTP + new password
  Widget _resetStage() {
    return Form(
      key: c.resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppOtpField(label: 'OTP code', controller: c.otpCtrl),
          const SizedBox(height: AppSpacing.md),
          AppPasswordField(
            label: 'New password',
            controller: c.passwordCtrl,
            validator: c.validatePassword,
          ),
          const SizedBox(height: AppSpacing.md),
          AppPasswordField(
            label: 'Confirm new password',
            controller: c.confirmCtrl,
            validator: c.validateConfirm,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Reset password',
            loading: c.submitting.value,
            onPressed: c.resetPassword,
          ),
          TextButton(
            onPressed: c.changeEmail,
            child: BiText(
              'Change email / resend OTP',
              gap: 0,
              style: AppTextStyles.label.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.otpSent});
  final bool otpSent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            otpSent ? Icons.lock_reset_rounded : Icons.mark_email_read_outlined,
            color: AppColors.primary,
            size: AppDimensions.iconLg,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        BiText(
          otpSent ? 'Enter OTP & new password' : 'Forgot your password?',
          style: AppTextStyles.headline,
        ),
        const SizedBox(height: 4),
        BiText(
          otpSent
              ? 'We sent a one-time code to your email. Enter it with your new password.'
              : 'Enter your registered email and we will send you an OTP to reset your password.',
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(message, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
