import 'package:flutter/material.dart';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// One destination in [PremiumBottomNav].
class PremiumNavItem {
  const PremiumNavItem({
    required this.icon,
    required this.label,
    IconData? activeIcon,
    this.badge = 0,
  }) : activeIcon = activeIcon ?? icon;

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Unread count rendered as a small bubble on the icon (0 hides it).
  final int badge;
}

/// A floating, gradient bottom navigation bar with an animated selected pill.
/// Keeps the same index/onTap contract as a standard bottom nav.
///
/// Coloured with the registration flow's muted rose gradient so the shell
/// matches the screens it frames.
class PremiumBottomNav extends StatelessWidget {
  const PremiumBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PremiumNavItem> items;

  static const Color _idle = Color(0xFFB98AA0);

  /// Selected tab: a raised brand-gradient orb with a white icon, sitting in
  /// the bar's animated curved notch.
  Widget _orb(PremiumNavItem item) => Transform.translate(
        // Sit the orb lower in the notch: the package floats it high.
        offset: const Offset(0, 12),
        child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFE5728F), AppColors.primaryDark, AppColors.primaryInk],
          ),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primaryInk.withValues(alpha: 0.40),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Icon(item.activeIcon, color: Colors.white, size: 26),
            if (item.badge > 0)
              Positioned(top: 4, right: 2, child: _Badge(count: item.badge, onDark: true)),
          ],
        ),
        ),
      );

  /// Resting tab: quiet rose icon with its label.
  Widget _rest(PremiumNavItem item) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(item.icon, color: _idle, size: 23),
                if (item.badge > 0)
                  Positioned(top: -6, right: -10, child: _Badge(count: item.badge)),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: _idle,
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final double inset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x26B25C82),
            blurRadius: 24,
            offset: Offset(0, -2),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CurvedNavigationBar(
            index: currentIndex,
            height: 64,
            color: Colors.white,
            buttonBackgroundColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            animationCurve: Curves.easeOutCubic,
            animationDuration: const Duration(milliseconds: 420),
            onTap: onTap,
            items: <Widget>[
              for (int i = 0; i < items.length; i++)
                i == currentIndex ? _orb(items[i]) : _rest(items[i]),
            ],
          ),
          // Fill the home-indicator inset so the white bar reaches the edge.
          Container(height: inset * 0.6, color: Colors.white),
        ],
      ),
    );
  }
}

/// Unread bubble for nav icons. Deliberately sits outside the pink bar's
/// language: white with an ink count, so it reads as a notification, not as
/// part of the selected pill.
class _Badge extends StatelessWidget {
  const _Badge({required this.count, this.onDark = false});

  final int count;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : AppColors.primaryInk,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white, width: 1.4),
      ),
      constraints: const BoxConstraints(minWidth: 17),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: onDark ? AppColors.primaryInk : Colors.white,
          fontSize: 9,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
