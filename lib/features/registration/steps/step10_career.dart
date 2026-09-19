import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/api_options.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/income_options.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_picker_field.dart';
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

  /// Annual income band. The chosen row's id is `annual_salary_range_id`, a
  /// foreign key into the server's `annual_salary_ranges` table —
  /// `/auth/register/steps` lists that field (not `annual_income`) for step 10,
  /// and `register/complete` rejects a payload without it.
  ///
  /// The old numeric `annual_income` is no longer collected here: the server
  /// dropped it from step 10, and a band id cannot be turned back into an
  /// amount without knowing each row's bounds, which only the server has.
  final Rxn<LookupItem> salaryRange = Rxn<LookupItem>();
  final TextEditingController jobTitle = TextEditingController();
  final TextEditingController organization = TextEditingController();
  final TextEditingController yearsOfExperience = TextEditingController();
  final RxnString employmentStatus = RxnString();
  final Rxn<LookupItem> category = Rxn<LookupItem>();
  final Rxn<LookupItem> profession = Rxn<LookupItem>();
  final RxString quickFilter = 'Full-time'.obs;

  bool get hasProfessions =>
      category.value != null &&
      lookup
          .itemsOf(LookupKeys.professions, parentId: category.value!.id)
          .isNotEmpty;

  void onCategory(LookupItem? v) {
    category.value = v;
    profession.value = null;
    if (v != null) lookup.ensure(LookupKeys.professions, parentId: v.id);
  }

  @override
  void restore() {
    lookup.ensure(LookupKeys.professionCategories);
    lookup.ensure(LookupKeys.annualSalaryRanges);
    // An id stored before the server list was known could point at a row that
    // no longer exists; restoring it would post a value `exists` rejects.
    final int? rangeId = buffer.getInt('annual_salary_range_id');
    if (SalaryRangeOptions.isValid(rangeId)) {
      salaryRange.value = LookupItem(id: rangeId!, name: '');
    }
    jobTitle.text = buffer.getString('job_title') ?? '';
    organization.text = buffer.getString('organization') ?? '';
    yearsOfExperience.text =
        buffer.getInt('years_of_experience')?.toString() ?? '';
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
    // Required by `POST /auth/register/complete`. Catching it here means the
    // user is told on the step that collects it, instead of at the very end of
    // the flow by a rejected submission.
    if (salaryRange.value == null) {
      error.value = 'Please select your annual salary range.';
      return false;
    }
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
    'annual_salary_range_id': salaryRange.value?.id,
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
      title: 'Career & Income',
      art: 'assets/registration/career-income/career_header.png',
      artIcon: Icons.work_outline_rounded,
      subtitle: 'Your work and annual income',
      busy: c.busy,
      error: c.error,
      formKey: c.formKey,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      children: <Widget>[
        Obx(
          () => _CareerLookupField(
            label: 'Annual income (PKR)',
            lookupKey: LookupKeys.annualSalaryRanges,
            controller: c.lookup,
            selected: c.salaryRange.value,
            onChanged: (LookupItem? value) => c.salaryRange.value = value,
            suggested: true,
          ),
        ),
        const _CareerTipBanner(
          text:
              'Select the range closest to your yearly earnings. This helps us personalize your plan.',
        ),
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CareerOptionField(
                label: 'Employment status',
                value: ApiOptions.labelOf(
                  ApiOptions.employmentStatus,
                  c.employmentStatus.value,
                ),
                options: ApiOptions.labelsOf(ApiOptions.employmentStatus),
                onChanged: (String? value) => c.employmentStatus.value =
                    ApiOptions.valueOfLabel(ApiOptions.employmentStatus, value),
              ),
              const SizedBox(height: AppSpacing.lg),
              _CareerQuickFilters(
                selected: c.quickFilter.value,
                onChanged: (String value) => c.quickFilter.value = value,
              ),
              if (c.employmentStatus.value != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                Reveal(
                  child: _CareerLookupField(
                    label: 'Profession category',
                    lookupKey: LookupKeys.professionCategories,
                    controller: c.lookup,
                    selected: c.category.value,
                    onChanged: c.onCategory,
                  ),
                ),
              ],
              if (c.hasProfessions) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Reveal(
                  child: _CareerLookupField(
                    label: 'Profession',
                    lookupKey: LookupKeys.professions,
                    controller: c.lookup,
                    parentId: c.category.value?.id,
                    selected: c.profession.value,
                    onChanged: (LookupItem? value) =>
                        c.profession.value = value,
                  ),
                ),
              ],
              if (c.category.value != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Reveal(
                  child: _CareerTextField(
                    label: 'Job title',
                    controller: c.jobTitle,
                    hint: 'e.g. Software Engineer',
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Reveal(
                  child: _CareerTextField(
                    label: 'Organization',
                    controller: c.organization,
                    hint: 'Where you work',
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Reveal(
                  child: _CareerTextField(
                    label: 'Years of experience',
                    controller: c.yearsOfExperience,
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

class _CareerLookupField extends StatelessWidget {
  const _CareerLookupField({
    required this.label,
    required this.lookupKey,
    required this.controller,
    required this.selected,
    required this.onChanged,
    this.parentId,
    this.suggested = false,
  });

  final String label;
  final String lookupKey;
  final LookupController controller;
  final LookupItem? selected;
  final ValueChanged<LookupItem?> onChanged;
  final int? parentId;
  final bool suggested;

  LookupItem? _resolved(List<LookupItem> items) {
    if (selected == null) return null;
    for (final LookupItem item in items) {
      if (item.id == selected!.id) return item;
    }
    return selected!.name.isEmpty ? null : selected;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ApiState<List<LookupItem>> state = controller.stateOf(
        lookupKey,
        parentId: parentId,
      );
      final List<LookupItem> items = state.data ?? const <LookupItem>[];
      final LookupItem? current = _resolved(items);

      return _CareerFieldFrame(
        label: label,
        value: current?.name,
        hint: 'Select',
        suggested: suggested,
        showSelectionCheck: suggested,
        onTap: () async {
          final LookupItem? picked = await showLookupPickerSheet(
            context,
            title: label,
            items: items,
            selectedId: current?.id,
            loading: state.status == ApiStatus.loading,
            onRetry: () {
              controller.load(lookupKey, parentId: parentId, force: true);
              Navigator.of(context).pop();
            },
          );
          if (picked != null) onChanged(picked);
        },
      );
    });
  }
}

class _CareerOptionField extends StatelessWidget {
  const _CareerOptionField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CareerFieldFrame(
      label: label,
      value: value,
      hint: 'Select',
      onTap: () async {
        final String? picked = await showStringPickerSheet(
          context,
          title: label,
          options: options,
          selected: value,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

class _CareerFieldFrame extends StatelessWidget {
  const _CareerFieldFrame({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.suggested = false,
    this.showSelectionCheck = false,
  });

  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final bool suggested;
  final bool showSelectionCheck;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool hasValue = value != null && value!.trim().isNotEmpty;
    final Color border = dark
        ? AppColors.requiredFieldBorderDark
        : AppColors.roseFieldBorder;
    final Color labelColor = dark
        ? AppColors.darkTextSecondary
        : AppColors.primary.withValues(alpha: 0.82);

    final Widget field = Material(
      color: dark ? AppColors.darkSurface : Colors.white,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppDimensions.fieldMinHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: border, width: 1.3),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  hasValue ? value! : hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 17,
                    color: hasValue
                        ? (dark
                              ? AppColors.darkInputText
                              : AppColors.lightInputText)
                        : (dark
                              ? AppColors.darkTextHint
                              : AppColors.lightTextHint),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (showSelectionCheck && hasValue)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: dark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextPrimary,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.bodyStrong.copyWith(
            fontSize: 17,
            color: labelColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (suggested && hasValue)
          Row(
            children: <Widget>[
              Expanded(child: field),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  'Suggested',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.primary.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ],
          )
        else
          field,
      ],
    );
  }
}

class _CareerTipBanner extends StatelessWidget {
  const _CareerTipBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.primary.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.primary.withValues(alpha: 0.82),
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTextStyles.body.copyWith(
                  color: dark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  height: 1.35,
                ),
                children: <InlineSpan>[
                  const TextSpan(
                    text: 'Tip: ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareerQuickFilters extends StatelessWidget {
  const _CareerQuickFilters({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<String> options = <String>[
      'Full-time',
      'Part-time',
      'Freelance',
    ];
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color labelColor = dark
        ? AppColors.darkTextSecondary
        : AppColors.primary.withValues(alpha: 0.82);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Quick filters',
          style: AppTextStyles.bodyStrong.copyWith(
            fontSize: 17,
            color: labelColor,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            for (int index = 0; index < options.length; index++) ...<Widget>[
              Expanded(
                child: _CareerQuickFilterChip(
                  label: options[index],
                  selected: selected == options[index],
                  onTap: () => onChanged(options[index]),
                ),
              ),
              if (index != options.length - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ],
    );
  }
}

class _CareerQuickFilterChip extends StatelessWidget {
  const _CareerQuickFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.76)
          : (dark ? AppColors.darkSurface : Colors.white),
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.roseFieldBorder,
              width: 1.3,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: selected
                      ? Colors.white
                      : (dark
                            ? AppColors.darkTextPrimary
                            : AppColors.primary.withValues(alpha: 0.82)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CareerTextField extends StatelessWidget {
  const _CareerTextField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color border = dark
        ? AppColors.requiredFieldBorderDark
        : AppColors.roseFieldBorder;
    final Color labelColor = dark
        ? AppColors.darkTextSecondary
        : AppColors.primary.withValues(alpha: 0.82);

    OutlineInputBorder outline(Color color, [double width = 1.3]) {
      return OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.bodyStrong.copyWith(
            fontSize: 17,
            color: labelColor,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          cursorColor: AppColors.primary,
          style: AppTextStyles.bodyStrong.copyWith(
            fontSize: 17,
            color: dark ? AppColors.darkInputText : AppColors.lightInputText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.body.copyWith(
              color: dark ? AppColors.darkTextHint : AppColors.lightTextHint,
            ),
            filled: true,
            fillColor: dark ? AppColors.darkSurface : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 17,
            ),
            border: outline(border),
            enabledBorder: outline(border),
            focusedBorder: outline(AppColors.primary, 1.6),
          ),
        ),
      ],
    );
  }
}
