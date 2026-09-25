import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../constants/reg_icons.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/bilingual_text.dart';
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
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return StepScaffold(
      stepNumber: 6,
      totalSteps: 18,
      title: 'Caste',
      art: RegIcons.step06Caste,
      artIcon: Icons.groups_rounded,
      subtitle: 'Select the caste that best describes your community.',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      note: 'Your selection is private and can be edited later.',
      children: <Widget>[
        Reveal(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : const Color(0xFFFDF1F5),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF7D3E0),
              ),
            ),
            child: Column(
              children: <Widget>[
                Obx(
                  () => AppLookupDropdown(
                    label: 'Caste',
                    lookupKey: LookupKeys.castes,
                    controller: c.lookup,
                    selected: c.caste.value,
                    onChanged: c.onCaste,
                    icon: Icons.groups_rounded,
                  ),
                ),
                Obx(
                  () => !c.hasSubCastes
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: AppLookupDropdown(
                            label: 'Sub caste',
                            lookupKey: LookupKeys.subCastes,
                            controller: c.lookup,
                            parentId: c.caste.value?.id,
                            selected: c.subCaste.value,
                            requirement: FieldRequirement.optional,
                            onChanged: (LookupItem? v) => c.subCaste.value = v,
                            icon: Icons.family_restroom_rounded,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        // Reference design's "Popular" quick-pick row: the first few castes
        // from the server list as one-tap chips. Same data, same selection —
        // just a faster path.
        Reveal(
          child: Obx(() {
            final List<LookupItem> popular = c.lookup
                .itemsOf(LookupKeys.castes)
                .take(6)
                .toList(growable: false);
            if (popular.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                BiText(
                  'Popular',
                  style: AppTextStyles.label.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: popular
                      .map(
                        (LookupItem item) => _PopularChip(
                          label: item.name,
                          selected: c.caste.value?.id == item.id,
                          onTap: () => c.onCaste(item),
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

/// One quick-pick chip in the "Popular" row.
class _PopularChip extends StatelessWidget {
  const _PopularChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: AppColors.regPrimaryGradient,
                  )
                : null,
            color: selected
                ? AppColors.regAccent
                : dark
                ? AppColors.darkSurface
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.roseFieldBorder,
              width: 1.2,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.regAccent.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: BiText(
                  label,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13.5,
                    color: selected
                        ? Colors.white
                        : (dark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary),
                  ),
                ),
              ),
              if (selected) ...<Widget>[
                const SizedBox(width: 6),
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
