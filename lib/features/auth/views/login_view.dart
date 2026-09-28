import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/email_otp_controller.dart';
import '../../../controllers/login_controller.dart';
import '../../../controllers/registration_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/biometric_auth_service.dart';
import '../../../core/utils/view_controller_mixin.dart';
import '../../../core/validators/app_validators.dart';
import '../../../repositories/auth_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/app_otp_field.dart';
import '../../../widgets/app_password_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/dismiss_keyboard.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../widgets/reveal.dart';

/// Login screen wearing the registration flow's reference look: the dusty-rose
/// canvas, one floating white rounded card with the soft rose shadow, a serif
/// heading, and the muted rose buttons — the same chrome StepScaffold draws.
/// Only the styling moved; every controller, validator and handler is the one
/// the previous design used.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with ViewController<LoginView> {
  late final LoginController c;
  late final EmailOtpController emailOtp;

  /// 0 = Email & password, 1 = Email OTP. (Mobile OTP removed — QA decision:
  /// the member never got those SMS reliably, and email covers recovery.)
  final RxInt _emailMode = 0.obs;

  @override
  void initState() {
    super.initState();
    c = putVC<LoginController>(
      LoginController(
        authRepository: Get.find<AuthRepository>(),
        authController: Get.find<AuthController>(),
      ),
    );
    emailOtp = putVC<EmailOtpController>(
      EmailOtpController(
        authRepository: Get.find<AuthRepository>(),
        authController: Get.find<AuthController>(),
      ),
    );
  }

  @override
  void dispose() {
    deleteVC<LoginController>();
    deleteVC<EmailOtpController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DismissKeyboard(
      child: Obx(
        () => LoadingOverlay(
          isLoading:
              c.submitting.value || emailOtp.submitting.value,
          child: Scaffold(
            // Login is fully English-only: the whole subtree (including the
            // email/password/phone fields) has bilingual Urdu disabled.
            body: UrduScope(
              enabled: false,
              child: DecoratedBox(
                // White canvas — the app-wide white + hot-pink combination.
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white,
                      Color(0xFFFAFAFA),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      const _LoginHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, AppSpacing.md, 18, AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _MethodToggle(emailMode: _emailMode),
                            const SizedBox(height: AppSpacing.lg),
                            // The floating white card that holds the form —
                            // the same card the registration steps draw.
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: const Color(0xFFB4487B).withValues(alpha: 0.10),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Obx(() => switch (_emailMode.value) {
                                    1 => _emailOtpForm(),
                                    _ => _emailForm(),
                                  }),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const _OrDivider(),
                            const SizedBox(height: AppSpacing.md),
                            // Fingerprint login replaces the (never-enabled) Google
                            // button: one tap, system biometric prompt, straight in.
                            _FingerprintLoginButton(onPressed: c.loginWithBiometric),
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
                style: AppTextStyles.label.copyWith(
                    color: AppColors.primary, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(label: AppStrings.login, loading: c.submitting.value, onPressed: c.submit),
        ],
      ),
    );
  }

  // ---- Email OTP form (QA: backend email-OTP login) -------------------------
  Widget _emailOtpForm() {
    return Form(
      key: emailOtp.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Reveal(
            child: AppTextFormField(
              label: 'Registered Email',
              controller: emailOtp.emailCtrl,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.email_outlined),
              validator: (String? v) => AppValidators.email(v),
            ),
          ),
          Obx(() {
            if (!emailOtp.otpRequested.value) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: AppButton(
                  label: 'Send Code',
                  loading: emailOtp.submitting.value,
                  onPressed: emailOtp.requestOtp,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                AppOtpField(label: 'Verification code', controller: emailOtp.otpCtrl),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Verify & Login',
                  loading: emailOtp.submitting.value,
                  onPressed: emailOtp.verifyOtp,
                ),
                TextButton(
                  onPressed: emailOtp.reset,
                  child: BiText(
                    'Change email / resend code',
                    gap: 0,
                    style: AppTextStyles.label.copyWith(color: AppColors.regAccent),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _forgotPassword() {
    // Opens the dedicated forgot/reset password screen (email → OTP → new password).
    Get.toNamed(AppRoutes.forgotPassword);
  }
}

class _MethodToggle extends StatelessWidget {
  const _MethodToggle({required this.emailMode});

  /// 0 = Email & password, 1 = Email OTP (QA-required recovery login).
  final RxInt emailMode;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // The reference's segmented look: white track, pink hairline, and the
      // active segment filled with the soul-pink gradient.
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.roseFieldBorder),
        ),
        child: Row(
          children: <Widget>[
            _seg(context, 'Email', emailMode.value == 0,
                () => emailMode.value = 0),
            _seg(context, 'Email OTP', emailMode.value == 1,
                () => emailMode.value = 1),
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
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            // The reference toggle's active segment: the soul-pink gradient
            // (135° hot pink), the app's new brand voice.
            gradient: active
                ? const LinearGradient(
                    colors: AppColors.brandGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: active ? null : Colors.transparent,
            borderRadius: AppRadius.smAll,
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: BiText(
            label,
            textAlign: TextAlign.center,
            gap: 0,
            style: AppTextStyles.label.copyWith(
              color: active ? Colors.white : AppColors.chatPillInk,
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
        const Expanded(
          child: Divider(color: AppColors.roseFieldBorder),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: BiText.inline(
              'or',
              style: AppTextStyles.caption
                  .copyWith(fontSize: 12, color: AppColors.chatTimeInk)),
        ),
        const Expanded(
          child: Divider(color: AppColors.roseFieldBorder),
        ),
      ],
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top * 0.3 + AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // The brand mark in a glass ring — same treatment as the splash, so
          // login, splash and the launcher icon all read as one product.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9), width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFB4487B).withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: const CircleAvatar(
              radius: 38,
              backgroundColor: Colors.white,
              backgroundImage: AssetImage('assets/images/app_icon_white_bg.jpeg'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          BiText(
            AppStrings.loginTitle,
            textAlign: TextAlign.center,
            // The registration serif heading in the deep rose ink.
            style: AppTextStyles.displaySerif.copyWith(
              fontSize: 24,
              color: AppColors.roseTitleInk,
            ),
            urduColor: AppColors.roseTitleInk,
          ),
          const SizedBox(height: 4),
          BiText(
            AppStrings.loginSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 13.5,
              color: AppColors.regAccent.withValues(alpha: 0.9),
            ),
            urduColor: AppColors.regAccent.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }
}

/// Fingerprint login button. Shown only when the member has opted in and the
/// device can verify them — otherwise it disappears entirely (a dead button
/// would be worse than none). One tap opens the system BiometricPrompt and on
/// success the saved credentials are replayed through the normal login API.
class _FingerprintLoginButton extends StatefulWidget {
  const _FingerprintLoginButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_FingerprintLoginButton> createState() =>
      _FingerprintLoginButtonState();
}

class _FingerprintLoginButtonState extends State<_FingerprintLoginButton> {
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    if (!Get.isRegistered<BiometricAuthService>()) return;
    final bool enabled = await Get.find<BiometricAuthService>().isEnabled();
    if (!mounted) return;
    setState(() => _available = enabled);
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.regAccent,
        side: const BorderSide(color: AppColors.roseFieldBorder, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        backgroundColor: Colors.white,
      ),
      onPressed: widget.onPressed,
      icon: const Icon(Icons.fingerprint_rounded, size: 24),
      label: Text(
        'Login with Fingerprint',
        style: AppTextStyles.label
            .copyWith(fontSize: 14.5, color: AppColors.regAccent),
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
          style: AppTextStyles.body.copyWith(
              color: AppColors.chatPreviewInk, fontSize: 13.5),
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
            style: AppTextStyles.label.copyWith(
                color: AppColors.regAccent, fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}
