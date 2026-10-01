import 'dart:async';

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
                // Category chips: Proposals for You (default active) · AI
                // Matches · My Interests · New Profiles — the reference strip.
                SliverToBoxAdapter(
                  child: _CategoryChips(controller: controller),
                ),
                // Hero banner (auto-looping carousel)...
                const SliverToBoxAdapter(child: _HeroBanner()),
                // ...with the search row right under it, per the reference.
                SliverToBoxAdapter(
                  child: _SearchRow(controller: controller),
                ),
                // "Recommended for You / Based on your preferences".
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

/// The search row that sits UNDER the hero banner: rounded field + trailing
/// filter button. Same live-debounce behaviour as always.
class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.controller});

  final SearchProfilesController controller;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : _Soul.ink50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isDark ? AppColors.darkBorder : _Soul.gray200),
              ),
              child: TextField(
                controller: controller.searchInputController,
                onChanged: controller.onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: controller.submitSearch,
                style: const TextStyle(fontSize: 13, color: _Soul.ink900),
                cursorColor: _Soul.pink600,
                decoration: InputDecoration(
                  hintText: 'Search by city, profession, education...',
                  hintStyle:
                      const TextStyle(fontSize: 12, color: _Soul.gray400),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _Soul.gray400,
                    size: 20,
                  ),
                  suffixIcon: Obx(() {
                    final bool hasText =
                        controller.filter.value.searchQuery?.isNotEmpty == true;
                    if (!hasText) return const SizedBox.shrink();
                    return IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: _Soul.ink500,
                      ),
                      onPressed: controller.clearSearchQuery,
                    );
                  }),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _FilterCircleButton(controller: controller),
        ],
      ),
    );
  }
}

/// The search row's trailing filter button (white circle + count badge).
class _FilterCircleButton extends StatelessWidget {
  const _FilterCircleButton({required this.controller});

  final SearchProfilesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int filterCount = controller.activeFilterCount;
      final bool hasFilters = filterCount > 0;
      return GestureDetector(
        onTap: () => SearchFilterBottomSheet.show(context),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: hasFilters ? _Soul.pink600 : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: hasFilters ? Colors.transparent : _Soul.gray200,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Center(
                child: Icon(
                  Icons.tune_rounded,
                  color: hasFilters ? _Soul.pinkInk : _Soul.ink900,
                  size: 20,
                ),
              ),
              if (hasFilters)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: _Soul.pinkInk,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.white, width: 1.5),
                      ),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
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
          ),
        ),
      );
    });
  }
}

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
        ],
      ),
    );
  }

  /// The reference's header: logo + "CHOOSE FOREVER" wordmark LEFT, and the
  /// white circular actions (search · bell · sliders) on the right. The old
  /// search field lives in the top-right search circle; the filter sheet in
  /// the sliders circle — same behaviour, new layout.
  Widget _buildIconRow(BuildContext context, ThemeData theme, bool isDark) {
    return Row(
      children: <Widget>[
        // Brand — heart glyph + serif "HamQadam" + CHOOSE FOREVER, left.
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final ScaffoldState? shell =
                  HomeView.shellKey.currentState ?? Scaffold.maybeOf(context);
              if (shell != null) {
                shell.openDrawer();
              }
            },
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icons/logo.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.favorite_rounded,
                      color: _Soul.pink600,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'HamQadam',
                          style: TextStyle(
                            fontFamily: AppTextStyles.displayFont,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: _Soul.ink900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.auto_awesome_rounded,
                            color: _Soul.pink600, size: 13),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'C H O O S E   F O R E V E R',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: _Soul.gray400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Horoscope (kept live here) · bell — search & filter have moved
        // to the card-area search row below, per the reference.
        _headerCircleButton(
          context,
          icon: Icons.auto_awesome_rounded,
          onTap: () => HoroscopeFormSheet.show(Get.context!),
        ),
        const SizedBox(width: 10),
        _buildNotificationButton(context, isDark),
      ],
    );
  }

  /// The reference's 42px white circle action button (search / bell look).
  Widget _headerCircleButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: _Soul.ink900, size: 20),
      ),
    );
  }

  /// The reference's search row: rounded field + trailing filter button.
  /// Same live-debounce search behaviour as always.
  Widget _buildSearchField(BuildContext context, ThemeData theme, bool isDark) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _Soul.ink50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _Soul.gray200),
            ),
            child: TextField(
              controller: controller.searchInputController,
              onChanged: controller.onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: controller.submitSearch,
              style: const TextStyle(fontSize: 13, color: _Soul.ink900),
              cursorColor: _Soul.pink600,
              decoration: InputDecoration(
                hintText: 'Search by city, profession, education...',
                hintStyle: const TextStyle(fontSize: 12, color: _Soul.gray400),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _Soul.gray400,
                  size: 20,
                ),
                suffixIcon: Obx(() {
                  final bool hasText =
                      controller.filter.value.searchQuery?.isNotEmpty == true;
                  if (!hasText) return const SizedBox.shrink();
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: _Soul.ink500,
                    ),
                    onPressed: controller.clearSearchQuery,
                  );
                }),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
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
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: _Soul.ink900,
                  size: 20,
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
}

