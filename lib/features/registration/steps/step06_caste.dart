import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

class Step06Controller extends StepController {
  Step06Controller() : super(6);

  LookupController get lookup => Get.find<LookupController>();

  final Rxn<LookupItem> caste = Rxn<LookupItem>();
  int? religionId;

  @override
  void restore() {
    religionId = buffer.getInt('religion_id');
    if (religionId != null) lookup.ensure(LookupKeys.castes, parentId: religionId);
    final int? ca = buffer.getInt('caste_id');
    if (ca != null) caste.value = LookupItem(id: ca, name: '');
  }

  @override
  bool extraValidate() {
    if (caste.value == null) {
      error.value = 'Please select your caste.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{'caste_id': caste.value?.id};
}

class Step06View extends StatefulWidget {
  const Step06View({super.key});
  @override
  State<Step06View> createState() => _Step06ViewState();
}

class _Step06ViewState extends State<Step06View> {
  late final Step06Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step06Controller());
  }

  @override
  void dispose() {
    Get.delete<Step06Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 6,
      totalSteps: 18,
      title: 'Caste',
      subtitle: 'Select the caste that best describes your community.',
      // The caste list hangs off the religion, so say so when that step was
      // skipped (otherwise the dropdown just sits there disabled).
      note: c.religionId == null
          ? 'Add your religion first — the caste list depends on it.'
          : null,
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        Reveal(
          child: Obx(
            () => AppLookupDropdown(
              label: 'Caste',
              lookupKey: LookupKeys.castes,
              controller: c.lookup,
              parentId: c.religionId,
              selected: c.caste.value,
              enabled: c.religionId != null,
              disabledHint: 'Select your religion first',
              onChanged: (LookupItem? v) => c.caste.value = v,
            ),
          ),
        ),
      ],
    );
  }
}
