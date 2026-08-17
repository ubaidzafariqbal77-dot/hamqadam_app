import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_lookups.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 3 — `POST /auth/register/step/3`.
///
/// Dynamic dropdowns: `religion_id`, `mother_tongue`, and the dependent chain
/// `sect_main_id` (by religion) → `school_of_thought_id` (by sect) →
/// `tradition_id` (by school of thought). The three dependent pickers only
/// appear when the backend actually has options for the selected parent.
class Step03Controller extends StepController {
  Step03Controller() : super(3);

  LookupController get lookup => Get.find<LookupController>();

  final Rxn<LookupItem> religion = Rxn<LookupItem>();
  final Rxn<LookupItem> motherTongue = Rxn<LookupItem>();
  final Rxn<LookupItem> sect = Rxn<LookupItem>();
  final Rxn<LookupItem> school = Rxn<LookupItem>();
  final Rxn<LookupItem> tradition = Rxn<LookupItem>();

  bool get hasSects =>
      religion.value != null &&
      lookup.itemsOf(LookupKeys.sectMain, parentId: religion.value!.id).isNotEmpty;

  bool get hasSchools =>
      sect.value != null &&
      lookup.itemsOf(LookupKeys.schoolOfThought, parentId: sect.value!.id).isNotEmpty;

  bool get hasTraditions =>
      school.value != null &&
      lookup.itemsOf(LookupKeys.traditions, parentId: school.value!.id).isNotEmpty;

  @override
  void restore() {
    lookup
      ..ensure(LookupKeys.religions)
      ..ensure(LookupKeys.languages);

    final int? r = buffer.getInt('religion_id');
    if (r != null) {
      religion.value = LookupItem(id: r, name: '');
      lookup
        ..ensure(LookupKeys.sectMain, parentId: r)
        ..ensure(LookupKeys.castes);
    }
    final int? t = buffer.getInt('mother_tongue');
    if (t != null) motherTongue.value = LookupItem(id: t, name: '');

    final int? s = buffer.getInt('sect_main_id');
    if (s != null) {
      sect.value = LookupItem(id: s, name: '');
      lookup.ensure(LookupKeys.schoolOfThought, parentId: s);
    }
    final int? sc = buffer.getInt('school_of_thought_id');
    if (sc != null) {
      school.value = LookupItem(id: sc, name: '');
      lookup.ensure(LookupKeys.traditions, parentId: sc);
    }
    final int? tr = buffer.getInt('tradition_id');
    if (tr != null) tradition.value = LookupItem(id: tr, name: '');
  }

  void onReligion(LookupItem? v) {
    religion.value = v;
    sect.value = null;
    school.value = null;
    tradition.value = null;
    if (v != null) {
      lookup
        ..ensure(LookupKeys.sectMain, parentId: v.id)
        // Warm the caste list (step 6) so it never shows a spinner.
        ..ensure(LookupKeys.castes);
    }
  }

  void onSect(LookupItem? v) {
    sect.value = v;
    school.value = null;
    tradition.value = null;
    if (v != null) lookup.ensure(LookupKeys.schoolOfThought, parentId: v.id);
  }

  void onSchool(LookupItem? v) {
    school.value = v;
    tradition.value = null;
    if (v != null) lookup.ensure(LookupKeys.traditions, parentId: v.id);
  }

  @override
  bool extraValidate() {
    if (religion.value == null) {
      error.value = 'Please select your religion.';
      return false;
    }
    if (motherTongue.value == null) {
      error.value = 'Please select your language.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'religion_id': religion.value?.id,
    'mother_tongue': motherTongue.value?.id,
    'sect_main_id': sect.value?.id,
    'school_of_thought_id': school.value?.id,
    'tradition_id': tradition.value?.id,
  };
}

class Step03View extends StatefulWidget {
  const Step03View({super.key});
  @override
  State<Step03View> createState() => _Step03ViewState();
}

class _Step03ViewState extends State<Step03View> {
  late final Step03Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step03Controller());
  }

  @override
  void dispose() {
    Get.delete<Step03Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 3,
      totalSteps: 18,
      title: 'Religion & language',
      subtitle: 'Your faith and mother tongue.',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        Obx(
          () => AppLookupPicker(
            label: 'Religion',
            lookupKey: LookupKeys.religions,
            controller: c.lookup,
            selected: c.religion.value,
            onChanged: c.onReligion,
          ),
        ),
        Obx(
          () => c.religion.value == null
              ? const SizedBox.shrink()
              : Reveal(
                  child: AppLookupPicker(
                    label: 'Language',
                    lookupKey: LookupKeys.languages,
                    controller: c.lookup,
                    selected: c.motherTongue.value,
                    onChanged: (LookupItem? v) => c.motherTongue.value = v,
                  ),
                ),
        ),
        // Sect → school of thought → tradition. Shown only where the backend
        // actually has data for the selected parent.
        Obx(
          () => !c.hasSects
              ? const SizedBox.shrink()
              : Reveal(
                  child: AppLookupPicker(
                    label: 'Sect',
                    lookupKey: LookupKeys.sectMain,
                    controller: c.lookup,
                    parentId: c.religion.value?.id,
                    selected: c.sect.value,
                    requirement: FieldRequirement.optional,
                    onChanged: c.onSect,
                  ),
                ),
        ),
        Obx(
          () => !c.hasSchools
              ? const SizedBox.shrink()
              : Reveal(
                  child: AppLookupPicker(
                    label: 'School of thought',
                    lookupKey: LookupKeys.schoolOfThought,
                    controller: c.lookup,
                    parentId: c.sect.value?.id,
                    selected: c.school.value,
                    requirement: FieldRequirement.optional,
                    onChanged: c.onSchool,
                  ),
                ),
        ),
        Obx(
          () => !c.hasTraditions
              ? const SizedBox.shrink()
              : Reveal(
                  child: AppLookupPicker(
                    label: 'Tradition',
                    lookupKey: LookupKeys.traditions,
                    controller: c.lookup,
                    parentId: c.school.value?.id,
                    selected: c.tradition.value,
                    requirement: FieldRequirement.optional,
                    onChanged: (LookupItem? v) => c.tradition.value = v,
                  ),
                ),
        ),
      ],
    );
  }
}
