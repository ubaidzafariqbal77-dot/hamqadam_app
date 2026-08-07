import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/registration_options.dart';
import '../../../controllers/step_controller.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

class Step08Controller extends StepController {
  Step08Controller() : super(8);

  final RxnString educationLevel = RxnString();
  final RxnString institution = RxnString();

  @override
  void restore() {
    educationLevel.value = buffer.getString('education_level');
    institution.value = buffer.getString('institution');
  }

  @override
  bool extraValidate() {
    if (educationLevel.value == null) {
      error.value = 'Please select your highest education.';
      return false;
    }
    if ((institution.value ?? '').trim().isEmpty) {
      error.value = 'Please select or enter your college / university.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'education_level': educationLevel.value,
    'institution': institution.value?.trim(),
  };
}

class Step08View extends StatefulWidget {
  const Step08View({super.key});
  @override
  State<Step08View> createState() => _Step08ViewState();
}

class _Step08ViewState extends State<Step08View> {
  late final Step08Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step08Controller());
  }

  @override
  void dispose() {
    Get.delete<Step08Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 8,
      totalSteps: 18,
      title: 'Education',
      subtitle: 'Your highest qualification.',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 40),
              AppOptionDropdown(
                label: 'Highest education',
                value: c.educationLevel.value,
                options: RegOptions.educationLevel,
                onChanged: (String? v) => c.educationLevel.value = v,
              ),
              const SizedBox(height: 40),
              if (c.educationLevel.value != null) ...<Widget>[
                const SizedBox(height: 20),
                Reveal(
                  child: AppStringPicker(
                    label: 'College / University',
                    value: c.institution.value,
                    options: RegOptions.institutions,
                    hint: 'Select or type your institution',
                    allowCustom: true,
                    onChanged: (String? v) => c.institution.value = v,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
