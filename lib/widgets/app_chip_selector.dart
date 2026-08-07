import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import '../models/lookup_item_model.dart';
import 'bilingual_text.dart';
import 'form_field_container.dart';

/// Multi-select chip group for a fixed list of string options.
class AppChipSelector extends StatelessWidget {
  const AppChipSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.requirement = FieldRequirement.optional,
    this.errorText,
  });

  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final FieldRequirement requirement;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FieldLabel(label: label, requirement: requirement),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: options.map((String o) {
            final bool isSelected = selected.contains(o);
            return _Chip(label: o, selected: isSelected, onTap: () => onToggle(o));
          }).toList(),
        ),
        if ((errorText ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(errorText!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
      ],
    );
  }
}

/// Single-select chip group (radio-like).
class AppSingleChipSelector extends StatelessWidget {
  const AppSingleChipSelector({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onSelect,
    this.requirement = FieldRequirement.required,
    this.errorText,
  });

  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onSelect;
  final FieldRequirement requirement;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FieldLabel(label: label, requirement: requirement),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: options
              .map((String o) => _Chip(label: o, selected: value == o, onTap: () => onSelect(o)))
              .toList(),
        ),
        if ((errorText ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(errorText!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
      ],
    );
  }
}

/// Single-select chip group backed by id-carrying [LookupItem] options
/// (e.g. account-for, gender, marital status). Used for local option lists that
/// do not come from the network.
class AppIdChipSelector extends StatelessWidget {
  const AppIdChipSelector({
    super.key,
    this.label,
    required this.options,
    required this.selectedId,
    required this.onSelect,
    this.errorText,
    this.requirement = FieldRequirement.required,
  });

  final String? label;
  final List<LookupItem> options;
  final int? selectedId;
  final ValueChanged<LookupItem> onSelect;
  final String? errorText;
  final FieldRequirement requirement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (label != null) FieldLabel(label: label!, requirement: requirement),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: options
              .map(
                (LookupItem o) => _Chip(
                  label: o.name,
                  selected: selectedId == o.id,
                  onTap: () => onSelect(o),
                ),
              )
              .toList(),
        ),
        if ((errorText ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(errorText!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // Responsive cap: a chip can never be wider than the content area, so a long
    // label wraps instead of overflowing (e.g. when a check icon is added on
    // selection). Uses GetX's screen width.
    final double maxWidth = (Get.width - (AppSpacing.lg * 2) - 4).clamp(120.0, 640.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          constraints: BoxConstraints(minHeight: 48, maxWidth: maxWidth),
          decoration: BoxDecoration(
            gradient: selected ? const LinearGradient(colors: AppColors.brandGradient) : null,
            color: selected
                ? null
                : (dark
                      ? AppColors.requiredFieldBackgroundDark
                      : AppColors.requiredFieldBackgroundLight),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : Theme.of(context).dividerColor,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: BiText(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: selected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  urduColor: selected
                      ? Colors.white.withValues(alpha: 0.9)
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
