import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 6 — `POST /auth/register/step/6` → `{caste_id, sub_caste_id}`.
///
/// `caste_id` is an independent dynamic dropdown; `sub_caste_id` depends on it.
class Step06Controller extends StepController {
  Step06Controller() : super(6);

  LookupController get lookup => Get.find<LookupController>();

  final Rxn<LookupItem> caste = Rxn<LookupItem>();
  final Rxn<LookupItem> subCaste = Rxn<LookupItem>();

  bool get hasSubCastes =>
      caste.value != null &&
      lookup.itemsOf(LookupKeys.subCastes, parentId: caste.value!.id).isNotEmpty;

  @override
  void restore() {
    lookup.ensure(LookupKeys.castes);
    final int? ca = buffer.getInt('caste_id');
    if (ca != null) {
      caste.value = LookupItem(id: ca, name: '');
      lookup.ensure(LookupKeys.subCastes, parentId: ca);
    }
    final int? sub = buffer.getInt('sub_caste_id');
    if (sub != null) subCaste.value = LookupItem(id: sub, name: '');
  }

  void onCaste(LookupItem? v) {
    caste.value = v;
    subCaste.value = null;
    if (v != null) lookup.ensure(LookupKeys.subCastes, parentId: v.id);
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
  Map<String, dynamic> collect() => <String, dynamic>{
    'caste_id': caste.value?.id,
    'sub_caste_id': subCaste.value?.id,
  };
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
              selected: c.caste.value,
              onChanged: c.onCaste,
            ),
          ),
        ),
        Obx(
          () => !c.hasSubCastes
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Reveal(
                    child: AppLookupDropdown(
                      label: 'Sub caste',
                      lookupKey: LookupKeys.subCastes,
                      controller: c.lookup,
                      parentId: c.caste.value?.id,
                      selected: c.subCaste.value,
                      requirement: FieldRequirement.optional,
                      onChanged: (LookupItem? v) => c.subCaste.value = v,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
