import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/routes/app_routes.dart';

/// The filter module's entry points, as one scrollable strip under the search
/// bar: Swipe Matching, Interest-Based, New Profiles, Recently Viewed,
/// Search History and Saved Searches.
///
/// These screens existed as endpoints before they existed as screens — a member
/// had no way to reach them. A strip rather than a menu because each one is a
/// different way to browse (judge a card, follow your interests, see who is
/// new, go back to somebody, re-run a search), and a menu would hide all six
/// behind one tap.
class DiscoverShortcuts extends StatelessWidget {
  const DiscoverShortcuts({super.key});

  static const List<_Shortcut> _items = <_Shortcut>[
    _Shortcut(
      label: 'Swipe',
      icon: Icons.style_rounded,
      route: AppRoutes.swipeMatching,
    ),
    _Shortcut(
      label: 'Interest-Based',
      icon: Icons.interests_rounded,
      route: AppRoutes.interestMatches,
    ),
    _Shortcut(
      label: 'New Profiles',
      icon: Icons.fiber_new_rounded,
      route: AppRoutes.newProfiles,
    ),
    _Shortcut(
      label: 'Recently Viewed',
      icon: Icons.visibility_outlined,
      route: AppRoutes.recentlyViewed,
    ),
    _Shortcut(
      label: 'Search History',
      icon: Icons.history_rounded,
      route: AppRoutes.searchHistory,
    ),
    _Shortcut(
      label: 'Saved Searches',
      icon: Icons.bookmark_rounded,
      route: AppRoutes.savedSearches,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (BuildContext ctx, int i) => _ShortcutChip(item: _items[i]),
      ),
    );
  }
}

class _Shortcut {
  const _Shortcut({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.item});

  final _Shortcut item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () => Get.toNamed<dynamic>(item.route),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.chatCardFill,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.chatCardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            child: Row(
              children: <Widget>[
                Icon(item.icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.roseTitleInk,
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
