import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../constants/registration_options.dart';
import '../../../controllers/step_controller.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/step_scaffold.dart';

class Step16Controller extends StepController {
  Step16Controller() : super(16);

  final RxnString fatherOccupation = RxnString();
  final RxnString motherOccupation = RxnString();
  final TextEditingController brothers = TextEditingController();
  final TextEditingController sisters = TextEditingController();

  @override
  void restore() {
    fatherOccupation.value = buffer.getString('father_occupation');
    motherOccupation.value = buffer.getString('mother_occupation');
    brothers.text = buffer.getInt('siblings_brothers')?.toString() ?? '';
    sisters.text = buffer.getInt('siblings_sisters')?.toString() ?? '';
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'father_occupation': fatherOccupation.value?.trim(),
    'mother_occupation': motherOccupation.value?.trim(),
    'siblings_brothers': int.tryParse(brothers.text.trim()),
    'siblings_sisters': int.tryParse(sisters.text.trim()),
  };

  @override
  void disposeFields() {
    brothers.dispose();
    sisters.dispose();
  }
}

class Step16View extends StatefulWidget {
  const Step16View({super.key});
  @override
  State<Step16View> createState() => _Step16ViewState();
}

class _Step16ViewState extends State<Step16View> {
  late final Step16Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step16Controller());
  }

  @override
  void dispose() {
    Get.delete<Step16Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 16,
      totalSteps: 18,
      title: 'Family information',
      subtitle: 'A little about your family (optional).',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      showSkip: true,
      onSkip: c.skip,
      children: <Widget>[
        const SizedBox(height: 8),
        Obx(
          () => AppStringPicker(
            label: "Father's occupation",
            value: c.fatherOccupation.value,
            options: RegOptions.parentOccupations,
            requirement: FieldRequirement.optional,
            hint: 'Select or type (e.g. Businessman)',
            allowCustom: true,
            onChanged: (String? v) => c.fatherOccupation.value = v,
          ),
        ),
       const SizedBox(height: 8),
        Obx(
          () => AppStringPicker(
            label: "Mother's occupation",
            value: c.motherOccupation.value,
            options: RegOptions.parentOccupations,
            requirement: FieldRequirement.optional,
            hint: 'Select or type (e.g. Homemaker)',
            allowCustom: true,
            onChanged: (String? v) => c.motherOccupation.value = v,
          ),
        ),
       const SizedBox(height: 8),
        AppTextFormField(
          label: 'Number of brothers',
          controller: c.brothers,
          requirement: FieldRequirement.optional,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          hint: '0',
          textInputAction: TextInputAction.next,
        ),
      const SizedBox(height: 8),
        AppTextFormField(
          label: 'Number of sisters',
          controller: c.sisters,
          requirement: FieldRequirement.optional,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          hint: '0',
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}
