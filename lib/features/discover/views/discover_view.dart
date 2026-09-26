import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/interest_controller.dart';
import '../../../controllers/notification_controller.dart';
import '../../../controllers/proposal_controller.dart';
import '../../../controllers/search_profiles_controller.dart';

import '../../../core/api/api_response.dart';
import '../../../models/chat_model.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';
import '../../chat/views/chat_conversation_view.dart';
import '../../notifications/views/notifications_view.dart';
import '../widgets/discover_shortcuts.dart';
import '../widgets/public_profile_detail_sheet.dart';
import '../widgets/report_profile_dialog.dart';
import '../widgets/trust_verification_sheet.dart';
import '../widgets/horoscope_form_sheet.dart';
import '../widgets/search_filter_bottom_sheet.dart';
import '../widgets/send_interest_dialog.dart';
import '../../proposals/widgets/send_proposal_dialog.dart';

class DiscoverView extends StatelessWidget {
  const DiscoverView({super.key});

  @override
  Widget build(BuildContext context) {
    final SearchProfilesController controller =
        Get.find<SearchProfilesController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      // floatingActionButton: Padding(
      //   padding: const EdgeInsets.only(bottom: 50),
      //   child: FloatingActionButton(
      //     heroTag: 'discover_filter_fab',
      //     backgroundColor: const Color(0xFF1644A6), // Premium deep blue as in reference
      //     elevation: 6,
      //     onPressed: () => SearchFilterBottomSheet.show(context),
      //     child: const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 26),
      //   ),
      // ),
      // ONE scrollable for the whole screen: search bar, shortcut chips,
      // active filters, the AI toggle and the profile list all travel
      // together — scrolling up takes the header with it instead of leaving
      // it pinned over a cramped feed.
      body: RefreshIndicator(
        color: AppColors.regAccent,
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
              // Top Search & Filter Bar
              SliverToBoxAdapter(child: _SearchBarHeader(controller: controller)),
              // The filter module's own screens: swiping, interests, new
              // arrivals, history and recently viewed — one tap away.
              const SliverToBoxAdapter(child: DiscoverShortcuts()),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
              // Active Filter Chips (if any filters applied)
              SliverToBoxAdapter(child: _ActiveFilterChips(controller: controller)),
              // AI Filtered toggle — narrows the feed to the matchmaking
              // model's top 5 matches for this member.
              SliverToBoxAdapter(child: _AiFilteredBar(controller: controller)),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
              // The profile list and every load state.
              _FeedSlivers(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
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

    // Icon row first, full-width search field BELOW it — the icons sit on both
    // sides and the search field spans the whole width underneath, so it is
    // the visual anchor of the screen and never squeezed on small phones.
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        children: <Widget>[
          _buildIconRow(context, theme, isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildSearchField(context, theme, isDark),
        ],
      ),
    );
  }

  /// Horoscope · Filter · Notifications · Partner-preference — the same four
  /// icon buttons, now arranged filter/notification on the LEFT and horoscope /
  /// partner-preference on the RIGHT with an even spread between.
  Widget _buildIconRow(BuildContext context, ThemeData theme, bool isDark) {
    return Row(
      children: <Widget>[
        _buildFilterButton(context, isDark),
        const SizedBox(width: AppSpacing.sm),
        _buildNotificationButton(context, isDark),
        const Spacer(),
        _buildHoroscopeButton(isDark),
        const SizedBox(width: AppSpacing.sm),
        _buildPartnerPrefButton(isDark),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller.searchInputController,
        onChanged: controller.onSearchChanged,
        // The magnifier key on the keyboard commits the query immediately and
        // reloads — the field used to rely on the 500 ms debounce alone, which
        // read as a dead button.
        textInputAction: TextInputAction.search,
        onSubmitted: controller.submitSearch,
        decoration: InputDecoration(
          hintText: 'Search by name, ID, or keyword...',
          hintStyle: AppTextStyles.body.copyWith(
            color: Theme.of(context).hintColor.withValues(alpha: 0.7),
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          suffixIcon: Obx(() {
            final bool hasText =
                controller.filter.value.searchQuery?.isNotEmpty == true;
            if (!hasText) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              onPressed: controller.clearSearchQuery,
            );
          }),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, bool isDark) {
    return Obx(() {
      final int filterCount = controller.activeFilterCount;
      final bool hasFilters = filterCount > 0;

      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          InkWell(
            onTap: () => SearchFilterBottomSheet.show(context),
            borderRadius: AppRadius.lgAll,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: hasFilters
                    ? AppColors.primary
                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: hasFilters
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightDivider),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (hasFilters ? AppColors.primary : Colors.black)
                        .withValues(alpha: hasFilters ? 0.25 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.tune_rounded,
                color: hasFilters
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.primary),
                size: 20,
              ),
            ),
          ),
          if (hasFilters)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    '$filterCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
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
      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          InkWell(
            onTap: () => Get.to(() => const NotificationsView()),
            borderRadius: AppRadius.lgAll,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                unread > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
                size: 22,
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
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

  Widget _buildHoroscopeButton(bool isDark) {
    return InkWell(
      onTap: () => HoroscopeFormSheet.show(Get.context!),
      borderRadius: AppRadius.lgAll,
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.gold,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildPartnerPrefButton(bool isDark) {
    return Obx(() {
      final bool active = controller.filter.value.partnerPreferenceFilter;
      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          InkWell(
            onTap: controller.togglePartnerPreferenceFilter,
            borderRadius: AppRadius.lgAll,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: active
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightDivider),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (active ? AppColors.primary : Colors.black)
                        .withValues(alpha: active ? 0.25 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.favorite_outline_rounded,
                color: active
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.primary),
                size: 20,
              ),
            ),
          ),
          if (active)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );
    });
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
          delegate: SliverChildBuilderDelegate(
            (BuildContext ctx, int i) {
              final SearchProfileModel profile = visible[i];
              final GlobalKey cardKey =
                  _cardKeys.putIfAbsent(profile.id, GlobalKey.new);
              return KeyedSubtree(
                key: cardKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _SingleUserProfileCard(
                    profile: profile,
                    controller: widget.controller,
                    onIgnore: () => _ignore(profile, i),
                  ),
                ),
              );
            },
            childCount: visible.length,
          ),
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
    final GlobalKey? nextKey =
        index + 1 < visible.length ? _cardKeys[visible[index + 1].id] : null;

    widget.controller.ignoreProfile(profile.id);
    AppSnackbar.info('Profile ignored.');

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

    final String? marital = controller.maritalStatusLabel(
      profile.maritalStatusId,
    );
    final String? religion = controller.religionLabel(profile.religionId);
    final String? city = controller.cityLabel(profile.cityId);
    final String? state = controller.stateLabel(profile.stateId);
    final String? country = controller.countryLabel(profile.countryId);
    final String? caste = controller.casteLabel(profile.casteId);

    final String genderLabel = profile.gender == '1'
        ? 'Male'
        : profile.gender == '2'
        ? 'Female'
        : '';
    final String heightLabel = profile.heightFormatted ?? '';
    // The API's real compatibility score — or nothing. A fabricated 80/70%
    // told every member the same lie about every profile, and the pill only
    // means something when it is the server's number.
    final int? matchPercentage = profile.compatibilityPercentage;

    return GestureDetector(
      // Whole-card tap → full profile detail page. Overlaid controls (heart /
      // action row / verified tick) win the gesture arena as descendants, so
      // their own handlers still fire.
      onTap: () => PublicProfileDetailSheet.show(
        context,
        profileId: profile.id,
        searchProfile: profile,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.roseFieldBorder),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFB4487B).withValues(alpha: 0.10),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // ==========================================================
              // 1. Photo · serif headline · AI match pill + heart
              // ==========================================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Rounded-square photo, like the reference card.
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.roseFieldBorder,
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18.5),
                      child: profile.hasPhoto
                          ? Image.network(
                              profile.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _PhotoFallback(profile: profile),
                              loadingBuilder: (BuildContext ctx,
                                  Widget child, ImageChunkEvent? p) {
                                if (p == null) return child;
                                return _PhotoFallback(profile: profile);
                              },
                            )
                          : _PhotoFallback(profile: profile),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // "Sara Khan, 26" — serif headline, the reference
                        // card's way of writing a name.
                        //
                        // One text flow, not a Row: as separate children the
                        // age and the tick reserved fixed width, so the name
                        // was the only thing left to shrink and long names
                        // ellipsed to "Muha…" even with room to spare. As
                        // spans they share the line, and the name may take a
                        // second one before any of it is cut.
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(text: profile.displayName),
                              if (profile.age != null)
                                TextSpan(text: ', ${profile.age}'),
                              // Non-breaking space, not a spacer widget: a
                              // WidgetSpan gap is a legal place to wrap, which
                              // left the tick stranded alone on a second line
                              // whenever the name itself fitted on the first.
                              const TextSpan(text: '\u00A0'),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                // The tick doubles as a button: tapping it
                                // opens the member's Trust & Verification
                                // dialog.
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => TrustVerificationSheet.show(
                                    context,
                                    profileId: profile.id,
                                    name: profile.displayName,
                                    photoUrl: profile.photo,
                                  ),
                                  child: Icon(
                                    profile.isVerified
                                        ? Icons.verified_rounded
                                        : Icons.shield_outlined,
                                    color: profile.isVerified
                                        ? AppColors.success
                                        : AppColors.regAccentSoft,
                                    size: 17,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          style: AppTextStyles.displaySerif.copyWith(
                            fontSize: 17,
                            height: 1.25,
                            color: AppColors.roseTitleInk,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            if (heightLabel.isNotEmpty)
                              _InfoChip(
                                icon: Icons.height_rounded,
                                label: heightLabel,
                              ),
                            if (genderLabel.isNotEmpty)
                              _InfoChip(
                                icon: Icons.person_outline_rounded,
                                label: genderLabel,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Top-right: the AI match pill above the shortlist heart,
                  // exactly where the reference card puts them.
                  Column(
                    children: <Widget>[
                      if (matchPercentage != null) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 12,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$matchPercentage% match',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF9C6A1E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                      Obx(() {
                        final bool isShortlisted =
                            controller.isShortlisted(profile.id);
                        return _RoundIconButton(
                          icon: isShortlisted
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          iconColor: isShortlisted
                              ? AppColors.regAccent
                              : AppColors.chatTimeInk,
                          tooltip: isShortlisted
                              ? 'Remove from shortlist'
                              : 'Shortlist',
                          onTap: () => controller.toggleShortlist(
                            profile.id,
                            displayName: profile.displayName,
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ==========================================================
              // 2. Glyph fact rows — the reference's 📍 🕌 💍 lines
              // ==========================================================
              _FactLine(
                icon: Icons.location_on_outlined,
                text: _buildLocationString(city, state, country),
              ),
              if (religion != null && religion.isNotEmpty)
                _FactLine(icon: Icons.mosque_outlined, text: religion),
              if (caste != null && caste.isNotEmpty)
                _FactLine(icon: Icons.groups_outlined, text: caste),
              if (marital != null && marital.isNotEmpty)
                _FactLine(icon: Icons.favorite_border_rounded, text: marital),

              const SizedBox(height: 12),

              // ==========================================================
              // 3. Aligned action row — equal icons on one baseline, the
              //    Proposal pill closing the row. Nothing sits below it, so
              //    there is no second row left to overflow.
              // ==========================================================
              Container(
                padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
                decoration: BoxDecoration(
                  color: AppColors.roseCanvasDeep,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: <Widget>[
                    // Each action is an equal FLEX cell, not a fixed 38 px
                    // button: six fixed buttons plus the pill cannot fit a
                    // narrow phone, and the row overflowed. Equal cells keep
                    // the even, aligned rhythm on every width.
                    Obx(() {
                      final bool hasSent =
                          interestCtrl?.hasSentInterestTo(profile.id) == true;
                      return _ActionCell(
                        icon: hasSent
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        iconColor: hasSent
                            ? AppColors.regAccent
                            : AppColors.chatPreviewInk,
                        tooltip: 'Send Interest',
                        onTap: () => SendInterestDialog.show(context, profile),
                      );
                    }),
                    _ActionCell(
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: AppColors.chatPreviewInk,
                      tooltip: 'Chat',
                      onTap: () => _handleChatTap(context, profile),
                    ),
                    _ActionCell(
                      icon: Icons.person_outline_rounded,
                      iconColor: AppColors.chatPreviewInk,
                      tooltip: 'Full Profile',
                      onTap: () => PublicProfileDetailSheet.show(
                        context,
                        profileId: profile.id,
                        searchProfile: profile,
                      ),
                    ),
                    _ActionCell(
                      icon: Icons.more_vert_rounded,
                      iconColor: AppColors.chatPreviewInk,
                      tooltip: 'More options',
                      onTap: () => _showOptionsMenu(context),
                    ),
                    _ActionCell(
                      icon: Icons.do_not_disturb_on_outlined,
                      iconColor: AppColors.chatPreviewInk,
                      tooltip: 'Ignore',
                      onTap: onIgnore,
                    ),
                    _ActionCell(
                      icon: Icons.flag_outlined,
                      iconColor: AppColors.chatPreviewInk,
                      tooltip: 'Report',
                      onTap: () => ReportProfileDialog.show(context, profile),
                    ),
                    _ProposalPill(
                      onTap: () => SendProposalDialog.show(context, profile),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  String _buildLocationString(String? city, String? state, String? country) {
    final List<String> parts = <String>[];
    if (city != null && city.isNotEmpty) parts.add(city);
    if (state != null && state.isNotEmpty) parts.add(state);
    if (country != null && country.isNotEmpty) parts.add(country);
    return parts.isEmpty ? 'Location not set' : parts.join(', ');
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      builder: (BuildContext ctx) {
        return SafeArea(
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
                  controller.ignoreProfile(profile.id);
                  AppSnackbar.info('Profile ignored.');
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
}// ---------------------------------------------------------------------------
// Card helpers — shared by the Discover feed card.
// ---------------------------------------------------------------------------

/// Small rose info chip on the white card (height, gender).
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.regAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.roseFieldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.chatTimeInk, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.chatPreviewInk,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One quiet glyph fact line under the headline (📍 city · 🕌 religion).
class _FactLine extends StatelessWidget {
  const _FactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Fixed-width, centred icon cell so every line's text starts on the
          // same left edge whatever the glyph's own width is — a mosque and a
          // pin do not measure the same, and the ragged left edge was what
          // made the block look unaligned.
          SizedBox(
            width: 18,
            child: Center(
              child: Icon(icon, size: 14, color: AppColors.regAccent),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: AppColors.chatPreviewInk,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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

/// The action row's uniform icon button: fixed 38×38 circle so every icon
/// shares one size and baseline — the alignment the reference list demands.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// The row's primary action: white pill, rose hairline, gold Proposal —
/// sitting on the same baseline as the icons instead of a second row below.
class _ProposalPill extends StatelessWidget {
  const _ProposalPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.mail_outline_rounded, size: 15, color: AppColors.gold),
              SizedBox(width: 6),
              Text(
                'Proposal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF9C6A1E),
                ),
              ),
            ],
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
