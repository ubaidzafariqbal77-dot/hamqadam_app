import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// The registration flow's icon treatment: a rounded-square container on the
/// brand gradient with a soft rose glow and a white rounded glyph. Replaces
/// the old raster illustrations so every step reads in one visual language.
///
/// [soft] draws the quieter variant (blush fill, rose glyph) used for list
/// rows and unselected cards; [selected] lifts a soft badge to the gradient.
class RegIconBadge extends StatelessWidget {
  const RegIconBadge({
    super.key,
    required this.icon,
    this.size = 44,
    this.soft = false,
    this.selected = false,
  });

  final IconData icon;
  final double size;
  final bool soft;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool filled = !soft || selected;
    final double radius = size * 0.32;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: filled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.primaryLight,
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
                stops: <double>[0, 0.45, 1],
              )
            : null,
        color: filled
            ? null
            : (dark
                ? AppColors.primary.withValues(alpha: 0.14)
                : AppColors.primaryLight),
        border: filled
            ? Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1)
            : null,
        boxShadow: filled
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.28),
                  blurRadius: size * 0.36,
                  offset: Offset(0, size * 0.12),
                  spreadRadius: -size * 0.06,
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: filled ? Colors.white : AppColors.primaryDark,
      ),
    );
  }
}

/// Large hero version shown above each step title: the badge sitting inside
/// a faint blush halo.
class RegHeroIcon extends StatelessWidget {
  const RegHeroIcon({super.key, required this.icon, this.size = 68});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, double s, Widget? child) => Transform.scale(scale: s, child: child),
        child: Container(
          padding: EdgeInsets.all(size * 0.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryLight.withValues(alpha: 0.55),
          ),
          child: RegIconBadge(icon: icon, size: size),
        ),
      ),
    );
  }
}
