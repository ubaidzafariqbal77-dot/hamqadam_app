import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../models/public_profile_model.dart';
import '../../../repositories/profile_repository.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/interest_controller.dart';
import '../../../controllers/notification_controller.dart';
import '../../../controllers/proposal_controller.dart';
import '../../../controllers/proposal_extra_controller.dart';
import '../../../controllers/search_profiles_controller.dart';

import '../../../core/api/api_response.dart';
import '../../../core/routes/app_routes.dart' as routes;
import '../../../models/chat_model.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';
import '../../auth/views/home_view.dart';
import '../../chat/views/chat_conversation_view.dart';
import '../../notifications/views/notifications_view.dart';
import '../widgets/public_profile_detail_sheet.dart';
import '../widgets/report_profile_dialog.dart';
import '../widgets/trust_verification_sheet.dart';
import '../widgets/horoscope_form_sheet.dart';
import '../widgets/search_filter_bottom_sheet.dart';
import '../widgets/send_interest_dialog.dart';
import 'ignored_profiles_view.dart';
import '../../proposals/widgets/send_proposal_dialog.dart';

class DiscoverView extends StatelessWidget {
  const DiscoverView({super.key});

  @override
  Widget build(BuildContext context) {
    final SearchProfilesController controller =
        Get.find<SearchProfilesController>();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      // SafeArea keeps the white header below the notch/status bar — the
      // reference design starts its header under the system bar.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _Soul.pink600,
          backgroundColor: Colors.white,
          onRefresh: controller.reload,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification n) {
              // Infinite scroll: start fetching the next page before the end.
              if (n.metrics.extentAfter < 400) {
                controller.loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                // Top Search & Filter Bar — the HTML reference's white header:
                // menu · serif "Discover / CHOOSE FOREVER" · bell, then the
                // search row with the pink-gradient sliders button. Horoscope
                // and partner-preference buttons stay in the icon row.
                SliverToBoxAdapter(
                  child: _SearchBarHeader(controller: controller),
                ),
                // Category chips: AI Matches (active, pink gradient) · Nearby ·
                // New Profiles · Verified — the reference's filter strip.
                SliverToBoxAdapter(
                  child: _CategoryChips(controller: controller),
                ),
                // The filter module's own screens live in the category strip
                // above (one scrollable row).
                // "Recommended for You / Based on your preferences / See All".
                const SliverToBoxAdapter(child: _RecommendedHeader()),
                // Active Filter Chips (if any filters applied)
                SliverToBoxAdapter(
                  child: _ActiveFilterChips(controller: controller),
                ),
                // AI Filtered toggle — narrows the feed to the matchmaking
                // model's top 5 matches for this member.
                SliverToBoxAdapter(
                  child: _AiFilteredBar(controller: controller),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xs),
                ),
                // The profile list and every load state.
                _FeedSlivers(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The HTML reference's colour set — the "soul" pink ramp, inks and the two
/// gradients the screen reuses. Named in one place so every widget below reads
/// like the Tailwind config it was ported from.
abstract class _Soul {
  static const Color pink100 = Color(0xFFFBE3EC);
  static const Color pink300 = Color(0xFFEDA6C2);
  static const Color pink400 = Color(0xFFF2B0C9);
  static const Color pink500 = Color(0xFFF4BFD1);
  static const Color pink600 = Color(0xFFF4BFD1);

  /// Deep dusty-rose ink for text/icons drawn ON the pastel accent —
  /// white is unreadable on a fill this light.
  static const Color pinkInk = Color(0xFF8E3D60);

  static const Color ink900 = Color(0xFF151515);
  static const Color ink500 = Color(0xFF777777);
  static const Color ink50 = Color(0xFFF8F8F8);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray100 = Color(0xFFF3F4F6);

  /// `pink-gradient`: linear 135deg #ff0f4d → #ff315f 55% → #ff6688.
  static const LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[pink600, pink500, pink400],
    stops: <double>[0.0, 0.55, 1.0],
  );

  /// `shadow-card`: 0 4px 18px rgba(255,15,77,.07), 0 2px 6px rgba(0,0,0,.04).
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x12B25C82), blurRadius: 18, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// `shadow-pink`: 0 5px 18px rgba(178,92,130,.25).
  static const List<BoxShadow> pinkShadow = <BoxShadow>[
    BoxShadow(color: Color(0x40B25C82), blurRadius: 18, offset: Offset(0, 5)),
  ];
}

// ---------------------------------------------------------------------------
// Search & Filter Header
// ---------------------------------------------------------------------------

class _SearchBarHeader extends StatelessWidget {
  const _SearchBarHeader({required this.controller});

