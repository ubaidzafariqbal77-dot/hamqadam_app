import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import 'bilingual_text.dart';

/// A single selectable card (optionally with an icon).
class CardOption {
  const CardOption(this.value, this.label, {this.icon});
  final Object value;
  final String label;
  final IconData? icon;
}

/// Premium single-select card grid used on the account/gender style screens:
/// two cards per row (the last odd one spans full width), a centered icon +
/// bilingual label, and a glowing brand border on the selected card.
class AppCardSelector extends StatelessWidget {
  const AppCardSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.label,
  });

  final List<CardOption> options;
  final Object? selected;
  final ValueChanged<CardOption> onSelect;

  /// Optional centered question label shown above the grid.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    if (label != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BiText(
            label!,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 17),
          ),
        ),
      );
    }
    for (int i = 0; i < options.length; i += 2) {
      final bool hasPair = i + 1 < options.length;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // A lone last card spans the full width (like the mockup); paired
              // cards split the row evenly.
              Expanded(child: _card(context, options[i])),
              if (hasPair) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _card(context, options[i + 1])),
              ],
            ],
          ),
        ),
      );
      if (i + 2 < options.length) rows.add(const SizedBox(height: AppSpacing.md));
    }
    return Column(children: rows);
  }

  Widget _card(BuildContext context, CardOption o) {
    final bool isSelected = selected == o.value;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color base = dark ? AppColors.requiredFieldBackgroundDark : AppColors.optionalFieldBackgroundLight;
    final Color labelColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.lightTextPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelect(o),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.10) : base,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.primaryDark,
              width: isSelected ? 1.6 : 1.1,
            ),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 18,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (o.icon != null) ...<Widget>[
                Icon(
                  o.icon,
                  size: 28,
                  color: isSelected ? AppColors.primary : AppColors.primaryLight,
                ),
                const SizedBox(height: 8),
              ],
              BiText(
                o.label,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 15,
                  color: isSelected ? AppColors.primary : labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
