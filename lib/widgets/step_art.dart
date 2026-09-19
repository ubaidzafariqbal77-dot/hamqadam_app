import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Decorative watercolour illustration at the top of every registration step
/// (reference design). Each step names its artwork with [asset]; until the
/// real files are dropped into `assets/images/` a soft glow icon keeps the
/// layout intact so the flow never renders a broken-image box.
///
/// Drop the real artwork later at the same path — no code change needed.
class StepArt extends StatelessWidget {
  const StepArt({super.key, required this.asset, this.icon, this.height = 132});

  /// Asset path, e.g. `assets/images/step_faith.png`.
  final String asset;

  /// Shown inside the soft glow while the real artwork is not in the bundle.
  final IconData? icon;

  final double height;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: height,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          // The per-step artwork is not in the bundle yet: show the shared
          // placeholder image (replace the step_*.png files when ready) and
          // only fall back to the soft glow if even that is missing.
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/onboard.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _GlowFallback(icon: icon),
          ),
        ),
      ),
    );
  }
}

class _GlowFallback extends StatelessWidget {
  const _GlowFallback({this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.08),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 34,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Icon(
        icon ?? Icons.favorite_rounded,
        size: 44,
        color: AppColors.primary.withValues(alpha: 0.7),
      ),
    );
  }
}
