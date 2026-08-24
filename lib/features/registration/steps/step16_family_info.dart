import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../constants/income_options.dart';
import '../../../constants/registration_options.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/step_scaffold.dart';

/// Screen 16 — Family information, the API's step 15
/// (`POST /auth/register/step/15`, skippable).
class Step16Controller extends StepController {
  Step16Controller() : super(16);

  LookupController get lookup => Get.find<LookupController>();

  final RxnString fatherOccupation = RxnString();
  final RxnString motherOccupation = RxnString();

  /// Sibling counts. Picked from a list rather than typed: the columns are
  /// `unsignedTinyInteger` and a free-text number field was the reported gap.
  final Rxn<LookupItem> brothers = Rxn<LookupItem>();
  final Rxn<LookupItem> sisters = Rxn<LookupItem>();

  @override
  void restore() {
    lookup.ensure(LookupKeys.siblings);
    fatherOccupation.value = buffer.getString('father_occupation');
    motherOccupation.value = buffer.getString('mother_occupation');
    brothers.value = _sibling(buffer.getInt('siblings_brothers'));
    sisters.value = _sibling(buffer.getInt('siblings_sisters'));
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'father_occupation': fatherOccupation.value?.trim(),
    'mother_occupation': motherOccupation.value?.trim(),
    'siblings_brothers': brothers.value?.id,
    'siblings_sisters': sisters.value?.id,
  };

  /// Rebuilds the picked row from a saved count.
  static LookupItem? _sibling(int? count) {
    if (count == null) return null;
    return LookupItem(id: count, name: SiblingOptions.labelFor(count));
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
        Obx(
          () => AppLookupDropdown(
            label: 'Number of brothers',
            lookupKey: LookupKeys.siblings,
            controller: c.lookup,
            selected: c.brothers.value,
            requirement: FieldRequirement.optional,
            onChanged: (LookupItem? v) => c.brothers.value = v,
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => AppLookupDropdown(
            label: 'Number of sisters',
            lookupKey: LookupKeys.siblings,
            controller: c.lookup,
            selected: c.sisters.value,
            requirement: FieldRequirement.optional,
            onChanged: (LookupItem? v) => c.sisters.value = v,
          ),
        ),
      ],
    );
  }
}
