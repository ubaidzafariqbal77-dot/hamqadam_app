import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/registration_payload.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/validators/app_validators.dart';
import '../../../widgets/app_date_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 2 — `POST /auth/register/step/2`. The API stores one `full_name`, and
/// this screen collects it in one field; both parts are still required, so the
/// validation is as strict as the old first-name + last-name pair.
class Step02Controller extends StepController {
  Step02Controller() : super(2);

  final TextEditingController fullName = TextEditingController();
  final FocusNode nameFocus = FocusNode();
  final Rxn<DateTime> dob = Rxn<DateTime>();

  /// Date of birth is revealed once the user starts on the name field.
  final RxBool showDob = false.obs;

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  @override
  void onInit() {
    super.onInit();
    nameFocus.addListener(() {
      if (nameFocus.hasFocus) showDob.value = true;
    });
  }

  @override
  void restore() {
    // Reads `full_name`, falling back to a draft that still holds the old
    // first/last pair — see RegPayload.fullName.
    fullName.text = RegPayload.fullName(buffer) ?? '';
    final String? d = buffer.getString('date_of_birth');
    if (d != null) {
      dob.value = DateTime.tryParse(d);
      showDob.value = true;
    }
    if (fullName.text.isNotEmpty) showDob.value = true;
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
    'full_name': AppValidators.collapseSpaces(fullName.text),
    'date_of_birth': dob.value == null ? null : _fmt.format(dob.value!),
  };

  @override
  void disposeFields() {
    fullName.dispose();
    nameFocus.dispose();
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
          label: 'Full name',
          controller: c.fullName,
          focusNode: c.nameFocus,
          hint: 'e.g. Ahmed Khan',
          textCapitalization: TextCapitalization.words,
          autofillHints: const <String>[AutofillHints.name],
          textInputAction: TextInputAction.done,
          validator: (String? v) => AppValidators.fullName(v),
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
