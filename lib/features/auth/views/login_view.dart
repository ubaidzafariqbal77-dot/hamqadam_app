import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/login_controller.dart';
import '../../../controllers/mobile_otp_controller.dart';
import '../../../controllers/registration_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/view_controller_mixin.dart';
import '../../../core/validators/app_validators.dart';
import '../../../repositories/auth_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/app_otp_field.dart';
import '../../../widgets/app_password_field.dart';
import '../../../widgets/app_phone_field.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/dismiss_keyboard.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../widgets/reveal.dart';

/// Premium login screen with Email and Mobile-OTP methods + Google.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with ViewController<LoginView> {
  late final LoginController c;
  late final MobileOtpController otp;
  final RxBool _emailMode = true.obs;

  @override
  void initState() {
    super.initState();
    c = putVC<LoginController>(
      LoginController(
        authRepository: Get.find<AuthRepository>(),
        authController: Get.find<AuthController>(),
      ),
    );
    otp = putVC<MobileOtpController>(
      MobileOtpController(
        authRepository: Get.find<AuthRepository>(),
        authController: Get.find<AuthController>(),
      ),
    );
  }

  @override
  void dispose() {
    deleteVC<LoginController>();
    deleteVC<MobileOtpController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DismissKeyboard(
      child: Obx(
        () => LoadingOverlay(
          isLoading: c.submitting.value || otp.submitting.value,
          child: Scaffold(
            // Login is fully English-only: the whole subtree (including the
            // email/password/phone fields) has bilingual Urdu disabled.
            body: UrduScope(
              enabled: false,
              child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                const _LoginHeader(),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _MethodToggle(emailMode: _emailMode),
                      const SizedBox(height: AppSpacing.lg),
                      Obx(() => _emailMode.value ? _emailForm() : _mobileForm()),
                      const SizedBox(height: AppSpacing.lg),
                      const _OrDivider(),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'With Google',
                        variant: AppButtonVariant.outline,
                        icon: Icons.g_mobiledata_rounded,
                        onPressed: _google,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _CreateAccountRow(),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Email form -----------------------------------------------------------
  Widget _emailForm() {
    return Form(
      key: c.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Obx(() => c.generalError.value.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ErrorBanner(message: c.generalError.value),
                )),
          Reveal(
            child: UrduScope(
              enabled: false,
              child: Obx(() => AppTextFormField(
                    label: AppStrings.email,
                    controller: c.emailCtrl,
                    focusNode: c.emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(Icons.email_outlined),
                    autofillHints: const <String>[AutofillHints.email],
                    serverError: c.serverErrors['email'],
                    onChanged: (_) => c.clearServerError('email'),
                    onSubmitted: (_) => c.passwordFocus.requestFocus(),
                    validator: (String? v) => AppValidators.email(v),
                  )),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Reveal(
            delayMs: 90,
            child: UrduScope(
              enabled: false,
              child: Obx(() => AppPasswordField(
                    label: AppStrings.password,
                    controller: c.passwordCtrl,
                    focusNode: c.passwordFocus,
                    textInputAction: TextInputAction.done,
                    serverError: c.serverErrors['password'],
                    onChanged: (_) => c.clearServerError('password'),
                    onSubmitted: (_) => c.submit(),
                    validator: (String? v) => AppValidators.required(v, field: 'Password'),
                  )),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: BiText.inline(
                AppStrings.forgotPassword,
                style: AppTextStyles.label.copyWith(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(label: AppStrings.login, loading: c.submitting.value, onPressed: c.submit),
        ],
      ),
    );
  }

  // ---- Mobile OTP form ------------------------------------------------------
  Widget _mobileForm() {
    return Form(
      key: otp.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Obx(() => otp.generalError.value.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ErrorBanner(message: otp.generalError.value),
                )),
          Reveal(
            child: UrduScope(
              enabled: false,
              child: AppPhoneField(
                label: 'Mobile number',
                controller: otp.phoneCtrl,
                validator: (String? v) => AppValidators.pakistaniPhone(v),
              ),
            ),
          ),
          Obx(() {
            if (!otp.otpRequested.value) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: AppButton(
                  label: 'Send OTP',
                  loading: otp.submitting.value,
                  onPressed: otp.requestOtp,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                AppOtpField(label: 'OTP code', controller: otp.otpCtrl),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Verify & Login',
                  loading: otp.submitting.value,
                  onPressed: otp.verifyOtp,
                ),
                TextButton(
                  onPressed: otp.reset,
                  child: BiText(
                    'Change number / resend',
                    gap: 0,
                    style: AppTextStyles.label.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _google() {
    // The Google ID-token flow is wired in AuthRepository.loginWithGoogle().
    // Enabling it requires a Google OAuth client (serverClientId) +
    // google-services.json, which must be configured first.
    AppSnackbar.info('Google Sign-In will be enabled after Google OAuth setup.');
  }

  void _forgotPassword() {
    // Opens the dedicated forgot/reset password screen (email → OTP → new password).
    Get.toNamed(AppRoutes.forgotPassword);
  }
}

class _MethodToggle extends StatelessWidget {
  const _MethodToggle({required this.emailMode});
  final RxBool emailMode;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool email = emailMode.value;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: <Widget>[
            _seg(context, 'Email', email, () => emailMode.value = true),
            _seg(context, 'Mobile OTP', !email, () => emailMode.value = false),
          ],
        ),
      );
    });
  }

  Widget _seg(BuildContext context, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: AppRadius.smAll,
          ),
          alignment: Alignment.center,
          child: BiText(
            label,
            textAlign: TextAlign.center,
            gap: 0,
            style: AppTextStyles.label.copyWith(
              color: active ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
            ),
            urduColor: active ? Colors.white.withValues(alpha: 0.9) : null,
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: BiText.inline('or', style: AppTextStyles.caption.copyWith(fontSize: 12)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.xxl,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.xxl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BiText(
            AppStrings.loginTitle,
            style: AppTextStyles.display.copyWith(color: Colors.white),
            urduColor: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 4),
          BiText(
            AppStrings.loginSubtitle,
            style: AppTextStyles.body.copyWith(color: Colors.white70),
            urduColor: Colors.white70,
          ),
        ],
      ),
    );
  }
}

class _CreateAccountRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        BiText.inline(
          AppStrings.noAccount,
          style: AppTextStyles.body
              .copyWith(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13.5),
        ),
        TextButton(
          onPressed: () async {
            // Start a fresh registration from step 1 (drops any old draft and
            // the previous profile-completion record).
            //
            // Awaited on purpose: the reset also drops the cached lookup lists,
            // and navigating first let step 1 read the still-warm cache, run
            // its `ensure`, and only then have the lists wiped underneath it —
            // leaving the "Account for" cards on a spinner with nobody left to
            // ask for them again.
            await Get.find<RegistrationController>().resetForNewAccount();
            Get.toNamed(AppRoutes.accountFor);
          },
          child: BiText.inline(
            AppStrings.createAccount,
            style: AppTextStyles.label.copyWith(color: AppColors.primary, fontSize: 13.5),
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
