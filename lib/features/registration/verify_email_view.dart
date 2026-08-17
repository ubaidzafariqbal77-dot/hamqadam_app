import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../controllers/verify_email_controller.dart';
import '../../core/validators/app_validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_otp_field.dart';
import '../../widgets/app_text_form_field.dart';
import '../../widgets/bilingual_text.dart';
import '../../widgets/dismiss_keyboard.dart';

/// Final signup screen: confirm the code emailed by
/// `POST /auth/register/request-otp` so `verify-otp` can activate the account.
///
/// Reached from the finalizing screen and re-opened on launch while the account
/// is registered but unverified, so a closed app never strands the user.
class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key, this.codeAlreadySent = false});

  final bool codeAlreadySent;

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  late final VerifyEmailController c;

  @override
  void initState() {
    super.initState();
    final bool sent = widget.codeAlreadySent || (Get.arguments is Map<String, dynamic>
        ? (Get.arguments as Map<String, dynamic>)['codeAlreadySent'] == true
        : false);
    c = Get.put(VerifyEmailController(codeAlreadySent: sent));
  }

  @override
  void dispose() {
    Get.delete<VerifyEmailController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Verification is the last mandatory step — leaving it by the back button
    // would drop the user into an unverified account.
    return PopScope(
      canPop: false,
      child: DismissKeyboard(
        child: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppColors.primary,
                    size: AppDimensions.iconLg,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                BiText('Verify your email', style: AppTextStyles.display),
                const SizedBox(height: AppSpacing.xs),
                Obx(
                  () => Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        const TextSpan(text: 'We sent a 6-digit code to '),
                        TextSpan(
                          text: c.email.value.isEmpty ? 'your email address' : c.email.value,
                          style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
                        ),
                        const TextSpan(text: '. Enter it below to activate your account.'),
                      ],
                    ),
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppOtpField(
                  label: 'Verification code',
                  controller: c.codeCtrl,
                  length: VerifyEmailController.codeLength,
                  onCompleted: (_) => c.verify(),
                ),
                const SizedBox(height: AppSpacing.md),
                Obx(
                  () => c.error.value.isEmpty
                      ? const SizedBox.shrink()
                      : _ErrorBanner(message: c.error.value),
                ),
                const SizedBox(height: AppSpacing.lg),
                Obx(
                  () => AppButton(
                    label: 'Verify & continue',
                    loading: c.verifying.value,
                    onPressed: c.verify,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Obx(() {
                  final int wait = c.resendIn.value;
                  return TextButton(
                    onPressed: c.canResend ? c.sendCode : null,
                    child: Text(
                      wait > 0 ? 'Resend code in ${wait}s' : 'Resend code',
                      style: AppTextStyles.label.copyWith(
                        color: c.canResend
                            ? AppColors.primary
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Check your spam folder if the email has not arrived within a '
                  'minute.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Wrong address, or already registered?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _promptChangeEmail(context, c),
                  icon: const Icon(Icons.alternate_email_rounded,
                      size: 18, color: AppColors.primary),
                  label: Text(
                    'Use a different email',
                    style: AppTextStyles.label.copyWith(color: AppColors.primary),
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

/// Lets the user move the account to another address and get a fresh code —
/// the way out of "Email is already verified" / a typo'd address, without
/// abandoning the 18 steps already submitted.
Future<void> _promptChangeEmail(BuildContext context, VerifyEmailController c) async {
  c.newEmailCtrl.text = c.email.value;
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Use a different email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'We will send a new code to this address and your account will use '
            'it from now on.',
            style: AppTextStyles.caption.copyWith(
              color: Theme.of(ctx).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextFormField(
            label: 'New email address',
            controller: c.newEmailCtrl,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: (String? v) => AppValidators.email(v),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Send code'),
        ),
      ],
    ),
  );
  if (confirmed == true) await c.changeEmail();
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
