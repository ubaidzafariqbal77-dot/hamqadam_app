import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/api_options.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../core/validators/app_validators.dart';
import '../../../exceptions/app_exceptions.dart';
import '../../../repositories/registration_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_otp_field.dart';
import '../../../widgets/app_phone_field.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 5 — contributes `{country_code, phone, email}` to the complete payload.
/// The field takes a local number (`03001234567`); it is split into the
/// documented `country_code` + `phone` pair on the way out.
///
/// When [ApiOptions.emailOtpBeforeSubmit] is on, the email is verified here
/// with a code before the user may continue. See that flag for why it is
/// currently off.
class Step05Controller extends StepController {
  Step05Controller() : super(5);

  RegistrationRepository get _repo => Get.find<RegistrationRepository>();

  final TextEditingController phone = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController code = TextEditingController();

  /// The address the current code was sent to — clearing it when the user edits
  /// the email is what stops a verified tick from surviving a changed address.
  final RxString sentTo = ''.obs;
  final RxString verifiedEmail = ''.obs;

  final RxBool sending = false.obs;
  final RxBool verifying = false.obs;
  final RxString otpError = ''.obs;
  final RxInt resendIn = 0.obs;
  Timer? _ticker;

  static const int _cooldown = 60;

  bool get otpEnabled => ApiOptions.emailOtpBeforeSubmit;
  String get _email => email.text.trim().toLowerCase();
  bool get isVerified => verifiedEmail.value.isNotEmpty && verifiedEmail.value == _email;
  bool get codeSent => sentTo.value.isNotEmpty && sentTo.value == _email;
  bool get canResend => resendIn.value == 0 && !sending.value;

  @override
  void restore() {
    phone.text = buffer.getString('phone') ?? '';
    email.text = buffer.getString('email') ?? '';
    verifiedEmail.value = buffer.getString('email_verified_as') ?? '';
    email.addListener(_onEmailChanged);
  }

  /// A changed address invalidates any code already sent or verified.
  void _onEmailChanged() {
    if (sentTo.value.isNotEmpty && sentTo.value != _email) {
      sentTo.value = '';
      code.clear();
      otpError.value = '';
    }
  }

  Future<void> sendCode() async {
    if (sending.value) return;
    final String? invalid = AppValidators.email(email.text);
    if (invalid != null) {
      otpError.value = invalid;
      return;
    }
    sending.value = true;
    otpError.value = '';
    try {
      final ApiEnvelope res = await _repo.requestRegistrationOtp(email: _email);
      if (!res.success) throw ApiException(res.message);
      sentTo.value = _email;
      _startCooldown();
      AppSnackbar.success(res.message.isEmpty ? 'Code sent to $_email' : res.message);
    } on AppException catch (e) {
      otpError.value = e.message;
    } finally {
      sending.value = false;
    }
  }

  Future<void> verifyCode() async {
    if (verifying.value) return;
    if (code.text.trim().length < 6) {
      otpError.value = 'Enter the complete 6-digit code.';
      return;
    }
    verifying.value = true;
    otpError.value = '';
    try {
      final ApiEnvelope res = await _repo.verifyRegistrationOtp(
        code: code.text.trim(),
        email: _email,
      );
      if (!res.success) throw ApiException(res.message);
      verifiedEmail.value = _email;
      buffer.putOne('email_verified_as', _email);
      AppSnackbar.success('Email verified.');
    } on AppException catch (e) {
      otpError.value = e.message;
    } finally {
      verifying.value = false;
    }
  }

  void _startCooldown() {
    _ticker?.cancel();
    resendIn.value = _cooldown;
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (resendIn.value <= 1) {
        resendIn.value = 0;
        t.cancel();
      } else {
        resendIn.value -= 1;
      }
    });
  }

  @override
  bool extraValidate() {
    if (otpEnabled && !isVerified) {
      error.value = 'Please verify your email address before continuing.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() {
    final ({String countryCode, String phone}) split = ApiValues.splitPhone(phone.text);
    return <String, dynamic>{
      'phone': phone.text.trim(),
      'country_code': split.countryCode,
      'email': _email,
    };
  }

  @override
  void disposeFields() {
    _ticker?.cancel();
    email.removeListener(_onEmailChanged);
    phone.dispose();
    email.dispose();
    code.dispose();
  }
}

class Step05View extends StatefulWidget {
  const Step05View({super.key});
  @override
  State<Step05View> createState() => _Step05ViewState();
}

class _Step05ViewState extends State<Step05View> {
  late final Step05Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step05Controller());
  }

  @override
  void dispose() {
    Get.delete<Step05Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 5,
      totalSteps: 18,
      title: 'Contact information',
      subtitle: 'We use this to secure your account.',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      note: 'Private. Used only for account security.',
      helpText: c.otpEnabled
          ? 'Your email and phone must be unique. Verify the email with the code '
                'we send before continuing.'
          : 'Your email and phone must be unique. The email is verified right '
                'after you submit your registration.',
      children: <Widget>[
        const SizedBox(height: 22),
        Reveal(
          child: AppPhoneField(
            label: 'Mobile number',
            controller: c.phone,
            textInputAction: TextInputAction.next,
            validator: (String? v) => AppValidators.pakistaniPhone(v),
          ),
        ),
        const SizedBox(height: 42),
        Reveal(
          delayMs: 120,
          child: AppTextFormField(
            label: 'Email address',
            controller: c.email,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.email],
            validator: (String? v) => AppValidators.email(v),
          ),
        ),
        if (c.otpEnabled) _EmailVerification(c: c),
      ],
    );
  }
}

/// "Send code → enter code → green tick" block under the email field.
class _EmailVerification extends StatelessWidget {
  const _EmailVerification({required this.c});
  final Step05Controller c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isVerified) {
        return const Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
              SizedBox(width: AppSpacing.xs),
              Text('Email verified', style: TextStyle(color: Colors.green)),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          if (!c.codeSent)
            AppButton(
              label: 'Send verification code',
              variant: AppButtonVariant.outline,
              loading: c.sending.value,
              onPressed: c.sendCode,
            )
          else ...<Widget>[
            AppOtpField(
              label: 'Verification code',
              controller: c.code,
              onCompleted: (_) => c.verifyCode(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: 'Verify',
                    loading: c.verifying.value,
                    onPressed: c.verifyCode,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: c.canResend ? c.sendCode : null,
                  child: Text(
                    c.resendIn.value > 0 ? 'Resend ${c.resendIn.value}s' : 'Resend',
                    style: AppTextStyles.label.copyWith(
                      color: c.canResend ? AppColors.primary : Theme.of(context).disabledColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (c.otpError.value.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              c.otpError.value,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
        ],
      );
    });
  }
}
