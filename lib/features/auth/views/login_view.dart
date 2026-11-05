import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../constants/app_colors.dart';
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
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/app_otp_field.dart';
import '../../../widgets/dismiss_keyboard.dart';
import '../../../widgets/loading_overlay.dart';

/// Login screen built from the Figma "HamQadam - login" frame (Website file,
/// Mobile page), in the app's own fonts and palette. Only the styling moved;
/// every controller, validator and handler is the one the previous design used.
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
          isLoading: c.submitting.value || emailOtp.submitting.value,
          child: Scaffold(
            backgroundColor: _Login.canvas,
            // Login is fully English-only: the whole subtree has bilingual
            // Urdu disabled.
            body: UrduScope(
              enabled: false,
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(child: _LoginBackdrop()),
                  SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(21, 13, 21, 21),
                      children: <Widget>[
                        const _LoginHeader(),
                        const SizedBox(height: 10),
                        const _Headline(),
                        const SizedBox(height: 12),
                        _MethodToggle(emailMode: _emailMode),
                        const SizedBox(height: 10),
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Obx(() => switch (_emailMode.value) {
                                    1 => _emailOtpForm(),
                                    _ => _emailForm(),
                                  }),
                              const SizedBox(height: 10),
                              const _OrDivider(),
                              // Fingerprint login (only when enabled on this
                              // device) sits under the divider.
                              _FingerprintLoginButton(onPressed: c.loginWithBiometric),
                              const SizedBox(height: 10),
                              _CreateAccountRow(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _TrustBadges(),
                        const SizedBox(height: 8),
                        const _RomanticFooterArt(),
                        const _FooterLinks(),
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
          Obx(() => _LoginField(
                label: 'Email Address',
                hint: 'name@email.com',
                icon: Icons.mail_outline_rounded,
                controller: c.emailCtrl,
                focusNode: c.emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.email],
                serverError: c.serverErrors['email'],
                onChanged: (_) => c.clearServerError('email'),
                onSubmitted: (_) => c.passwordFocus.requestFocus(),
                validator: (String? v) => AppValidators.email(v),
              )),
          const SizedBox(height: 12),
          Obx(() => _LoginField(
                label: 'Password',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                controller: c.passwordCtrl,
                focusNode: c.passwordFocus,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                serverError: c.serverErrors['password'],
                onChanged: (_) => c.clearServerError('password'),
                onSubmitted: (_) => c.submit(),
                validator: (String? v) => AppValidators.required(v, field: 'Password'),
              )),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: _forgotPassword,
                child: Text(
                  'Forgot password?',
                  style: _Login.text(11.5, FontWeight.w500, _Login.link),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(label: 'Log In', onPressed: c.submit),
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
          _LoginField(
            label: 'Registered Email',
            hint: 'name@email.com',
            icon: Icons.mail_outline_rounded,
            controller: emailOtp.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: (String? v) => AppValidators.email(v),
          ),
          Obx(() {
            if (!emailOtp.otpRequested.value) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _PrimaryButton(label: 'Send Code', onPressed: emailOtp.requestOtp),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 12),
                AppOtpField(label: 'Verification code', controller: emailOtp.otpCtrl),
                const SizedBox(height: 12),
                _PrimaryButton(label: 'Verify & Login', onPressed: emailOtp.verifyOtp),
                TextButton(
                  onPressed: emailOtp.reset,
                  child: Text(
                    'Change email / resend code',
                    style: _Login.text(12, FontWeight.w500, _Login.link),
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

/// Figma "HamQadam - login" tokens, expressed in the app's own palette and
/// fonts (Plus Jakarta Sans body, Playfair Display headings).
class _Login {
  const _Login._();

  static const Color canvas = Color(0xFFFBF5F5);
  static const Color ink = AppColors.roseTitleInk; // headings
  static const Color body = AppColors.chatPreviewInk; // body copy
  static const Color muted = AppColors.chatTimeInk; // hints, footer
  static const Color accent = AppColors.primaryDark; // script/italic accents
  static const Color link = AppColors.primaryInk; // links
  static const Color fieldBorder = Color(0xFFF0CCD5);
  static const Color divider = Color(0xFFEBD1D8);
  static const List<Color> button = AppColors.brandGradient;

  static TextStyle text(double size, FontWeight weight, Color color,
          {double? spacing, double? height}) =>
      TextStyle(
        fontFamily: AppTextStyles.bodyFont,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: height,
      );

  static TextStyle display(double size, Color color, {bool italic = false}) => TextStyle(
        fontFamily: AppTextStyles.displayFont,
        fontSize: size,
        fontWeight: FontWeight.w600,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: color,
        height: 1.25,
      );
}

/// Soft pink radial glows behind everything (Figma's atmospheric blobs).
class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  Widget _glow(Alignment at, double radius, Color color, double stop) => Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: at,
              radius: radius,
              colors: <Color>[color, color.withValues(alpha: 0)],
              stops: <double>[0, stop],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        _glow(const Alignment(-0.8, -0.76), 1.1, const Color(0xD9FDE0E9), 0.45),
        _glow(const Alignment(0.8, -0.6), 1.0, const Color(0xB3FEE9EE), 0.4),
        _glow(const Alignment(0, 0), 0.7, const Color(0xE6FFFFFF), 0.6),
        _glow(const Alignment(-0.7, 0.7), 1.05, const Color(0xBFF7C4D1), 0.5),
        _glow(const Alignment(0.7, 0.76), 1.1, const Color(0xD9F9D6E0), 0.45),
      ],
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 8),
        // Top-right slogan + doodle heart.
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('Rishton ki duniya',
                    style: _Login.display(13, _Login.accent, italic: true)),
                Text('CHOOSE FOREVER',
                    style: _Login.text(8, FontWeight.w700, _Login.accent, spacing: 1.28)),
              ],
            ),
            const SizedBox(width: 4),
            Transform.rotate(
              angle: -0.21,
              child: SvgPicture.asset('assets/images/login/heart_doodle.svg', width: 20, height: 20),
            ),
            const SizedBox(width: 2),
          ],
        ),
        const SizedBox(height: 8),
        // Dual watercolor hearts.
        SizedBox(
          width: 48,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 4,
                top: 0,
                child: Transform.rotate(
                  angle: -0.1,
                  child: Opacity(
                    opacity: 0.85,
                    child: SvgPicture.asset('assets/images/login/heart_left.svg', width: 24, height: 22),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 8,
                child: Transform.rotate(
                  angle: 0.21,
                  child: Opacity(
                    opacity: 0.9,
                    child: SvgPicture.asset('assets/images/login/heart_right.svg', width: 20, height: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        Text('HamQadam',
            style: _Login.display(28, _Login.ink).copyWith(letterSpacing: -0.7, height: 1)),
        const SizedBox(height: 4),
        Text('Rishton ki duniya',
            style: _Login.text(12, FontWeight.w400, _Login.body, spacing: 0.3)),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text("Let's Continue", style: _Login.display(28, _Login.ink)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Your Journey', style: _Login.display(28, _Login.accent, italic: true)),
            const SizedBox(width: 6),
            SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 4,
                    child: Transform.rotate(
                      angle: -0.21,
                      child: SvgPicture.asset('assets/images/login/mini_heart_a.svg', width: 18, height: 18),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -3,
                    child: Transform.rotate(
                      angle: 0.21,
                      child: SvgPicture.asset('assets/images/login/mini_heart_b.svg', width: 13, height: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('Same dreams. A brighter tomorrow.',
            style: _Login.text(12, FontWeight.w400, _Login.body)),
      ],
    );
  }
}

class _MethodToggle extends StatelessWidget {
  const _MethodToggle({required this.emailMode});

  /// 0 = Email & password, 1 = Email OTP (QA-required recovery login).
  final RxInt emailMode;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xCCFCE7F3)),
        ),
        child: Row(
          children: <Widget>[
            _seg('Email', emailMode.value == 0, () => emailMode.value = 0),
            _seg('Email OTP', emailMode.value == 1, () => emailMode.value = 1),
          ],
        ),
      );
    });
  }

  Widget _seg(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: _Login.button)
                : null,
            borderRadius: BorderRadius.circular(18),
            border: active ? Border.all(color: Colors.white.withValues(alpha: 0.3)) : null,
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: _Login.text(
              14,
              active ? FontWeight.w500 : FontWeight.w600,
              active ? Colors.white : const Color(0xFF404040),
              spacing: 0.35,
            ),
          ),
        ),
      ),
    );
  }
}

