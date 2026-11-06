import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// The Discover screen's white reference AppBar, now app-wide.
///
/// Every screen used to draw the dusty-rose gradient bar; the Discover
/// redesign moved to the HTML reference's sticky white header — serif pink
/// title, gray subtitle, soft-pink icon chips — and the same treatment now
/// applies everywhere so the app reads as one family again. Dark text on
/// white, a hairline shadow, and actions drawn in the soul-pink ink.
///
/// Drop-in for `Scaffold.appBar` — the constructor is unchanged, so no call
/// site needed edits.
class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PremiumAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 14);

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        // Frosted-glass circle chips for back / menu / action icons.
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.55),
            foregroundColor: AppColors.primaryInk,
            fixedSize: const Size(40, 40),
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            shape: CircleBorder(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
        ),
      ),
      child: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: kToolbarHeight + 14,
        centerTitle: centerTitle,
        leading: leading == null
            ? null
            : Padding(padding: const EdgeInsets.only(left: 12), child: Center(child: leading)),
        leadingWidth: leading == null ? null : 56,
        iconTheme: const IconThemeData(color: AppColors.primaryInk, size: 22),
        actionsIconTheme: const IconThemeData(color: AppColors.primaryInk, size: 22),
        actionsPadding: const EdgeInsets.only(right: 12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        flexibleSpace: const PremiumBarBackground(),
        title: PremiumBarTitle(
          title: title,
          subtitle: subtitle,
          center: centerTitle,
        ),
        actions: actions == null
            ? null
            : <Widget>[
                for (final Widget a in actions!)
                  Padding(padding: const EdgeInsets.only(left: 8), child: a),
              ],
      ),
    );
  }
}

/// Brand-gradient sheet behind every premium header: rose → dusty rose →
/// ink, rounded bottom corners, soft bokeh orbs, a faint heart watermark and
/// a slow one-time shimmer sweep.
class PremiumBarBackground extends StatelessWidget {
  const PremiumBarBackground({super.key});

  static const BorderRadius _radius = BorderRadius.vertical(bottom: Radius.circular(28));

  Widget _orb(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: alpha),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        // The app's own brand pastel (same gradient as buttons / cards).
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.regPrimaryGradient,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x40B25C82),
            blurRadius: 22,
            offset: Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Stack(
          children: <Widget>[
            Positioned(top: -40, right: -30, child: _orb(150, 0.22)),
            Positioned(bottom: -50, left: -20, child: _orb(120, 0.16)),
            Positioned(top: 10, left: 140, child: _orb(40, 0.18)),
            Positioned(
              right: 70,
              bottom: 6,
              child: Icon(Icons.favorite_rounded, size: 34, color: Colors.white.withValues(alpha: 0.35)),
            ),
            Positioned(
              right: 22,
              top: 18,
              child: Icon(Icons.favorite_rounded, size: 16, color: Colors.white.withValues(alpha: 0.45)),
            ),
            // One gentle shimmer sweep on first paint.
            Positioned.fill(
              child: const SizedBox.expand()
                  .animate()
                  .shimmer(
                    delay: 250.ms,
                    duration: 1600.ms,
                    color: Colors.white.withValues(alpha: 0.45),
                    angle: 0.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White serif title + spaced caps subtitle, sliding/fading in.
class PremiumBarTitle extends StatelessWidget {
  const PremiumBarTitle({super.key, required this.title, this.subtitle, this.center = false});

  final String title;
  final String? subtitle;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: AppTextStyles.displaySerif.copyWith(
            color: AppColors.primaryInk,
            fontSize: 22,
            height: 1.15,
          ),
        ),
        if ((subtitle ?? '').isNotEmpty) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            subtitle!.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryDark,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 380.ms).slideX(begin: -0.06, end: 0, curve: Curves.easeOutCubic);
  }
}
