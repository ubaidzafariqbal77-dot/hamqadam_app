import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/registration_options.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/step_controller.dart';
import '../../../models/lookup_item_model.dart';
import '../../../widgets/app_chip_selector.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/bilingual_text.dart';
import '../../../widgets/form_field_container.dart';
import '../../../widgets/step_scaffold.dart';

/// Screen 15 — Interests & hobbies, the API's step 14
/// (`POST /auth/register/step/14` → `{"hobbies": ["Reading", …]}`, skippable).
///
/// The chips come from the dynamic `hobbies` list when the backend provides one
/// and fall back to the bundled categories otherwise.
class Step15Controller extends StepController {
  Step15Controller() : super(15);

  LookupController get lookup => Get.find<LookupController>();

  final RxList<String> selected = <String>[].obs;

  /// Chip groups to show: one group per bundled category, or a single group
  /// holding whatever the API returned.
  Map<String, List<String>> get categories {
    final List<LookupItem> items = lookup.itemsOf(LookupKeys.hobbies);
    if (items.isEmpty) return RegOptions.interestCategories;
    return <String, List<String>>{
      'Interests': items.map((LookupItem i) => i.name).toList(),
    };
  }

  @override
  void restore() {
    lookup.ensure(LookupKeys.hobbies);
    selected.assignAll(buffer.getStringList('interests'));
  }

  void toggle(String chip) {
    if (selected.contains(chip)) {
      selected.remove(chip);
    } else {
      if (selected.length >= RegOptions.maxInterests) {
        AppSnackbar.info('You can select up to ${RegOptions.maxInterests} interests.');
        return;
      }
      selected.add(chip);
    }
  }

  @override
  Map<String, dynamic> collect() => <String, dynamic>{
    // Display labels (may carry an emoji) are kept for the UI; the API gets the
    // plain names it lists in `hobbies`.
    'interests': selected.toList(),
    'hobbies': selected.map(RegOptions.plain).toList(),
  };
}

class Step15View extends StatefulWidget {
  const Step15View({super.key});
  @override
  State<Step15View> createState() => _Step15ViewState();
}

class _Step15ViewState extends State<Step15View> {
  late final Step15Controller c;

  @override
  void initState() {
    super.initState();
    c = Get.put(Step15Controller());
  }

  @override
  void dispose() {
    Get.delete<Step15Controller>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      stepNumber: 15,
      totalSteps: 18,
      title: 'What are your interests?',
      subtitle: 'Select up to ${RegOptions.maxInterests} interests to make your '
          'profile stand out!',
      busy: c.busy,
      error: c.error,
      primaryLabel: 'Continue',
      onPrimary: c.submit,
      onBack: c.back,
      showSkip: true,
      onSkip: c.skip,
      children: <Widget>[
        Obx(() {
          final List<String> sel = c.selected.toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _InterestsField(count: sel.length, onTap: () => _openSheet(context)),
              if (sel.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.center,
                  children: sel
                      .map((String s) => _SelectedChip(label: s, onRemove: () => c.toggle(s)))
                      .toList(),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (BuildContext ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (BuildContext c2, ScrollController scroll) {
            return Column(
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: BiText('What are your interests?', style: AppTextStyles.subtitle)),
                      Obx(() => Text(
                            '${c.selected.length}/${RegOptions.maxInterests}',
                            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
                          )),
                      const SizedBox(width: AppSpacing.md),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: BiText.inline(
                          'Done',
                          style: AppTextStyles.button.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                    children: <Widget>[
                      for (final MapEntry<String, List<String>> e in c.categories.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: Obx(
                            () => AppChipSelector(
                              label: e.key,
                              options: e.value,
                              selected: c.selected.toList(),
                              requirement: FieldRequirement.optional,
                              onToggle: c.toggle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The tappable "open the interests picker" field.
class _InterestsField extends StatelessWidget {
  const _InterestsField({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color hintColor = Theme.of(context).hintColor;
    return FormFieldContainer(
      label: 'Interests',
      requirement: FieldRequirement.optional,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: count == 0
                    ? BiText.inline(
                        'Select interests',
                        textAlign: TextAlign.start,
                        style: AppTextStyles.body.copyWith(color: hintColor),
                      )
                    : Text(
                        '$count selected',
                        style: AppTextStyles.body.copyWith(color: AppColors.primary),
                      ),
              ),
              Icon(Icons.expand_more_rounded, color: hintColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// A selected-interest chip with a remove button, shown under the field.
class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            RegOptions.plain(label),
            style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
