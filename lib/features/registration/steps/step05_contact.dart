import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/step_controller.dart';
import '../../../core/validators/app_validators.dart';
import '../../../widgets/app_phone_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

class Step05Controller extends StepController {
  Step05Controller() : super(5);

  final TextEditingController phone = TextEditingController();
  final TextEditingController email = TextEditingController();

  @override
  void restore() {
    phone.text = buffer.getString('phone') ?? '';
    email.text = buffer.getString('email') ?? '';
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'phone': phone.text.trim(),
    'email': email.text.trim().toLowerCase(),
  };

  @override
  void disposeFields() {
    phone.dispose();
    email.dispose();
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
      helpText: 'Your email and phone must be unique. They are verified when you '
          'set your password in a later step.',
      children: <Widget>[
        SizedBox(height: 22),
        Reveal(
          child: AppPhoneField(
            label: 'Mobile number',
            controller: c.phone,
            textInputAction: TextInputAction.next,
            validator: (String? v) => AppValidators.pakistaniPhone(v),
          ),
        ),
         SizedBox(height: 42),
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
      ],
    );
  }
}
