import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/api_options.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/income_options.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_form_field.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/reveal.dart';
import '../../../widgets/step_scaffold.dart';

/// Step 10 — `POST /auth/register/step/10`.
///
/// `employment_status` is hardcoded (government, private, civil, defence,
/// self_employed, unemployed, retired); `profession_category_id` →
/// `profession_id` is a dependent dynamic dropdown pair.
class Step10Controller extends StepController {
  Step10Controller() : super(10);

  LookupController get lookup => Get.find<LookupController>();

  /// Annual income, chosen from a band. The band's lower bound is what gets
  /// posted, because `members.annual_income` is a decimal column.
  final Rxn<LookupItem> annualIncome = Rxn<LookupItem>();
  final TextEditingController jobTitle = TextEditingController();
  final TextEditingController organization = TextEditingController();
  final TextEditingController yearsOfExperience = TextEditingController();
  final RxnString employmentStatus = RxnString();
  final Rxn<LookupItem> category = Rxn<LookupItem>();
  final Rxn<LookupItem> profession = Rxn<LookupItem>();

  bool get hasProfessions =>
      category.value != null &&
      lookup.itemsOf(LookupKeys.professions, parentId: category.value!.id).isNotEmpty;

  void onCategory(LookupItem? v) {
    category.value = v;
    profession.value = null;
    if (v != null) lookup.ensure(LookupKeys.professions, parentId: v.id);
  }

  @override
  void restore() {
    lookup.ensure(LookupKeys.professionCategories);
    lookup.ensure(LookupKeys.annualIncome);
    final int? income = buffer.getInt('annual_income');
    final IncomeBand? band = IncomeBand.forValue(income);
    if (band != null) annualIncome.value = band.item;
    jobTitle.text = buffer.getString('job_title') ?? '';
    organization.text = buffer.getString('organization') ?? '';
    yearsOfExperience.text = buffer.getInt('years_of_experience')?.toString() ?? '';
    employmentStatus.value = buffer.getString('employment_status');
    final int? cat = buffer.getInt('profession_category_id');
    if (cat != null) {
      category.value = LookupItem(id: cat, name: '');
      lookup.ensure(LookupKeys.professions, parentId: cat);
    }
    final int? prof = buffer.getInt('profession_id');
    if (prof != null) profession.value = LookupItem(id: prof, name: '');
  }

  @override
  bool extraValidate() {
    if (employmentStatus.value == null) {
      error.value = 'Please select your employment status.';
      return false;
    }
    if (category.value == null) {
      error.value = 'Please select your profession category.';
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    'annual_income': annualIncome.value?.id,
    'employment_status': employmentStatus.value,
    'profession_category_id': category.value?.id,
    'profession_id': profession.value?.id,
    'job_title': jobTitle.text.trim(),
    'organization': organization.text.trim(),
    // Always a number: the `careers` table rejects a null here, so a blank
    // field must post 0 rather than being omitted from the payload.
    'years_of_experience': int.tryParse(yearsOfExperience.text.trim()) ?? 0,
  };

  @override
  void disposeFields() {
    jobTitle.dispose();
    organization.dispose();
    yearsOfExperience.dispose();
  }
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
        Obx(
          () => AppLookupDropdown(
            label: 'Annual income (PKR)',
            lookupKey: LookupKeys.annualIncome,
            controller: c.lookup,
            selected: c.annualIncome.value,
            requirement: FieldRequirement.optional,
            onChanged: (LookupItem? v) => c.annualIncome.value = v,
          ),
        ),
        const SizedBox(height: 20),
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppOptionDropdown(
                label: 'Employment status',
                value: ApiOptions.labelOf(ApiOptions.employmentStatus, c.employmentStatus.value),
                options: ApiOptions.labelsOf(ApiOptions.employmentStatus),
                onChanged: (String? v) => c.employmentStatus.value =
                    ApiOptions.valueOfLabel(ApiOptions.employmentStatus, v),
              ),
              if (c.employmentStatus.value != null) ...<Widget>[
                const SizedBox(height: 20),
                Reveal(
                  child: AppLookupDropdown(
                    label: 'Profession category',
                    lookupKey: LookupKeys.professionCategories,
                    controller: c.lookup,
                    selected: c.category.value,
                    onChanged: c.onCategory,
                  ),
                ),
              ],
              if (c.hasProfessions) ...<Widget>[
                const SizedBox(height: 20),
                Reveal(
                  child: AppLookupDropdown(
                    label: 'Profession',
                    lookupKey: LookupKeys.professions,
                    controller: c.lookup,
                    parentId: c.category.value?.id,
                    selected: c.profession.value,
                    requirement: FieldRequirement.optional,
                    onChanged: (LookupItem? v) => c.profession.value = v,
                  ),
                ),
              ],
              if (c.category.value != null) ...<Widget>[
                const SizedBox(height: 20),
                Reveal(
                  child: AppTextFormField(
                    label: 'Job title',
                    controller: c.jobTitle,
                    requirement: FieldRequirement.optional,
                    hint: 'e.g. Software Engineer',
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: 20),
                Reveal(
                  child: AppTextFormField(
                    label: 'Organization',
                    controller: c.organization,
                    requirement: FieldRequirement.optional,
                    hint: 'Where you work',
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: 20),
                Reveal(
                  child: AppTextFormField(
                    label: 'Years of experience',
                    controller: c.yearsOfExperience,
                    requirement: FieldRequirement.optional,
                    hint: 'e.g. 4',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
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
