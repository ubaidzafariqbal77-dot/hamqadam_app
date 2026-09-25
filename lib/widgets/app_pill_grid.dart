import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';
import 'bilingual_text.dart';

/// Thin-stroke line-art glyphs for the Family financial status reference
/// (crown / diamond / house / sprout), matched on the server's wording so a
/// renamed or reordered list still draws the right mark. Unknown values fall
/// back to the house.
IconData financialGlyph(String name) {
  final String n = name.toLowerCase();
  if (n.contains('elite') || n.contains('establish')) {
    return Icons.workspace_premium_outlined;
  }
  if (n.contains('high') || n.contains('afflu')) return Icons.diamond_outlined;
  if (n.contains('aspir') || n.contains('grow')) return Icons.eco_outlined;
  return Icons.home_outlined; // middle / stable
}

/// One choice tile in the reference's financial-status grid: a soft rounded
/// card with a thin rose line-art glyph above a centred label, and a dusty-rose
/// wash when chosen (the reference's selected "Established").
class FinancialOptionCard extends StatelessWidget {
  const FinancialOptionCard({
    super.key,
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
    final Color ink =
        Theme.of(context).textTheme.bodyLarge?.color ??
        AppColors.lightTextPrimary;
    final Color glyph = selected
        ? (dark ? AppColors.darkTextPrimary : AppColors.regAccent)
        : dark
        ? AppColors.darkTextSecondary
        : AppColors.regAccent.withValues(alpha: 0.85);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? (dark
                      ? AppColors.primary.withValues(alpha: 0.30)
                      : AppColors.roseSelectedFill)
                : (dark ? AppColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? (dark ? AppColors.primary : AppColors.roseSelectedBorder)
                  : (dark ? AppColors.darkBorder : AppColors.roseFieldBorder),
              width: selected ? 1.4 : 1.1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFB4487B).withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(financialGlyph(label), size: 34, color: glyph),
              const SizedBox(height: 10),
              BiText(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? (dark
                            ? AppColors.darkTextPrimary
                            : AppColors.roseSelectedInk)
                      : ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice in the reference's two-column pill grid ("Preferred marital
/// status"): a compact text pill — white with a soft pink hairline normally,
/// filled dusty rose with dark ink when chosen.
class PillOption {
  const PillOption(this.value, this.label);

  final Object value;
  final String label;
}

/// The reference design's option grid for choice questions: a centered section
/// label above a two-column grid of compact pills, measured off the "Preferred
/// marital status" mockup (~56pt tall, 16pt radius, no icon discs). A lone
/// last pill spans the full width, like the mockup.
class AppPillGrid extends StatelessWidget {
  const AppPillGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.label,
    this.labelStyle,
    this.checkWhenSelected = false,
  });

  final List<PillOption> options;
  final Object? selected;
  final ValueChanged<PillOption> onSelect;

  /// Centered section label above the grid (e.g. "Preferred marital status").
  final String? label;

  /// Overrides the default section-label style — the Family-details reference
  /// draws its question headings in the serif rose tone.
  final TextStyle? labelStyle;

  /// Draws a small circled check before the chosen pill's label (the Family
  /// details reference's selected "Yes").
  final bool checkWhenSelected;

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
            style: labelStyle ?? AppTextStyles.subtitle.copyWith(fontSize: 17),
          ),
        ),
      );
    }
    for (int i = 0; i < options.length; i += 2) {
      final bool hasPair = i + 1 < options.length;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _pill(context, options[i])),
            if (hasPair) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _pill(context, options[i + 1])),
            ] else ...<Widget>[
              // A lone last pill keeps its half-width, matching the mockup's
              // grid instead of stretching across the card.
              const SizedBox(width: AppSpacing.md),
              const Expanded(child: SizedBox.shrink()),
            ],
          ],
        ),
      );
      if (i + 2 < options.length) {
        rows.add(const SizedBox(height: AppSpacing.md));
      }
    }
    return Column(children: rows);
  }

  Widget _pill(BuildContext context, PillOption o) {
    final bool isSelected = selected == o.value;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink =
        Theme.of(context).textTheme.bodyLarge?.color ??
        AppColors.lightTextPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onSelect(o),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 56,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: isSelected && checkWhenSelected && !dark
                ? const LinearGradient(colors: AppColors.regPrimaryGradient)
                : null,
            color: isSelected
                ? (dark
                      ? AppColors.primary.withValues(alpha: 0.30)
                      : checkWhenSelected
                      ? null
                      : AppColors.roseSelectedFill)
                : (dark ? AppColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? (dark
                        ? AppColors.primary
                        : checkWhenSelected
                        ? Colors.transparent
                        : AppColors.roseSelectedBorder)
                  : (dark ? AppColors.darkBorder : AppColors.roseFieldBorder),
              width: 1.2,
            ),
            boxShadow: isSelected && checkWhenSelected && !dark
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.regAccent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (checkWhenSelected && isSelected) ...<Widget>[
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: dark ? AppColors.darkTextPrimary : Colors.white,
                  ),
                  const SizedBox(width: 6),
                ],
                BiText(
                  o.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (checkWhenSelected
                              ? (dark
                                    ? AppColors.darkTextPrimary
                                    : Colors.white)
                              : dark
                              ? AppColors.darkTextPrimary
                              : AppColors.roseSelectedInk)
                        : ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
