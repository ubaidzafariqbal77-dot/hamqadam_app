import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/step_controller.dart';
import '../../../core/validators/app_validators.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/step_scaffold.dart';

class Step13Controller extends StepController {
  Step13Controller() : super(13);

  final TextEditingController aboutMe = TextEditingController();

  @override
  void restore() => aboutMe.text = buffer.getString('about_me') ?? '';

  @override
  Map<String, dynamic> collect() => <String, dynamic>{'about_me': aboutMe.text.trim()};

  @override
  void disposeFields() => aboutMe.dispose();
}

class Step13View extends StatefulWidget {
  const Step13View({super.key});
  @override
  State<Step13View> createState() => _Step13ViewState();
}

class _Step13ViewState extends State<Step13View> {
  late final Step13Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step13Controller());
  }

  @override
  void dispose() {
    Get.delete<Step13Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 13,
      totalSteps: 18,
      title: 'About yourself',
      subtitle: 'Write a short introduction (max 300 characters).',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        AppTextFormField(
          label: 'About yourself',
          controller: c.aboutMe,
          hint: 'Tell potential matches a little about who you are…',
          maxLines: 6,
          minLines: 4,
          maxLength: 300,
          showCounter: true,
          textInputAction: TextInputAction.newline,
          validator: (String? v) {
            final String? req = AppValidators.required(v, field: 'About yourself');
            if (req != null) return req;
            return AppValidators.minLength(v, 20, field: 'About yourself');
          },
        ),
      ],
    );
  }
}