/// The frosted white card that holds the form.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3),
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4), spreadRadius: -4),
        ],
      ),
      child: child,
    );
  }
}

/// Figma input: icon on the left, small label above the value, all inside one
/// rounded pink-bordered box. Validation messages appear under the box.
class _LoginField extends StatefulWidget {
  const _LoginField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.focusNode,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.serverError,
    this.onChanged,
    this.onSubmitted,
    this.validator,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? serverError;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => widget.validator?.call(widget.controller.text),
      builder: (FormFieldState<String> field) {
        final String? error = field.errorText ?? widget.serverError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: error != null ? AppColors.error : _Login.fieldBorder),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(widget.icon, size: 16, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.label,
                            style: _Login.text(11, FontWeight.w500, _Login.body, height: 1.25)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          obscureText: _hidden,
                          keyboardType: widget.keyboardType,
                          textInputAction: widget.textInputAction,
                          autofillHints: widget.autofillHints,
                          style: _Login.text(13, FontWeight.w400, _Login.ink),
                          onChanged: (String v) {
                            field.didChange(v);
                            widget.onChanged?.call(v);
                          },
                          onSubmitted: widget.onSubmitted,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.only(bottom: 2.75),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            hintText: widget.hint,
                            hintStyle: _Login.text(13, FontWeight.w400, const Color(0xFFA6999C),
                                spacing: widget.obscure ? 1.3 : null),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.obscure)
                    GestureDetector(
                      onTap: () => setState(() => _hidden = !_hidden),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 16,
                          color: _Login.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 4),
                child: Text(error, style: _Login.text(11, FontWeight.w500, AppColors.error)),
              ),
          ],
        );
      },
    );
  }
}

