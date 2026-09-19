import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/registration_payload.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/validators/app_validators.dart';
import '../../../widgets/app_password_field.dart';
import '../../../widgets/step_scaffold.dart';

/// Screen 11 — Account Security. Contributes `email_verify`, `password` and
/// `password_confirmation` to the single `POST /auth/register/complete` payload.
/// `email_verify` re-confirms the address captured on the contact step (it is
/// also where the verification code is emailed), so the two must match.
class Step11Controller extends StepController {
  Step11Controller() : super(11);

  final TextEditingController password = TextEditingController();
  final TextEditingController confirm = TextEditingController();

  @override
  bool extraValidate() {
    final String? personal = AppValidators.passwordNotPersonal(
      password.text,
      against: <String>[
        buffer.getString('email') ?? '',
        // The name is one field now, so check the whole thing and each part —
        // "Ahmed Khan", "Ahmed" and "Khan" are all still off limits.
        ...?RegPayload.fullName(buffer)?.split(' '),
        RegPayload.fullName(buffer) ?? '',
        buffer.getString('phone') ?? '',
      ],
    );
    if (personal != null) {
      error.value = personal;
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'password': password.text,
    'password_confirmation': confirm.text,
  };

  @override
  void disposeFields() {
    password.dispose();
    confirm.dispose();
  }
}

class Step11View extends StatefulWidget {
  const Step11View({super.key});
  @override
  State<Step11View> createState() => _Step11ViewState();
}

class _Step11ViewState extends State<Step11View> {
  late final Step11Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step11Controller());
  }

  @override
  void dispose() {
    Get.delete<Step11Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 11,
      totalSteps: 18,
      title: 'Account security',
      art: 'assets/registration/password.png', 
      artIcon: Icons.lock_outline_rounded,
      subtitle: 'Create a strong password to protect your account.',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Save password',
      onPrimary: c.submit,
      onBack: c.back,
      helpText: 'This password will secure your account once the last step is '
          'submitted. You will sign in with the email you entered earlier.',
      titleColor: const Color(0xFFB23A5E),
      children: <Widget>[
        const SizedBox(height: 4),
        AppPasswordField(
          label: 'Password',
          controller: c.password,
          textInputAction: TextInputAction.next,
          validator: AppValidators.password,
          hint: 'At least 8 characters',
        ),
        // Live strength meter + the three requirement chips from the
        // reference: label row, segmented bar, then the 3 checks.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: c.password,
          builder: (BuildContext context, TextEditingValue v, _) {
            final _PwStrength s = _PwStrength.of(v.text);
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Password strength',
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 15,
                          color: const Color(0xFF2B2230),
                        ),
                      ),
                      const Spacer(),
                      if (v.text.isNotEmpty)
                        Text(
                          '${s.label} · ${s.percent}%',
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 14,
                            color: s.color,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: s.percent / 100),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      builder: (BuildContext ctx, double val, _) =>
                          LinearProgressIndicator(
                        value: val,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF3E3E9),
                        valueColor: AlwaysStoppedAnimation<Color>(s.color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(child: _req('At least 8 characters', s.hasLength)),
                      Expanded(child: _req('Includes number or symbol', s.hasSymbolOrDigit)),
                      Expanded(child: _req('Mixed case letters', s.hasMixedCase)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        AppPasswordField(
          label: 'Confirm password',
          controller: c.confirm,
          textInputAction: TextInputAction.done,
          validator: (String? v) => AppValidators.confirmPassword(v, c.password.text),
        ),
      ],
    );
  }

  /// One requirement chip: outline tick when met, grey when not.
  Widget _req(String label, bool met) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: met ? Colors.transparent : Colors.transparent,
            border: Border.all(
              color: met ? AppColors.success : Colors.black26,
              width: 1.4,
            ),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 13,
            color: met ? AppColors.success : Colors.black26,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              height: 1.3,
              color: met ? AppColors.lightTextPrimary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Live password scoring for the strength meter. Purely visual — the submit
/// validator is still the server-matching [AppValidators.password].
class _PwStrength {
  const _PwStrength(this.percent, this.label, this.color, this.hasLength,
      this.hasSymbolOrDigit, this.hasMixedCase);

  final int percent;
  final String label;
  final Color color;
  final bool hasLength;
  final bool hasSymbolOrDigit;
  final bool hasMixedCase;

  static _PwStrength of(String pw) {
    final bool hasLen = pw.length >= 8;
    final bool hasSymOrDigit = pw.contains(RegExp(r'[0-9]')) || pw.contains(RegExp(r'[^A-Za-z0-9]'));
    final bool hasMixed = pw.contains(RegExp(r'[a-z]')) && pw.contains(RegExp(r'[A-Z]'));
    int score = 0;
    if (hasLen) score++;
    if (hasSymOrDigit) score++;
    if (hasMixed) score++;
    if (pw.length >= 12) score++;
    // The three chips are the rules members see; the meter never says "Strong"
    // unless all three pass. Length beyond 8 tops the score up.
    final int percent = switch (score) {
      0 => 0,
      1 => 30,
      2 => 60,
      3 => 85,
      _ => 100,
    };
    final (String, Color) verdict = switch (score) {
      0 || 1 => ('Weak', const Color(0xFFD64541)),
      2 => ('Medium', const Color(0xFFC98A19)),
      _ => ('Strong', AppColors.primary),
    };
    return _PwStrength(percent, verdict.$1, verdict.$2, hasLen, hasSymOrDigit, hasMixed);
  }
}
