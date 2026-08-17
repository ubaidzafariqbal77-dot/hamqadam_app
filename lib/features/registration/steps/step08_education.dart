import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/api_options.dart';
import '../../../constants/app_lookups.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_picker_field.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 8 — `POST /auth/register/step/8`.
///
/// Dynamic dropdowns: `education_level_id` → `degree_id` → `field_of_study_id`,
/// plus `institution_id` (filtered by the country picked on step 4).
/// `education_status` is hardcoded: completed / in_progress / dropped.
class Step08Controller extends StepController {
  Step08Controller() : super(8);

  LookupController get lookup => Get.find<LookupController>();

  final Rxn<LookupItem> level = Rxn<LookupItem>();
  final Rxn<LookupItem> degree = Rxn<LookupItem>();
  final Rxn<LookupItem> field = Rxn<LookupItem>();
  final Rxn<LookupItem> institution = Rxn<LookupItem>();
  final RxnString status = RxnString();
  final RxnString year = RxnString();

  int? countryId;

  /// Graduation years: 60 back, 10 ahead (an in-progress degree can end later).
  static List<String> get years {
    final int now = DateTime.now().year;
    return <String>[for (int y = now + 10; y >= now - 60; y--) '$y'];
  }

  bool get hasDegrees =>
      level.value != null &&
      lookup.itemsOf(LookupKeys.degrees, parentId: level.value!.id).isNotEmpty;

  bool get hasFields =>
      degree.value != null &&
      lookup.itemsOf(LookupKeys.fieldsOfStudy, parentId: degree.value!.id).isNotEmpty;

  bool get hasInstitutions =>
      lookup.itemsOf(LookupKeys.institutions, parentId: countryId).isNotEmpty;

  bool get isInProgress => status.value == 'in_progress';

  String get yearLabel => isInProgress ? 'Expected graduation year' : 'Graduation year';

  @override
  void restore() {
    countryId = buffer.getInt('country_id');
    lookup
      ..ensure(LookupKeys.educationLevels)
      ..ensure(LookupKeys.institutions, parentId: countryId);

    final int? lv = buffer.getInt('education_level_id');
    if (lv != null) {
      level.value = LookupItem(id: lv, name: '');
      lookup.ensure(LookupKeys.degrees, parentId: lv);
    }
    final int? dg = buffer.getInt('degree_id');
    if (dg != null) {
      degree.value = LookupItem(id: dg, name: '');
      lookup.ensure(LookupKeys.fieldsOfStudy, parentId: dg);
    }
    final int? fs = buffer.getInt('field_of_study_id');
    if (fs != null) field.value = LookupItem(id: fs, name: '');
    final int? inst = buffer.getInt('institution_id');
    if (inst != null) institution.value = LookupItem(id: inst, name: '');
    status.value = buffer.getString('education_status');
    year.value = buffer.getInt('graduation_year')?.toString();
  }

  void onLevel(LookupItem? v) {
    level.value = v;
    degree.value = null;
    field.value = null;
    if (v != null) lookup.ensure(LookupKeys.degrees, parentId: v.id);
  }

  void onDegree(LookupItem? v) {
    degree.value = v;
    field.value = null;
    if (v != null) lookup.ensure(LookupKeys.fieldsOfStudy, parentId: v.id);
  }

  @override
  bool extraValidate() {
    if (level.value == null) {
      error.value = 'Please select your highest education.';
      return false;
    }
    if (status.value == null) {
      error.value = 'Please select whether your education is completed.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'education_level_id': level.value?.id,
    'degree_id': degree.value?.id,
    'field_of_study_id': field.value?.id,
    'institution_id': institution.value?.id,
    'education_status': status.value,
    'graduation_year': int.tryParse(year.value ?? ''),
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
              const SizedBox(height: 24),
              AppLookupDropdown(
                label: 'Highest education',
                lookupKey: LookupKeys.educationLevels,
                controller: c.lookup,
                selected: c.level.value,
                onChanged: c.onLevel,
              ),
              if (c.hasDegrees) ...<Widget>[
                const SizedBox(height: 28),
                Reveal(
                  child: AppLookupDropdown(
                    label: 'Degree',
                    lookupKey: LookupKeys.degrees,
                    controller: c.lookup,
                    parentId: c.level.value?.id,
                    selected: c.degree.value,
                    requirement: FieldRequirement.optional,
                    onChanged: c.onDegree,
                  ),
                ),
              ],
              if (c.hasFields) ...<Widget>[
                const SizedBox(height: 28),
                Reveal(
                  child: AppLookupDropdown(
                    label: 'Field of study',
                    lookupKey: LookupKeys.fieldsOfStudy,
                    controller: c.lookup,
                    parentId: c.degree.value?.id,
                    selected: c.field.value,
                    requirement: FieldRequirement.optional,
                    onChanged: (LookupItem? v) => c.field.value = v,
                  ),
                ),
              ],
              if (c.level.value != null && c.hasInstitutions) ...<Widget>[
                const SizedBox(height: 28),
                Reveal(
                  child: AppLookupDropdown(
                    label: 'College / University',
                    lookupKey: LookupKeys.institutions,
                    controller: c.lookup,
                    parentId: c.countryId,
                    selected: c.institution.value,
                    requirement: FieldRequirement.optional,
                    onChanged: (LookupItem? v) => c.institution.value = v,
                  ),
                ),
              ],
              if (c.level.value != null) ...<Widget>[
                const SizedBox(height: 28),
                Reveal(
                  child: AppOptionDropdown(
                    label: 'Education status',
                    value: ApiOptions.labelOf(ApiOptions.educationStatus, c.status.value),
                    options: ApiOptions.labelsOf(ApiOptions.educationStatus),
                    onChanged: (String? v) => c.status.value =
                        ApiOptions.valueOfLabel(ApiOptions.educationStatus, v),
                  ),
                ),
              ],
              if (c.status.value != null) ...<Widget>[
                const SizedBox(height: 28),
                Reveal(
                  child: AppStringPicker(
                    label: c.yearLabel,
                    value: c.year.value,
                    options: Step08Controller.years,
                    requirement: FieldRequirement.optional,
                    hint: 'Select year',
                    onChanged: (String? v) => c.year.value = v,
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
