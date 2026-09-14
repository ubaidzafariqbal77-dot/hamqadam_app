import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

/// The app's standard content card.
///
/// Extracted from the pattern the Profile screen established so the newer
/// screens (verification, interests, preferences) look identical instead of
/// each inventing its own elevation and border.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: dark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: dark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                  spreadRadius: -6,
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Icon + title row used at the top of a [SurfaceCard].
class CardTitle extends StatelessWidget {
  const CardTitle({super.key, required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      // Small icon container so every card header reads at the same weight.
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: AppRadius.smAll,
        ),
        child: Icon(icon, size: AppDimensions.iconSm, color: AppColors.primary),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          title,
          style: AppTextStyles.subtitle.copyWith(
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

/// Small status pill — verified badges, interest statuses, filter chips.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppTextStyles.badge.copyWith(color: color)),
        ],
      ),
    );
  }
}
