import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/api_options.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/step_controller.dart';
import '../../../constants/reg_icons.dart';
import '../../../core/api/api_client.dart';
import '../../../core/validators/app_validators.dart';
import '../../../exceptions/app_exceptions.dart';
import '../../../repositories/account_check_repository.dart';
import '../../../repositories/registration_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_otp_field.dart';
import '../../../widgets/app_phone_field.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/field_icon_assets.dart';
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

  // ---- Live availability checks (Task: green "Available" / red "already
  // registered" under each field as the member types) ----
  AccountCheckRepository get _checkRepo => Get.isRegistered<AccountCheckRepository>()
      ? Get.find<AccountCheckRepository>()
      : Get.put(AccountCheckRepository(Get.find<ApiClient>()), permanent: true);

  final Rxn<bool> phoneAvailable = Rxn<bool>();
  final RxString phoneCheckMessage = ''.obs;
  final Rxn<bool> emailAvailable = Rxn<bool>();
  final RxString emailCheckMessage = ''.obs;
  Timer? _phoneDebounce;
  Timer? _emailDebounce;
  String _lastPhoneChecked = '';
  String _lastEmailChecked = '';

  /// Debounced server check for the phone field.
  void onPhoneTyped(String raw) {
    _phoneDebounce?.cancel();
    final String value = raw.trim();
    if (value.isEmpty || AppValidators.pakistaniPhone(value) != null) {
      phoneAvailable.value = null;
      phoneCheckMessage.value = '';
      return;
    }
    if (value == _lastPhoneChecked && phoneAvailable.value != null) return;
    _phoneDebounce = Timer(const Duration(milliseconds: 700), () => _checkPhone(value));
  }

  Future<void> _checkPhone(String value) async {
    final ({String countryCode, String phone}) split = ApiValues.splitPhone(value);
    final String full = '${split.countryCode}${split.phone}';
    _lastPhoneChecked = value;
    try {
      final AccountCheckResult r = await _checkRepo.check(type: 'phone', value: full);
      // Stale-response guard: the field may have changed while in flight.
      if (value != phone.text.trim()) return;
      phoneAvailable.value = r.available;
      phoneCheckMessage.value = r.message ?? '';
    } on AppException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 404) {
        phoneAvailable.value = null;
        phoneCheckMessage.value = '';
      }
      // Network blips stay silent — the server re-validates on submit.
    } catch (_) {}
  }

  /// Debounced server check for the email field.
  void onEmailTyped(String raw) {
    _emailDebounce?.cancel();
    final String value = raw.trim();
    if (value.isEmpty || AppValidators.email(value) != null) {
      emailAvailable.value = null;
      emailCheckMessage.value = '';
      return;
    }
    if (value.toLowerCase() == _lastEmailChecked && emailAvailable.value != null) return;
    _emailDebounce = Timer(const Duration(milliseconds: 700), () => _checkEmail(value));
  }

  Future<void> _checkEmail(String value) async {
    _lastEmailChecked = value.toLowerCase();
    try {
      final AccountCheckResult r = await _checkRepo.check(type: 'email', value: value);
      if (value != email.text.trim()) return;
      emailAvailable.value = r.available;
      emailCheckMessage.value = r.message ?? '';
    } on AppException {
      // Silent — the server re-validates on submit.
    } catch (_) {}
  }

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
    // Live availability checks fire as the member types.
    phone.addListener(() => onPhoneTyped(phone.text));
    email.addListener(() => onEmailTyped(email.text));
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
    _phoneDebounce?.cancel();
    _emailDebounce?.cancel();
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
      art: RegIcons.step05Contact,
      artIcon: Icons.contact_phone_rounded,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppPhoneField(
                insetLabel: true,
                label: 'Mobile number',
                controller: c.phone,
                textInputAction: TextInputAction.next,
                validator: (String? v) => AppValidators.pakistaniPhone(v),
                // Reference style: rose handset glyph in the field's leading disc.
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 8),
                  child: AssetOrIconDisc(child: PhoneGlyph(size: 22)),
                ),
              ),
              _AvailabilityText(
                available: c.phoneAvailable.value,
                message: c.phoneCheckMessage.value,
              ),
            ],
          ),
        ),
        const SizedBox(height: 42),
        Reveal(
            delayMs: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppTextFormField(
                  insetLabel: true,
                  label: 'Email address',
                  controller: c.email,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.email],
                  validator: (String? v) => AppValidators.email(v),
                  // Matching rose envelope glyph — same disc treatment as the
                  // phone field above.
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: AssetOrIconDisc(child: MailGlyph(size: 22)),
                  ),
                ),
                _AvailabilityText(
                  available: c.emailAvailable.value,
                  message: c.emailCheckMessage.value,
                ),
              ],
            ),
          ),
        if (c.otpEnabled) _EmailVerification(c: c),
      ],
    );
  }
}

/// Green "available" / red "already registered" line under a field, driven by
/// the live `POST /auth/check` result. Hidden until the server has answered.
class _AvailabilityText extends StatelessWidget {
  const _AvailabilityText({required this.available, required this.message});

  final bool? available;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (available == null || message.isEmpty) return const SizedBox.shrink();
    final bool ok = available!;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 14),
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 15,
            color: ok ? Colors.green : AppColors.error,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: ok ? Colors.green : AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
                      color: c.canResend ? AppColors.regAccent : Theme.of(context).disabledColor,
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
