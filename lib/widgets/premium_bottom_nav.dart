import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

/// One destination in [PremiumBottomNav].
class PremiumNavItem {
  const PremiumNavItem({required this.icon, required this.label, IconData? activeIcon})
      : activeIcon = activeIcon ?? icon;

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// A floating, gradient bottom navigation bar with an animated selected pill.
/// Keeps the same index/onTap contract as a standard bottom nav.
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.brandGradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.40),
                blurRadius: 22,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            children: List<Widget>.generate(items.length, (int i) {
              return Expanded(
                child: _NavCell(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({required this.item, required this.selected, required this.onTap});

  final PremiumNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              selected ? item.activeIcon : item.icon,
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.75),
              size: selected ? 24 : 22,
            ),
            // Label appears only for the selected item (space-efficient, premium).
            Flexible(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