/// Gradient pill with the label centred and a translucent arrow badge on the
/// right edge.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: _Login.button),
          borderRadius: BorderRadius.circular(12),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.38),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Text(label, style: _Login.text(15, FontWeight.w500, Colors.white, spacing: 0.375)),
            Positioned(
              right: 14,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white),
              ),
            ),
          ],
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
        const Expanded(child: Divider(color: _Login.divider, height: 1, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: _Login.text(11, FontWeight.w400, _Login.muted)),
        ),
        const Expanded(child: Divider(color: _Login.divider, height: 1, thickness: 1)),
      ],
    );
  }
}

class _TrustBadges extends StatelessWidget {
  const _TrustBadges();

  Widget _badge(IconData icon, String title, String sub) => Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 14, color: AppColors.primaryDark),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: _Login.text(10, FontWeight.w600, _Login.ink, height: 1.15)),
                Text(sub, style: _Login.text(9, FontWeight.w400, _Login.muted, height: 1.15)),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    const Widget sep = SizedBox(
      height: 22,
      child: VerticalDivider(color: Color(0xCCEBD1D8), width: 8, thickness: 1),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          _badge(Icons.verified_user_outlined, 'Safe', '& Secure'),
          sep,
          _badge(Icons.lock_outline_rounded, 'Your Privacy', 'Our Priority'),
          sep,
          _badge(Icons.favorite_border_rounded, 'Real People', 'Real Intentions'),
        ],
      ),
    );
  }
}

/// Watercolor couple illustration with the script tagline on the right.
class _RomanticFooterArt extends StatelessWidget {
  const _RomanticFooterArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 143,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 8,
            child: SvgPicture.asset(
              'assets/images/login/romantic_illustration.svg',
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('Choose Forever',
                    style: _Login.display(30, _Login.accent, italic: true)
                        .copyWith(fontWeight: FontWeight.w400, letterSpacing: 0.9, height: 1.1)),
                const SizedBox(height: 4),
                Text('MORE THAN A MATCH',
                    style: _Login.text(7.5, FontWeight.w700, _Login.accent, spacing: 1.2)),
                Text('A LIFETIME TOGETHER',
                    style: _Login.text(7.5, FontWeight.w700, _Login.accent, spacing: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks();

  static const String _site = 'https://hamqadam.com';

  Widget _link(String label, String path) => GestureDetector(
        onTap: () => launchUrl(Uri.parse('$_site$path'), mode: LaunchMode.externalApplication),
        child: Text(label, style: _Login.text(10, FontWeight.w400, _Login.body)),
      );

  @override
  Widget build(BuildContext context) {
    final Widget bar = Text('|', style: _Login.text(10, FontWeight.w400, const Color(0xFFCFBEBF)));
    return Container(
      padding: const EdgeInsets.only(top: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x99F1D5DC))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _link('Terms', '/terms-conditions'),
          const SizedBox(width: 8),
          bar,
          const SizedBox(width: 8),
          _link('Privacy Policy', '/privacy-policy'),
          const SizedBox(width: 8),
          bar,
          const SizedBox(width: 8),
          _link('Community Guidelines', '/terms-conditions'),
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
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: _Login.fieldBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white.withValues(alpha: 0.85),
        ),
        onPressed: widget.onPressed,
        icon: const Icon(Icons.fingerprint_rounded, size: 20),
        label: Text('Login with Fingerprint',
            style: _Login.text(13, FontWeight.w500, AppColors.primaryDark)),
      ),
    );
  }
}

class _CreateAccountRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('New to HamQadam? ', style: _Login.text(12.5, FontWeight.w400, _Login.body)),
          GestureDetector(
            onTap: () async {
              // Start a fresh registration from step 1 (drops any old draft
              // and the previous profile-completion record). Awaited so step 1
              // never reads lookup lists that are about to be wiped.
              await Get.find<RegistrationController>().resetForNewAccount();
              Get.toNamed(AppRoutes.accountFor);
            },
            child: Text(
              'Create account',
              style: _Login.text(12.5, FontWeight.w600, AppColors.primaryInk).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
