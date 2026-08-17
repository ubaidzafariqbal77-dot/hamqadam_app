import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
        buffer.getString('first_name') ?? '',
        buffer.getString('last_name') ?? '',
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
      subtitle: 'Create a strong password to protect your account.',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Save password',
      onPrimary: c.submit,
      onBack: c.back,
      helpText: 'This password will secure your account once the last step is '
          'submitted. You will sign in with the email you entered earlier.',
      children: <Widget>[
        const SizedBox(height: 40),
        AppPasswordField(
          label: 'Password',
          controller: c.password,
          textInputAction: TextInputAction.next,
          validator: AppValidators.password,
          hint: 'At least 8 characters',
        ),
        const SizedBox(height: 40),
        AppPasswordField(
          label: 'Confirm password',
          controller: c.confirm,
          textInputAction: TextInputAction.done,
          validator: (String? v) => AppValidators.confirmPassword(v, c.password.text),
        ),
      ],
    );
  }
}