  final SearchProfilesController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    // The HTML reference's header: white sticky bar with the icon row on top
    // (menu · serif logo · notification — plus the app's horoscope and
    // partner-preference buttons kept beside them) and the full-width search
    // row with the pink-gradient sliders button underneath. Every button keeps
    // its existing behaviour.
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        12,
      ),
      child: Column(
        children: <Widget>[
          _buildIconRow(context, theme, isDark),
          const SizedBox(height: 12),
          _buildSearchField(context, theme, isDark),
        ],
      ),
    );
  }

  /// Drawer (left) · serif "Discover / CHOOSE FOREVER" logo (centre) · the
  /// remaining live actions (horoscope, partner-preference, notification)
  /// grouped on the RIGHT — one icon each side of the title only, so the bar
  /// reads menu → title → tools.
  Widget _buildIconRow(BuildContext context, ThemeData theme, bool isDark) {
    return Row(
      children: <Widget>[
        _buildMenuButton(context, isDark),
        const Expanded(
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.favorite_rounded, color: _Soul.pink600, size: 15),
                  SizedBox(width: 4),
                  Text(
                    'Discover',
                    style: TextStyle(
                      fontFamily: AppTextStyles.displayFont,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: _Soul.pink600,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 3),
              Text(
                'CHOOSE FOREVER',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  color: _Soul.gray400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildHoroscopeButton(isDark),
        const SizedBox(width: AppSpacing.sm),
        _buildPartnerPrefButton(isDark),
        const SizedBox(width: AppSpacing.sm),
        _buildNotificationButton(context, isDark),
      ],
    );
  }

  /// The 36 px soft-pink circle menu chip from the reference — opens the
  /// home shell's drawer. The shell's AppBar is suppressed on this tab, so
  /// the plain Scaffold.of(context) lookup can't find a drawer from inside
  /// the nested Discover scaffold; the shell's GlobalKey reaches it directly.
  Widget _buildMenuButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        final ScaffoldState? shell =
            HomeView.shellKey.currentState ?? Scaffold.maybeOf(context);
        if (shell != null) {
          shell.openDrawer();
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF1F4),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.menu_rounded, color: _Soul.pink600, size: 19),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, ThemeData theme, bool isDark) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: _Soul.ink50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Soul.gray200),
            ),
            child: TextField(
              controller: controller.searchInputController,
              onChanged: controller.onSearchChanged,
              // The magnifier key on the keyboard commits the query immediately
              // and reloads — the field used to rely on the 500 ms debounce
              // alone, which read as a dead button.
              textInputAction: TextInputAction.search,
              onSubmitted: controller.submitSearch,
              style: const TextStyle(fontSize: 12, color: _Soul.ink900),
              cursorColor: _Soul.pink600,
              decoration: InputDecoration(
                hintText: 'Search name, city, profession...',
                hintStyle: const TextStyle(fontSize: 11, color: _Soul.gray400),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _Soul.gray400,
                  size: 17,
                ),
                suffixIcon: Obx(() {
                  final bool hasText =
                      controller.filter.value.searchQuery?.isNotEmpty == true;
                  if (!hasText) return const SizedBox.shrink();
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: _Soul.ink500,
                    ),
                    onPressed: controller.clearSearchQuery,
                  );
                }),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildFilterButton(context, isDark),
      ],
    );
  }

  Widget _buildFilterButton(BuildContext context, bool isDark) {
    return Obx(() {
      final int filterCount = controller.activeFilterCount;
      final bool hasFilters = filterCount > 0;

      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // The reference's 40 px pink-gradient sliders chip.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => SearchFilterBottomSheet.show(context),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: _Soul.pinkGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _Soul.pinkShadow,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: _Soul.pinkInk,
                  size: 19,
                ),
              ),
            ),
          ),
          if (hasFilters)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: _Soul.pink600,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 1.5),
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    '$filterCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildNotificationButton(BuildContext context, bool isDark) {
    return Obx(() {
      final NotificationController? notifCtrl =
          Get.isRegistered<NotificationController>()
          ? Get.find<NotificationController>()
          : null;
      final int unread = notifCtrl?.unreadCount.value ?? 0;
      return GestureDetector(
        onTap: () => Get.to(() => const NotificationsView()),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF1F4),
            shape: BoxShape.circle,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: _Soul.pink600,
                  size: 19,
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: _Soul.pink600,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  /// Horoscope — restyled to the reference's 36 px soft-pink circle, same
  /// behaviour.
  Widget _buildHoroscopeButton(bool isDark) {
    return GestureDetector(
      onTap: () => HoroscopeFormSheet.show(Get.context!),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF1F4),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: _Soul.pink600,
          size: 18,
        ),
      ),
    );
  }

  /// Partner-preference toggle — reference's soft-pink circle; the pink fill
  /// marks it active.
  Widget _buildPartnerPrefButton(bool isDark) {
    return Obx(() {
      final bool active = controller.filter.value.partnerPreferenceFilter;
      return GestureDetector(
        onTap: controller.togglePartnerPreferenceFilter,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active ? _Soul.pink600 : const Color(0xFFFFF1F4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.favorite_outline_rounded,
            color: active ? _Soul.pinkInk : _Soul.pink600,
            size: 18,
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Category chips — the HTML reference's filter strip, ONE horizontally
// scrollable row under the search bar: the active AI Matches pill in the pink
// gradient, the rest white with a gray hairline. AI Matches reuses the
// existing AI Filtered toggle; Nearby and Verified reuse the filter model's
// own flags; New Profiles and the filter-module shortcuts (Swipe,
// Interest-Based, Recently Viewed, Search History, Saved Searches) route to
// their existing screens — all entry points survive, in one strip.
// ---------------------------------------------------------------------------

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.controller});

  final SearchProfilesController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.md, 4),
      child: SizedBox(
        height: 32,
        child: Obx(() {
          final SearchFilterModel f = controller.filter.value;
          final bool aiActive = controller.aiFiltered.value;
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            children: <Widget>[
              _CategoryChip(
                label: 'AI Matches',
                icon: Icons.auto_awesome_rounded,
                active: aiActive,
                onTap: controller.toggleAiFiltered,
              ),
              _CategoryChip(
                label: 'Nearby',
                active: f.nearby,
                onTap: () => controller.applyFilter(
                  controller.filter.value.copyWith(nearby: !f.nearby),
                ),
              ),
              _CategoryChip(
                label: 'New Profiles',
                onTap: () => Get.toNamed<dynamic>(routes.AppRoutes.newProfiles),
              ),
              _CategoryChip(
                label: 'Verified',
                icon: Icons.verified_rounded,
                active: f.verifiedOnly,
                onTap: () => controller.applyFilter(
                  controller.filter.value.copyWith(
                    verifiedOnly: !f.verifiedOnly,
                  ),
                ),
              ),
              // The filter module's own screens, same strip so nothing hides
              // behind a second row: swiping, interests, history, recently
              // viewed and saved searches.
              _CategoryChip(
                label: 'Swipe',
                icon: Icons.style_rounded,
                onTap: () => Get.toNamed<dynamic>(routes.AppRoutes.swipeMatching),
              ),
              _CategoryChip(
                label: 'Interest-Based',
                icon: Icons.interests_rounded,
                onTap: () => Get.toNamed<dynamic>(routes.AppRoutes.interestMatches),
              ),
              _CategoryChip(
                label: 'Recently Viewed',
                icon: Icons.visibility_outlined,
                onTap: () => Get.toNamed<dynamic>(routes.AppRoutes.recentlyViewed),
              ),
              _CategoryChip(
                label: 'Search History',
                icon: Icons.history_rounded,
                onTap: () => Get.toNamed<dynamic>(routes.AppRoutes.searchHistory),
              ),
              _CategoryChip(
                label: 'Saved Searches',
                icon: Icons.bookmark_rounded,
                onTap: () => Get.toNamed<dynamic>(routes.AppRoutes.savedSearches),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.onTap,
    this.active = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: active ? _Soul.pinkGradient : null,
              color: active ? null : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: active
                  ? Border.all(color: Colors.transparent)
                  : Border.all(color: _Soul.gray200),
              boxShadow: active ? _Soul.pinkShadow : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    size: 12,
                    color: active ? _Soul.pinkInk : _Soul.pink600,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? _Soul.pinkInk : _Soul.gray600,
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

// ---------------------------------------------------------------------------
// "Recommended for You / Based on your preferences / See All" — the section
// header between the chips and the feed. See All resets the filters back to
// the full listing.
// ---------------------------------------------------------------------------

class _RecommendedHeader extends StatelessWidget {
  const _RecommendedHeader();

  @override
  Widget build(BuildContext context) {
    final SearchProfilesController controller =
        Get.find<SearchProfilesController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Recommended for You',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _Soul.ink900,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Based on your preferences',
                style: TextStyle(fontSize: 9, color: _Soul.gray400),
              ),
            ],
          ),
          GestureDetector(
            onTap: controller.resetFilter,
            child: const Text(
              '',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _Soul.pink600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Filtered Bar — toggle that narrows the feed to the matchmaking model's
// top 5 matches for this member, with a live count pill while active.
// ---------------------------------------------------------------------------

class _AiFilteredBar extends StatelessWidget {
  const _AiFilteredBar({required this.controller});

  final SearchProfilesController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Obx(() {
      final bool active = controller.aiFiltered.value;

      return Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.md, 2, AppSpacing.md, 4),
        child: Row(
          children: <Widget>[
            Expanded(child: _buildButton(theme, isDark, active)),
          ],
        ),
      );
    });
  }

  Widget _buildButton(ThemeData theme, bool isDark, bool active) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: controller.toggleAiFiltered,
        borderRadius: AppRadius.lgAll,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: <Color>[Color(0xFF6A3DE8), Color(0xFF9B4DCA)],
                  )
                : null,
            color: active
                ? null
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : (isDark ? AppColors.darkBorder : AppColors.lightDivider),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: active
                    ? const Color(0xFF6A3DE8).withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: active ? 10 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: active ? Colors.white : AppColors.gold,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Filtered',
                style: TextStyle(
                  color: active
                      ? Colors.white
                      : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              if (active) ...<Widget>[
                const SizedBox(width: 8),
                _buildCountPill(),
                const Spacer(),
                Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ] else ...<Widget>[
                const Spacer(),
                Text(
                  'Top 5',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Total AI matches available (up to 5) for the pill while the mode is on.
  Widget _buildCountPill() {
    final int shown = controller.aiFilteredProfiles.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$shown',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          height: 1.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active Filter Chips Bar
// ---------------------------------------------------------------------------

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({required this.controller});

  final SearchProfilesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final SearchFilterModel f = controller.filter.value;
      final List<_FilterChipItem> chips = <_FilterChipItem>[];

      if (f.ageMin != null || f.ageMax != null) {
        final int min = f.ageMin ?? 18;
        // A null upper bound means the slider sat at its top (70+) — say so
        // instead of the old hardcoded "60", which contradicted the slider.
        final String label = f.ageMax == null
            ? 'Age: $min+'
            : 'Age: $min-${f.ageMax}';
        chips.add(
          _FilterChipItem(
            label: label,
            onRemove: () => controller.applyFilter(
              f.copyWith(clearAgeMin: true, clearAgeMax: true),
            ),
          ),
        );
      }
      if (f.verifiedOnly) {
        chips.add(
          _FilterChipItem(
            label: 'Verified Only',
            onRemove: () =>
                controller.applyFilter(f.copyWith(verifiedOnly: false)),
          ),
        );
      }
      if (f.photoOnly) {
        chips.add(
          _FilterChipItem(
            label: 'With Photo',
            onRemove: () =>
                controller.applyFilter(f.copyWith(photoOnly: false)),
          ),
        );
      }
      if (f.compatibilityMin != null && f.compatibilityMin! > 0) {
        chips.add(
          _FilterChipItem(
            label: '${f.compatibilityMin}%+ Match',
            onRemove: () =>
                controller.applyFilter(f.copyWith(clearCompatibilityMin: true)),
          ),
        );
      }
      if (f.nearby) {
        chips.add(
          _FilterChipItem(
            label: 'Nearby',
            onRemove: () => controller.applyFilter(f.copyWith(nearby: false)),
          ),
        );
      }
      if (f.sort != null && f.sort!.isNotEmpty) {
        final String sortLabel = switch (f.sort) {
          'compatibility' => 'Best Match',
          'latest' => 'Recently Active',
          'newest' => 'Newest',
          'age_asc' => 'Young to Old',
          'age_desc' => 'Old to Young',
          _ => f.sort!,
        };
        chips.add(
          _FilterChipItem(
            label: 'Sort: $sortLabel',
            onRemove: () => controller.applyFilter(f.copyWith(clearSort: true)),
          ),
        );
      }
      // Gender is intentionally NOT listed here. It is the opposite-gender
      // rule, and a chip implies a filter the member may remove — tapping the
      // × used to widen Discover to both genders.
      if (f.maritalStatusId != null) {
        final String? m = controller.maritalStatusLabel(f.maritalStatusId);
        if (m != null) {
          chips.add(
            _FilterChipItem(
              label: m,
              onRemove: () =>
                  controller.applyFilter(f.copyWith(clearMaritalStatus: true)),
            ),
          );
        }
      }
      if (f.religionId != null) {
        final String? r = controller.religionLabel(f.religionId);
        if (r != null) {
          chips.add(
            _FilterChipItem(
              label: r,
              onRemove: () =>
                  controller.applyFilter(f.copyWith(clearReligion: true)),
            ),
          );
        }
      }
      if (f.casteId != null) {
        final String? c = controller.casteLabel(f.casteId);
        if (c != null) {
          chips.add(
            _FilterChipItem(
              label: c,
              onRemove: () =>
                  controller.applyFilter(f.copyWith(clearCaste: true)),
            ),
          );
        }
      }
      if (f.cityId != null) {
        final String? city = controller.cityLabel(f.cityId);
        if (city != null) {
          chips.add(
            _FilterChipItem(
              label: city,
              onRemove: () =>
                  controller.applyFilter(f.copyWith(clearCity: true)),
            ),
          );
        }
      }
      if (f.partnerPreferenceFilter) {
        chips.add(
          _FilterChipItem(
            label: 'Partner Match',
            onRemove: () => controller.applyFilter(
              f.copyWith(partnerPreferenceFilter: false),
            ),
          ),
        );
      }

      if (chips.isEmpty) return const SizedBox.shrink();

      return Container(
        height: 34,
        margin: const EdgeInsets.only(bottom: 4),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: chips.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (BuildContext ctx, int i) {
            if (i == chips.length) {
              return ActionChip(
                label: const Text('Clear All'),
                labelStyle: const TextStyle(
                  color: AppColors.error,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: AppColors.error.withValues(alpha: 0.08),
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: controller.resetFilter,
              );
            }
            final _FilterChipItem item = chips[i];
            return Chip(
              label: Text(item.label),
              labelStyle: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              deleteIcon: const Icon(
                Icons.close_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              onDeleted: item.onRemove,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          },
        ),
      );
    });
  }
}

class _FilterChipItem {
  const _FilterChipItem({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;
}

// ---------------------------------------------------------------------------
// Profile feed — slivers of the screen's single scroll view. Search bar,
// shortcuts, filter chips and this list all scroll together now; the old
// fixed-header + full-screen-page deck pinned the header and squeezed the
// cards (the action row overflowed on every phone).
// ---------------------------------------------------------------------------

class _FeedSlivers extends StatefulWidget {
  const _FeedSlivers({required this.controller});

  final SearchProfilesController controller;

  @override
  State<_FeedSlivers> createState() => _FeedSliversState();
}

class _FeedSliversState extends State<_FeedSlivers> {
  /// One key per rendered card, so ignoring a profile can settle the list on
  /// the neighbour that takes its place — the auto-advance the old PageView
  /// gave us, rebuilt for a plain list.
  final Map<int, GlobalKey> _cardKeys = <int, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // The AI Filtered mode renders its own state (AI matches); the
      // normal feed renders the search state.
      final ApiState<SearchProfilesPage> state = widget.controller.displayState;

      switch (state.status) {
        case ApiStatus.initial:
        case ApiStatus.loading:
          // Structure-preserving skeleton instead of a bare spinner.
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Column(
                children: <Widget>[
                  SkeletonProfileCard(),
                  SkeletonProfileCard(),
                ],
              ),
            ),
          );
        case ApiStatus.noInternet:
          return SliverFillRemaining(
            hasScrollBody: false,
            child: NoInternetWidget(onRetry: widget.controller.reload),
          );
        case ApiStatus.unauthorized:
        case ApiStatus.serverError:
        case ApiStatus.validationError:
          return SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorStateWidget(
              message: state.message,
              onRetry: widget.controller.reload,
            ),
          );
        case ApiStatus.empty:
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              title: 'No Matches Found',
              message:
                  state.message ??
                  'No profiles match your current filters. Try relaxing some criteria.',
              onRefresh: widget.controller.reload,
            ),
          );
        case ApiStatus.success:
          return _buildFeed();
      }
    });
  }

  Widget _buildFeed() {
    final List<SearchProfileModel> visible = widget.controller.visibleProfiles;

    if (visible.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyStateWidget(
          title: 'You are all caught up',
          message:
              'No more profiles to show right now. Check back soon or relax your filters.',
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverList(
          delegate: SliverChildBuilderDelegate((BuildContext ctx, int i) {
            final SearchProfileModel profile = visible[i];
            final GlobalKey cardKey = _cardKeys.putIfAbsent(
              profile.id,
              GlobalKey.new,
            );
            return KeyedSubtree(
              key: cardKey,
              child: Padding(
                // The reference list's rhythm: px-4 with a tight 10 px gap
                // between cards (space-y-2.5).
                padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                child: _SingleUserProfileCard(
                  profile: profile,
                  controller: widget.controller,
                  onIgnore: () => _ignore(profile, i),
                ),
              ),
            );
          }, childCount: visible.length),
        ),
        // Tail loader while the next page is on its way (the scroll
        // listener in the body triggers the fetch near the end).
        if (widget.controller.hasMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.regAccent,
                  ),
                ),
              ),
            ),
          ),
        // Clearance for the floating bottom navigation bar.
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }

  void _ignore(SearchProfileModel profile, int index) {
    // The neighbour that takes this slot once the list rebuilds.
    final List<SearchProfileModel> visible = widget.controller.visibleProfiles;
    final GlobalKey? nextKey = index + 1 < visible.length
        ? _cardKeys[visible[index + 1].id]
        : null;

    // Persist on the server (shows in the Ignored list, restorable) AND hide
    // the card from the current feed immediately.
    if (Get.isRegistered<ProposalExtraController>()) {
      Get.find<ProposalExtraController>().ignoreUser(profile.id);
    }
    widget.controller.ignoreProfile(profile.id);
    AppSnackbar.info('Profile ignored. Restore it from the Ignored list.');

    if (nextKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext? ctx = nextKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Profile card — one member in the Discover list.
//
// The reference recipe: a WHITE rounded card on the rose canvas, a rounded-
// square photo on the left, a serif "Name, age" headline, the AI match pill
// and shortlist heart in the top-right, quiet glyph rows for the facts, and
// ONE aligned action row — every icon equal-sized on the same baseline with
// even spacing, the Proposal pill closing the row. The old full-bleed photo
// card with a vertical icon rail overflowed its bottom action row.
// ---------------------------------------------------------------------------

class _SingleUserProfileCard extends StatelessWidget {
  const _SingleUserProfileCard({
    required this.profile,
    required this.controller,
    required this.onIgnore,
  });

  final SearchProfileModel profile;
  final SearchProfilesController controller;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final InterestController? interestCtrl =
        Get.isRegistered<InterestController>()
        ? Get.find<InterestController>()
        : null;

    final String? religion = controller.religionLabel(profile.religionId);
    final String? city = controller.cityLabel(profile.cityId);
    final String? sect = controller.sectLabel(profile.sectMainId);
    final String? school = controller.schoolOfThoughtLabel(profile.schoolOfThoughtId);
    final String? education = controller.educationLabel(profile);
    final String? profession = controller.professionLabel(profile);
    final String? family = controller.familyLabel(profile);

    final String heightLabel = profile.heightFormatted ?? '';
    // The API's real compatibility score — or nothing. A fabricated 80/70%
    // told every member the same lie about every profile, and the pill only
    // means something when it is the server's number.
    final int? matchPercentage = profile.compatibilityPercentage;

    return GestureDetector(
      // Whole-card tap → full profile detail page. Overlaid controls (heart /
      // kebab) win the gesture arena as descendants, so their own handlers
      // still fire.
      onTap: () => PublicProfileDetailSheet.show(
        context,
        profileId: profile.id,
        searchProfile: profile,
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Soul.gray100),
          boxShadow: _Soul.cardShadow,
        ),
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
            // ---------------------------------------------------------
            // PHOTO — the reference card's portrait image: Verified chip
            // top-left, extra-photos badge bottom-left, favourite heart
            // bottom-right.
            // ---------------------------------------------------------
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 96,
                  height: 116,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _Soul.pink100,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: profile.hasPhoto
                        // Disk-cached: revisiting Discover (and scrolling
                        // back) renders instantly instead of re-downloading
                        // every photo on each rebuild.
                        ? CachedNetworkImage(
                            imageUrl: profile.photoUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            memCacheWidth: 300,
                            errorWidget: (_, _, _) =>
                                _PhotoFallback(profile: profile),
                            placeholder: (_, _) =>
                                _PhotoFallback(profile: profile),
                          )
                        : _PhotoFallback(profile: profile),
                  ),
                ),
                // Verified chip — white pill with the pink tick, exactly the
                // reference card's top-left badge.
                if (profile.isVerified)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => TrustVerificationSheet.show(
                        context,
                        profileId: profile.id,
                        name: profile.displayName,
                        photoUrl: profile.photo,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.verified_rounded,
                                size: 10, color: _Soul.pink600),
                            SizedBox(width: 3),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: _Soul.ink900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Extra-photos badge — bottom-left dark pill with the count
                // of ADDITIONAL gallery photos (0 hides it).
                if (profile.additionalPhotoCount > 0)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.photo_library_rounded,
                              size: 9, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            '${profile.additionalPhotoCount}',
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Favourite heart — the reference's white circular button
                // bottom-right, INSIDE the photo bounds (negative offsets
                // made it hang outside the card on real devices).
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => controller.toggleShortlist(
                      profile.id,
                      displayName: profile.displayName,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Obx(() {
                        final bool isShortlisted =
                            controller.isShortlisted(profile.id);
                        return Icon(
                          isShortlisted
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: isShortlisted
                              ? _Soul.pink600
                              : _Soul.ink500,
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // ---------------------------------------------------------
            // CONTENT — the reference layout: name + presence chip + kebab,
            // the age/height | faith | sect chips row, location, education +
            // job on one 2-col row, family line, then match pill + "Why this
            // match?" + Send Proposal.
            // ---------------------------------------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Name row — name, presence chip, kebab menu.
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _Soul.ink900,
                          ),
                          // Complete name — always fully visible, wrapping to
                          // as many lines as it needs (no ellipsis).
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showOptionsMenu(context),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.more_vert_rounded,
                              size: 18, color: _Soul.gray300),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Chips row — "24 Years ¦ 5'4" ¦ ☾ Muslim ¦ ◫ Sunni" — the
                  // reference's tiny glyph chips with dotted separators. Every
                  // value comes from the API/lookups.
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (profile.age != null)
                        _IconChip(icon: Icons.cake_outlined, label: '${profile.age} Years'),
                      if (heightLabel.isNotEmpty) ...<Widget>[
                        const _DotSeparator(),
                        _IconChip(icon: Icons.height_rounded, label: heightLabel),
                      ],
                      if (religion != null) ...<Widget>[
                        const _DotSeparator(),
                        _IconChip(icon: Icons.nightlight_round, label: religion),
                      ],
                      if (sect != null) ...<Widget>[
                        const _DotSeparator(),
                        _IconChip(icon: Icons.menu_book_rounded, label: school ?? sect),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Location line.
                  if (city != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _FactCell(
                        icon: Icons.location_on_outlined,
                        label: city,
                      ),
                    ),

                  // Education + job — the reference's two-column row.
                  if (education != null || profession != null) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: <Widget>[
                          if (education != null)
                            Expanded(
                              child: _FactCell(
                                icon: Icons.school_outlined,
                                label: education,
                              ),
                            ),
                          if (profession != null)
                            Expanded(
                              child: _FactCell(
                                icon: Icons.work_outline_rounded,
                                label: profession,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Family line — "Family Oriented".
                  if (family != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _FactCell(
                        icon: Icons.home_outlined,
                        label: family,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Bottom row — match pill + "Why this match?" + Send
                  // Proposal, exactly the reference alignment.
                  Row(
                    children: <Widget>[
                      if (matchPercentage != null && matchPercentage > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.favorite_rounded,
                                  size: 10, color: _Soul.pink600),
                              const SizedBox(width: 4),
                              Text(
                                '$matchPercentage% Match',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _Soul.pink600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // "Why this match?" — ONLY while the AI Match filter
                      // (top-5 matchmaking mode) is applied; the reasons come
                      // from the compatibility engine, so the link means
                      // nothing on a plain search result.
                      if (controller.aiFiltered.value &&
                          matchPercentage != null &&
                          matchPercentage > 0) ...<Widget>[
                        const SizedBox(width: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _WhyThisMatchSheet.show(
                            context,
                            profile: profile,
                            matchPercentage: matchPercentage,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 2, vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  'Why this match?',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _Soul.ink500,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded,
                                    size: 13, color: _Soul.ink500),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          ],
            ),
        // -------------------------------------------------------------
        // Action strip — the six-icon row (Send Interest / Chat / Full
        // Profile / More / Ignore / Report) that sat below every card in
        // the original design. Equal-flex cells so nothing overflows.
        // -------------------------------------------------------------
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
          decoration: BoxDecoration(
            color: _Soul.ink50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              // Send Interest — heart cell; shows a tick when already sent.
              Obx(() {
                final bool sent =
                    interestCtrl?.hasSentInterestTo(profile.id) == true;
                return _ActionCell(
                  icon: sent
                      ? Icons.check_rounded
                      : Icons.favorite_border_rounded,
                  iconColor: sent ? AppColors.success : _Soul.pink600,
                  tooltip: 'Send Interest',
                  onTap: () =>
                      SendInterestDialog.show(context, profile),
                );
              }),
              // Chat.
              _ActionCell(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: _Soul.ink900,
                tooltip: 'Chat',
                onTap: () => _handleChatTap(context, profile),
              ),
              // Full profile.
              _ActionCell(
                icon: Icons.person_outline_rounded,
                iconColor: _Soul.ink900,
                tooltip: 'Full Profile',
                onTap: () => PublicProfileDetailSheet.show(
                  context,
                  profileId: profile.id,
                  searchProfile: profile,
                ),
              ),
              // More options.
              _ActionCell(
                icon: Icons.more_vert_rounded,
                iconColor: _Soul.ink900,
                tooltip: 'More options',
                onTap: () => _showOptionsMenu(context),
              ),
              // Ignore.
              _ActionCell(
                icon: Icons.do_not_disturb_on_rounded,
                iconColor: _Soul.ink900,
                tooltip: 'Ignore',
                onTap: onIgnore,
              ),
              // Report.
              _ActionCell(
                icon: Icons.flag_outlined,
                iconColor: AppColors.error,
                tooltip: 'Report',
                onTap: () => ReportProfileDialog.show(context, profile),
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      builder: (BuildContext ctx) {
        // Scrollable: the menu now has 8 entries and overflowed ~6px on
        // short screens / small text-scale settings.
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Chat'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleChatTap(context, profile);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Full Profile'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  PublicProfileDetailSheet.show(
                    context,
                    profileId: profile.id,
                    searchProfile: profile,
                  );
                },
              ),
              Obx(() {
                final ProposalController? proposalCtrl =
                    Get.isRegistered<ProposalController>()
                    ? Get.find<ProposalController>()
                    : null;
                final bool proposed =
                    proposalCtrl?.hasSentProposalTo(profile.id) == true;
                if (proposed) {
                  return ListTile(
                    leading: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                    ),
                    title: const Text(
                      'Already Sent',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      PublicProfileDetailSheet.show(
                        context,
                        profileId: profile.id,
                        searchProfile: profile,
                      );
                    },
                  );
                }
                return ListTile(
                  leading: const Icon(
                    Icons.mail_outline_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Send Proposal'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    SendProposalDialog.show(context, profile);
                  },
                );
              }),

              ListTile(
                leading: const Icon(
                  Icons.favorite_border_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Send Interest'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  SendInterestDialog.show(context, profile);
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: AppColors.gold,
                ),
                title: const Text('Shortlist'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.toggleShortlist(
                    profile.id,
                    displayName: profile.displayName,
                  );
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.visibility_off_outlined,
                  color: Theme.of(context).hintColor,
                ),
                title: const Text('Ignore Profile'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  // Persist on the server (shows in the Ignored list, restorable)
                  // AND hide the card from the current feed immediately.
                  if (Get.isRegistered<ProposalExtraController>()) {
                    Get.find<ProposalExtraController>().ignoreUser(profile.id);
                  }
                  controller.ignoreProfile(profile.id);
                  AppSnackbar.info('Profile ignored. Restore it from the Ignored list.');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.restore_from_trash_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Ignored Profiles'),
                subtitle: const Text(
                  'View and restore hidden profiles',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  IgnoredProfilesView.open();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Report Profile',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ReportProfileDialog.show(context, profile);
                },
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  void _handleChatTap(BuildContext context, SearchProfileModel profile) async {
    final ChatController chatCtrl = Get.find<ChatController>();
    final ChatThread? thread = await chatCtrl.findExistingThreadWithUser(
      profile.id,
    );
    if (thread != null && thread.id > 0) {
      ChatConversationView.open(thread);
    } else {
      if (context.mounted) {
        _showChatConnectPrompt(context, profile);
      }
    }
  }

  void _showChatConnectPrompt(
    BuildContext context,
    SearchProfileModel profile,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      builder: (BuildContext ctx) {
        final ThemeData theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_chat_unread_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Connect to Chat',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Direct messaging with ${profile.displayName} is enabled once an Express Interest proposal is accepted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.8,
                    ),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.mdAll,
                      ),
                    ),
                    icon: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Send Express Interest',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      SendInterestDialog.show(context, profile);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Theme.of(ctx).hintColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} // ---------------------------------------------------------------------------
// Card helpers — shared by the Discover feed card.
// ---------------------------------------------------------------------------

/// Word for the match badge's caption — the reference's "Harmonious" line,
/// softened to the score band the server computed.
String _harmonyWord(int pct) {
  if (pct >= 75) return 'Excellent';
  if (pct >= 60) return 'Harmonious';
  if (pct >= 45) return 'Promising';
  return 'Worth a look';
}

/// One fact in the HTML card's 2×2 grid: tiny pink glyph + one ellipsized
/// gray line (city, community, status, religion).
class _FactCell extends StatelessWidget {
  const _FactCell({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 10, color: _Soul.pink300),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 8.5, color: _Soul.ink500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// One action in the card's action row: an equal FLEX cell of the row's
/// free width with a centred 20 px glyph. Fixed-width buttons overflowed on
/// narrow phones once six of them shared a row with the Proposal pill; flex
/// cells shrink together instead, so the baseline alignment never breaks.
class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.icon,
    required this.iconColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: SizedBox(
            height: 38,
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// Rounded-square photo fallback when the member has no picture yet.
class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.profile});

  final SearchProfileModel profile;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.regAccent.withValues(alpha: 0.14),
      child: Center(
        child: Text(
          profile.initial,
          style: AppTextStyles.title.copyWith(
            color: AppColors.regAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// "Why this match?" — opens a dedicated DIALOGUE BOX holding only the
/// why-match data: the AI summary line and the reasons list. Nothing else —
/// no profile link, no actions. Backed by `GET /profiles/{id}/compatibility`;
/// the listing card's percentage is what the header shows.
class _WhyThisMatchSheet {
  const _WhyThisMatchSheet._();

  static void show(
    BuildContext context, {
    required SearchProfileModel profile,
    required int matchPercentage,
  }) {
    final ProfileRepository repo = Get.find<ProfileRepository>();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (BuildContext ctx) => FutureBuilder<CompatibilityModel?>(
        future: repo
            .fetchCompatibility(profile.id)
            .then<CompatibilityModel?>((CompatibilityModel v) => v)
            .catchError((_) => null),
        builder: (BuildContext ctx, AsyncSnapshot<CompatibilityModel?> snap) {
          final CompatibilityModel? data = snap.data;
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Header — title + match pill + close.
                    Row(
                      children: <Widget>[
                        const Icon(Icons.auto_awesome_rounded,
                            size: 16, color: _Soul.pink600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Why this match?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$matchPercentage% Match',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _Soul.pink600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.close_rounded,
                                size: 18, color: _Soul.ink500),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 22),
                    if (snap.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _Soul.pink600),
                        ),
                      )
                    else ...<Widget>[
                      // The one-line AI summary.
                      Text(
                        'AI Compatibility Summary:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data?.displayExplanation ??
                            'This match is based on your shared preferences — '
                                'age, location, faith and lifestyle all line up '
                                'well with what you are looking for.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (data != null && data.reasons.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(
                          'What lines up',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                ...data.reasons.take(6).map(
                                      (String r) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 5),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            const Icon(
                                                Icons.check_circle_rounded,
                                                size: 13,
                                                color: Color(0xFF22A45D)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                r,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  height: 1.4,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tiny glyph chip used in the reference card's facts row ("24 Years",
/// "5'4\"", "Muslim", "Sunni") — pink icon + ink label.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 10, color: _Soul.pink600),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: _Soul.ink900,
          ),
        ),
      ],
    );
  }
}

/// The dotted separator between chips in the facts row.
class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _Soul.gray300,
      ),
    );
  }
}
