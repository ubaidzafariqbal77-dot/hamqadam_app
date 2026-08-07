import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/step_controller.dart';
import '../../../core/validators/app_validators.dart';
import '../../../widgets/app_password_field.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 11 — Account Security. Completing this step assembles the buffered
/// account fields (name, DOB, email, phone, gender, on_behalf) with the
/// password entered here and creates the real account via `POST /auth/register`.
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
      primaryLabel: 'Create account',
      onPrimary: c.submit,
      onBack: c.back,
      helpText: 'Your account is created at this step. If your email or phone is '
          'already registered, go back and update it.',
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