// ---------------------------------------------------------------------------
// Hero banner — auto-looping 3-slide carousel (AI Matches / Curated Profiles /
// Verified Members) with page dots. The reference's pink promo card.
// ---------------------------------------------------------------------------

class _HeroBanner extends StatefulWidget {
  const _HeroBanner();

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  static const List<String> _images = <String>[
    'assets/images/onboard.png',
    'assets/images/onboard2.png',
    'assets/images/onboard3.png',
  ];
  static const List<String> _badges = <String>['AI Matches', 'Curated Profiles', 'Verified Members'];
  static const List<String> _titles = <String>['Thoughtful proposals', 'Handpicked for you', 'Trust built in'];
  static const List<String> _accents = <String>['for your journey.', 'from day one.', 'at every step.'];
  static const List<String> _bodies = <String>[
    'Our AI finds compatible, verified profiles\nbased on your preferences.',
    'Real rishtas aligned with your values\nand partner preferences.',
    'Every profile passes verification —\nconnect with confidence.',
  ];

  final PageController _pageController = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    // Auto-advance every 3.5s, looping back to 0 after the last slide.
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (Timer t) {
      if (!mounted) return;
      final int next = (_current + 1) % _images.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 4),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFBD9E3),
              Color(0xFFF7C4D6),
              Color(0xFFF2AEC9),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (int i) => setState(() => _current = i),
            itemBuilder: (BuildContext _, int i) => _buildSlide(i),
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(int i) {
    return Stack(
      children: <Widget>[
        // Right-side artwork, faded into the gradient.
        Positioned(
          right: -30,
          top: 0,
          bottom: 0,
          child: Opacity(
            opacity: 0.9,
            child: Image.asset(
              _images[i],
              height: 190,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.auto_awesome_rounded, size: 13, color: _Soul.pinkInk),
                  const SizedBox(width: 5),
                  Text(
                    _badges[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _Soul.pinkInk,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Serif headline — dark first line, pink accent second.
              Text(
                _titles[i],
                style: TextStyle(
                  fontFamily: AppTextStyles.displayFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _Soul.ink900,
                  height: 1.15,
                ),
              ),
              Text(
                _accents[i],
                style: TextStyle(
                  fontFamily: AppTextStyles.displayFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _Soul.pinkInk,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _bodies[i],
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: _Soul.gray600,
                ),
              ),
              const SizedBox(height: 8),
              // Page dots — active one wide.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List<Widget>.generate(_images.length, (int d) {
                  final bool active = d == _current;
                  return Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: active ? 16 : 5,
                    height: 4,
                    decoration: BoxDecoration(
                      color: active ? _Soul.pinkInk : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
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
        height: 38,
        child: Obx(() {
          final SearchFilterModel f = controller.filter.value;
          final bool aiActive = controller.aiFiltered.value;
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            children: <Widget>[
              // The reference's FIRST and default-active pill — the whole
              // Discover feed. Tapping reloads the plain feed and deactivates
              // the AI toggle.
              _CategoryChip(
                label: 'Proposals for You',
                icon: Icons.group_rounded,
                active: !aiActive,
                onTap: () {
                  if (controller.aiFiltered.value) {
                    controller.toggleAiFiltered();
                  }
                },
              ),
              _CategoryChip(
                label: 'AI Matches',
                icon: Icons.auto_awesome_rounded,
                active: aiActive,
                onTap: controller.toggleAiFiltered,
              ),
              _CategoryChip(
                label: 'My Interests',
                icon: Icons.favorite_rounded,
                onTap: () => Get.toNamed<dynamic>(routes.AppRoutes.expressInterests),
              ),
              _CategoryChip(
                label: 'New Profiles',
                icon: Icons.person_add_alt_rounded,
                onTap: () => Get.toNamed<dynamic>(routes.AppRoutes.newProfiles),
              ),
              _CategoryChip(
                label: 'Nearby',
                active: f.nearby,
                onTap: () => controller.applyFilter(
                  controller.filter.value.copyWith(nearby: !f.nearby),
                ),
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
                // Verified — icon-only badge, top-left of the photo (tap
                // opens the trust sheet, same behaviour as before).
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
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: Color(0xFF1D9BF0),
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
            // CONTENT — the reference layout: serif name on ONE line
            // (complete, never truncated) + kebab, the age/height · faith
            // line, location, profession, education. The % Match block sits
            // on the right with the heart ABOVE it.
            // ---------------------------------------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Name row — complete name on a single line + kebab menu.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            profile.displayName,
                            style: const TextStyle(
                              fontFamily: AppTextStyles.displayFont,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _Soul.ink900,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // "26 Years · 5'4\" · Islam" — dark text with quiet dots.
                  if (profile.age != null ||
                      heightLabel.isNotEmpty ||
                      religion != null)
                    Text(
                      <String?>[
                        if (profile.age != null) '${profile.age} Years',
                        if (heightLabel.isNotEmpty) heightLabel,
                        if (religion != null) religion,
                      ].whereType<String>().join('  ·  '),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _Soul.ink900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 5),

                  // Location line — "Lahore, Pakistan".
                  if (city != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _FactCell(
                        icon: Icons.location_on_outlined,
                        label: city,
                      ),
                    ),

                  // Profession line.
                  if (profession != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _FactCell(
                        icon: Icons.work_outline_rounded,
                        label: profession,
                      ),
                    ),

                  // Education line.
                  if (education != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _FactCell(
                        icon: Icons.school_outlined,
                        label: education,
                      ),
                    ),                  // Family line — "Family Oriented".
                  if (family != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _FactCell(
                        icon: Icons.home_outlined,
                        label: family,
                      ),
                    ),
                ],
              ),
            ),

            // % Match + heart — the reference's right rail: heart circle
            // ABOVE the pink match block, both stacked.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controller.toggleShortlist(
                    profile.id,
                    displayName: profile.displayName,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
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
                        color: isShortlisted ? _Soul.pinkInk : _Soul.ink500,
                      );
                    }),
                  ),
                ),
                if (matchPercentage != null && matchPercentage > 0) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE0EA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '$matchPercentage%',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _Soul.pinkInk,
                          ),
                        ),
                        const Text(
                          'Match',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _Soul.pinkInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
            ),
        // -------------------------------------------------------------
        // Action strip — View Profile | Why this match? | Send Interest |
        // Send Proposal — ALWAYS all four (AI mode or not), same tap
        // targets as before. The old icon row below keeps Chat/More/
        // Ignore/Report. Small 10px labels; each pill clips with ellipsis
        // instead of overflowing the Row.
        // -------------------------------------------------------------
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            // View Profile — soft pink pill.
            Expanded(
              child: GestureDetector(
                onTap: () => PublicProfileDetailSheet.show(
                  context,
                  profileId: profile.id,
                  searchProfile: profile,
                ),
                child: Container(
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE0EA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  // FittedBox: the label always shows COMPLETE, scaled to
                  // the pill's width — never "View Pro…".
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.visibility_rounded,
                              size: 12, color: _Soul.pinkInk),
                          const SizedBox(width: 4),
                          Text(
                            'View Profile',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _Soul.pinkInk,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            // "Why this match?" — reasons come from the compatibility engine.
            Expanded(
              child: GestureDetector(
                onTap: (matchPercentage != null && matchPercentage > 0)
                    ? () => _WhyThisMatchSheet.show(
                          context,
                          profile: profile,
                          matchPercentage: matchPercentage,
                        )
                    : null,
                child: Container(
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE0EA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.auto_awesome_rounded,
                              size: 11, color: _Soul.pinkInk),
                          const SizedBox(width: 4),
                          Text(
                            'Why this match?',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _Soul.pinkInk,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            // Send Interest — soft pink pill, tick when already sent.
            Expanded(
              child: Obx(() {
                final bool sent =
                    interestCtrl?.hasSentInterestTo(profile.id) == true;
                return GestureDetector(
                  onTap: () => SendInterestDialog.show(context, profile),
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE0EA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              sent
                                  ? Icons.check_rounded
                                  : Icons.favorite_rounded,
                              size: 11,
                              color: sent ? AppColors.success : _Soul.pinkInk,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sent ? 'Sent' : 'Send Interest',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color:
                                    sent ? AppColors.success : _Soul.pinkInk,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 5),
            // Send Proposal — solid pink pill, closing the row.
            Expanded(
              child: GestureDetector(
                onTap: () => SendProposalDialog.show(context, profile),
                child: Container(
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _Soul.pink600,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: _Soul.pinkShadow,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.send_rounded,
                              size: 12, color: _Soul.pinkInk),
                          const SizedBox(width: 4),
                          Text(
                            'Send Proposal',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _Soul.pinkInk,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
