import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../constants/registration_options.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/validators/app_validators.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

class Step10Controller extends StepController {
  Step10Controller() : super(10);

  final TextEditingController annualIncome = TextEditingController();
  final RxnString workCategory = RxnString();
  final RxnString profession = RxnString();

  List<String> get professions =>
      RegOptions.professionsByCategory[workCategory.value] ?? const <String>[];

  void onCategory(String? v) {
    workCategory.value = v;
    profession.value = null;
  }

  @override
  void restore() {
    annualIncome.text = buffer.getString('annual_income') ?? '';
    workCategory.value = buffer.getString('work_category');
    profession.value = buffer.getString('profession');
  }

  @override
  bool extraValidate() {
    if (workCategory.value == null) {
      error.value = 'Please select your work category.';
      return false;
    }
    if (profession.value == null) {
      error.value = 'Please select your profession.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'annual_income': int.tryParse(annualIncome.text.trim()),
    'work_category': workCategory.value,
    'profession': profession.value,
  };

  @override
  void disposeFields() => annualIncome.dispose();
}

class Step10View extends StatefulWidget {
  const Step10View({super.key});
  @override
  State<Step10View> createState() => _Step10ViewState();
}

class _Step10ViewState extends State<Step10View> {
  late final Step10Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step10Controller());
  }

  @override
  void dispose() {
    Get.delete<Step10Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 10,
      totalSteps: 18,
      title: 'Career & income',
      subtitle: 'Your work and annual income.',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        AppTextFormField(
          label: 'Annual income (PKR)',
          controller: c.annualIncome,
          hint: 'e.g. 1200000',
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          validator: (String? v) =>
              AppValidators.numberInRange(v, 0, 100000000, field: 'Annual income'),
        ),
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppStringPicker(
                label: 'Work category',
                value: c.workCategory.value,
                options: RegOptions.workCategory,
                onChanged: c.onCategory,
              ),
              if (c.workCategory.value != null) ...<Widget>[
                const SizedBox(height: 20),
                Reveal(
                  child: AppStringPicker(
                    label: 'Profession',
                    value: c.profession.value,
                    options: c.professions,
                    onChanged: (String? v) => c.profession.value = v,
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
