import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/step_controller.dart';
import '../../../core/validators/app_validators.dart';
import '../../../widgets/app_date_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

class Step02Controller extends StepController {
  Step02Controller() : super(2);

  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final FocusNode lastNameFocus = FocusNode();
  final Rxn<DateTime> dob = Rxn<DateTime>();

  /// Date of birth is revealed once the user moves to the last-name field.
  final RxBool showDob = false.obs;

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  @override
  void onInit() {
    super.onInit();
    lastNameFocus.addListener(() {
      if (lastNameFocus.hasFocus) showDob.value = true;
    });
  }

  @override
  void restore() {
    firstName.text = buffer.getString('first_name') ?? '';
    lastName.text = buffer.getString('last_name') ?? '';
    final String? d = buffer.getString('date_of_birth');
    if (d != null) {
      dob.value = DateTime.tryParse(d);
      showDob.value = true;
    }
  }

  @override
  bool extraValidate() {
    final String? err = AppValidators.dateOfBirth(dob.value);
    if (err != null) {
      error.value = err;
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'first_name': firstName.text.trim(),
    'last_name': lastName.text.trim(),
    'date_of_birth': dob.value == null ? null : _fmt.format(dob.value!),
  };

  @override
  void disposeFields() {
    firstName.dispose();
    lastName.dispose();
    lastNameFocus.dispose();
  }
}

class Step02View extends StatefulWidget {
  const Step02View({super.key});
  @override
  State<Step02View> createState() => _Step02ViewState();
}

class _Step02ViewState extends State<Step02View> {
  late final Step02Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step02Controller());
  }

  @override
  void dispose() {
    Get.delete<Step02Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    return StepScaffold(
      stepNumber: 2,
      totalSteps: 18,
      title: 'Basic information',
      subtitle: 'Tell us your name and date of birth.',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        AppTextFormField(
          label: 'First name',
          controller: c.firstName,
          hint: 'e.g. Ahmed',
          textInputAction: TextInputAction.next,
          validator: (String? v) => AppValidators.personName(v, field: 'First name'),
        ),
        AppTextFormField(
          label: 'Last name',
          controller: c.lastName,
          focusNode: c.lastNameFocus,
          hint: 'e.g. Khan',
          textInputAction: TextInputAction.done,
          validator: (String? v) => AppValidators.personName(v, field: 'Last name'),
        ),
        Obx(
          () => c.showDob.value
              ? Reveal(
                  child: AppDateField(
                    label: 'Date of birth',
                    value: c.dob.value,
                    firstDate: DateTime(now.year - 90),
                    lastDate: DateTime(now.year - 18, now.month, now.day),
                    onChanged: (DateTime d) => c.dob.value = d,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
