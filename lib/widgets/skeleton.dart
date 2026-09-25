import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Shimmer-free skeleton placeholder set.
///
/// A single reusable [Skeleton] box plus composed [SkeletonList] rows so every
/// data-driven screen can show structure while loading instead of a bare
/// spinner. Pulse-only (no shader) keeps it cheap on low-end devices, matching
/// the app's performance-first posture.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color base = dark ? AppColors.darkSurfaceAlt : const Color(0xFFECE9EC);
    final Color highlight = dark ? AppColors.darkSurface : const Color(0xFFF7F5F8);

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.45).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.circle ? widget.height : widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
        ),
        // A faint inner highlight gives the bone a soft, premium depth.
        foregroundDecoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[highlight.withValues(alpha: 0.5), Colors.transparent],
          ),
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A list-card skeleton matching the SurfaceCard list pattern (avatar, two
/// text lines, trailing pill). Used by inbox/proposal/shortlist style screens.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6, this.padding});

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: dark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: <Widget>[
            const Skeleton(height: 48, circle: true),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Skeleton(width: 140, height: 13),
                  SizedBox(height: 8),
                  Skeleton(width: double.infinity, height: 11),
                  SizedBox(height: 6),
                  Skeleton(width: 90, height: 11),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Skeleton(width: 56, height: 20, radius: 999),
          ],
        ),
      ),
    );
  }
}

/// Full-width profile-card skeleton for the Discover feed while the first page
/// loads (portrait photo + name + chips + action row).
class SkeletonProfileCard extends StatelessWidget {
  const SkeletonProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : AppColors.lightSurfaceAlt,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Skeleton(width: 150, height: 22, radius: 6),
                  const SizedBox(width: 10),
                  const Skeleton(width: 46, height: 22, radius: 6),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  for (int i = 0; i < 3; i++) ...<Widget>[
                    const Skeleton(width: 76, height: 24, radius: 8),
                    if (i != 2) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  for (int i = 0; i < 4; i++) ...<Widget>[
                    const Expanded(child: Skeleton(height: 44, radius: 10)),
                    if (i != 3) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
