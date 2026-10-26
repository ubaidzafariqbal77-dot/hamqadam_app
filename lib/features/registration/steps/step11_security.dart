import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/registration_payload.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../core/validators/app_validators.dart';
import '../../../repositories/account_check_repository.dart';
import '../../../widgets/app_password_field.dart';
import '../../../widgets/step_scaffold.dart';
import '../../../constants/reg_icons.dart';

/// Screen 11 — Account Security. Contributes `email_verify`, `password` and
/// `password_confirmation` to the single `POST /auth/register/complete` payload.
/// `email_verify` re-confirms the address captured on the contact step (it is
/// also where the verification code is emailed), so the two must match.
class Step11Controller extends StepController {
  Step11Controller() : super(11);

  final TextEditingController password = TextEditingController();
  final TextEditingController confirm = TextEditingController();
  final TextEditingController referral = TextEditingController();

  // ---- Live referral-code check (valid = a real member owns the code) -------
  AccountCheckRepository get _checkRepo =>
      Get.isRegistered<AccountCheckRepository>()
      ? Get.find<AccountCheckRepository>()
      : Get.put(AccountCheckRepository(Get.find<ApiClient>()), permanent: true);

  /// null = not checked / empty, true = valid, false = unknown code.
  final Rxn<bool> referralValid = Rxn<bool>();
  final RxBool referralChecking = false.obs;
  final RxString referralMessage = ''.obs;
  Timer? _referralDebounce;
  int _referralSeq = 0;

  void onReferralChanged(String raw) {
    _referralDebounce?.cancel();
    referralValid.value = null;
    referralMessage.value = '';
    final String code = raw.trim();
    if (code.isEmpty) {
      referralChecking.value = false;
      return;
    }
    referralChecking.value = true;
    final int seq = ++_referralSeq;
    _referralDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final AccountCheckResult r = await _checkRepo.check(type: 'referral', value: code);
        if (seq != _referralSeq) return; // a newer keystroke superseded this
        referralValid.value = r.available;
        referralMessage.value = r.available
            ? (r.referrerName?.isNotEmpty ?? false
                ? 'Valid code — referred by ${r.referrerName}'
                : 'Valid referral code')
            : 'This referral code does not belong to any member';
      } catch (_) {
        if (seq != _referralSeq) return;
        // Offline / server hiccup: stay neutral. The server re-checks at signup
        // and ignores a bad code instead of failing the registration.
        referralValid.value = null;
        referralMessage.value = 'Could not verify the code right now';
      } finally {
        if (seq == _referralSeq) referralChecking.value = false;
      }
    });
  }

  @override
  bool extraValidate() {
    if (referral.text.trim().isNotEmpty && referralValid.value == false) {
      error.value = 'That referral code is not valid. Fix it or clear the field.';
      return false;
    }
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
    if (referral.text.trim().isNotEmpty) 'referral_code': referral.text.trim(),
  };

  @override
  void disposeFields() {
    password.dispose();
    confirm.dispose();
    _referralDebounce?.cancel();
    referral.dispose();
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
      art: RegIcons.step11Security,
      artIcon: Icons.lock_outline_rounded,
      subtitle: 'Create a strong password to protect your account.',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Save password',
      onPrimary: c.submit,
      onBack: c.back,
      helpText:
          'This password will secure your account once the last step is '
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
                      Expanded(
                        child: _req('At least 8 characters', s.hasLength),
                      ),
                      Expanded(
                        child: _req(
                          'Includes number or symbol',
                          s.hasSymbolOrDigit,
                        ),
                      ),
                      Expanded(
                        child: _req('Mixed case letters', s.hasMixedCase),
                      ),
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
          revalidateWhenControllerChanges: c.password,
          textInputAction: TextInputAction.done,
          validator: (String? v) =>
              AppValidators.confirmPassword(v, c.password.text),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: c.referral,
          textCapitalization: TextCapitalization.characters,
          onChanged: c.onReferralChanged,
          validator: AppValidators.referralCode,
          decoration: InputDecoration(
            labelText: 'Referral code (optional)',
            hintText: 'Enter a friend\'s code',
            prefixIcon: const Icon(Icons.card_giftcard_rounded),
            suffixIcon: Obx(() {
              if (c.referralChecking.value) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final bool? v = c.referralValid.value;
              if (v == null) return const SizedBox.shrink();
              return Icon(
                v ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: v ? const Color(0xFF2E7D5B) : const Color(0xFFD64545),
              );
            }),
          ),
        ),
        Obx(() {
          final String m = c.referralMessage.value;
          if (m.isEmpty) return const SizedBox.shrink();
          final bool? v = c.referralValid.value;
          return Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              m,
              style: AppTextStyles.caption.copyWith(
                color: v == true
                    ? const Color(0xFF2E7D5B)
                    : v == false
                        ? const Color(0xFFD64545)
                        : AppColors.lightTextSecondary,
              ),
            ),
          );
        }),
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
              color: met
                  ? AppColors.lightTextPrimary
                  : AppColors.lightTextSecondary,
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
  const _PwStrength(
    this.percent,
    this.label,
    this.color,
    this.hasLength,
    this.hasSymbolOrDigit,
    this.hasMixedCase,
  );

  final int percent;
  final String label;
  final Color color;
  final bool hasLength;
  final bool hasSymbolOrDigit;
  final bool hasMixedCase;

  static _PwStrength of(String pw) {
    final bool hasLen = pw.length >= 8;
    final bool hasSymOrDigit =
        pw.contains(RegExp(r'[0-9]')) || pw.contains(RegExp(r'[^A-Za-z0-9]'));
    final bool hasMixed =
        pw.contains(RegExp(r'[a-z]')) && pw.contains(RegExp(r'[A-Z]'));
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
      _ => ('Strong', AppColors.regAccent),
    };
    return _PwStrength(
      percent,
      verdict.$1,
      verdict.$2,
      hasLen,
      hasSymOrDigit,
      hasMixed,
    );
  }
}
