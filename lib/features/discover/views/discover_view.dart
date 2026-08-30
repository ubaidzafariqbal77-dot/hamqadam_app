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
import '../../../widgets/state_widgets.dart';
import '../../chat/views/chat_conversation_view.dart';
import '../../notifications/views/notifications_view.dart';
import '../widgets/public_profile_detail_sheet.dart';
import '../widgets/report_profile_dialog.dart';
import '../widgets/search_filter_bottom_sheet.dart';
import '../widgets/send_interest_dialog.dart';
import '../../proposals/widgets/send_proposal_dialog.dart';

 
class DiscoverView extends StatelessWidget {
  const DiscoverView({super.key});

  @override
  Widget build(BuildContext context) {
    final SearchProfilesController controller = Get.find<SearchProfilesController>();

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
      body: Column(
        children: <Widget>[
          // Top Search & Filter Bar
          _SearchBarHeader(controller: controller),
          // Active Filter Chips (if any filters applied)
          _ActiveFilterChips(controller: controller),
          // Single User Full-Screen Vertical Feed
          Expanded(
            child: Obx(() {
              final ApiState<SearchProfilesPage> state = controller.state.value;

              switch (state.status) {
                case ApiStatus.initial:
                case ApiStatus.loading:
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                case ApiStatus.noInternet:
                  return NoInternetWidget(onRetry: controller.reload);
                case ApiStatus.unauthorized:
                case ApiStatus.serverError:
                case ApiStatus.validationError:
                  return ErrorStateWidget(
                    message: state.message,
                    onRetry: controller.reload,
                  );
                case ApiStatus.empty:
                  return EmptyStateWidget(
                    title: 'No Matches Found',
                    message: state.message ??
                        'No profiles match your current filters. Try relaxing some criteria.',
                    onRefresh: controller.resetFilter,
                  );
                case ApiStatus.success:
                  return _VerticalProfilesFeed(controller: controller);
              }
            }),
          ),
        ],
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

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          // Search text box
          Expanded(
            child: Container(
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
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Filter Button with Badge
          Obx(() {
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
                            : (isDark ? AppColors.darkBorder : AppColors.lightDivider),
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
          }),
          const SizedBox(width: AppSpacing.sm),
          // Notification Bell Button with unread badge
          Obx(() {
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
          }),
        ],
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
        final int max = f.ageMax ?? 60;
        chips.add(
          _FilterChipItem(
            label: 'Age: $min-$max',
            onRemove: () => controller.applyFilter(f.copyWith(clearAgeMin: true, clearAgeMax: true)),
          ),
        );
      }
      if (f.verifiedOnly) {
        chips.add(
          _FilterChipItem(
            label: 'Verified Only',
            onRemove: () => controller.applyFilter(f.copyWith(verifiedOnly: false)),
          ),
        );
      }
      if (f.photoOnly) {
        chips.add(
          _FilterChipItem(
            label: 'With Photo',
            onRemove: () => controller.applyFilter(f.copyWith(photoOnly: false)),
          ),
        );
      }
      if (f.compatibilityMin != null && f.compatibilityMin! > 0) {
        chips.add(
          _FilterChipItem(
            label: '${f.compatibilityMin}%+ Match',
            onRemove: () => controller.applyFilter(f.copyWith(clearCompatibilityMin: true)),
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
      if (f.gender != null) {
        final String g = controller.genderLabel(f.gender) ?? f.gender!;
        chips.add(
          _FilterChipItem(
            label: g,
            onRemove: () => controller.applyFilter(f.copyWith(clearGender: true)),
          ),
        );
      }
      if (f.maritalStatusId != null) {
        final String? m = controller.maritalStatusLabel(f.maritalStatusId);
        if (m != null) {
          chips.add(
            _FilterChipItem(
              label: m,
              onRemove: () => controller.applyFilter(f.copyWith(clearMaritalStatus: true)),
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
              onRemove: () => controller.applyFilter(f.copyWith(clearReligion: true)),
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
              onRemove: () => controller.applyFilter(f.copyWith(clearCaste: true)),
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
              onRemove: () => controller.applyFilter(f.copyWith(clearCity: true)),
            ),
          );
        }
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
              deleteIcon: const Icon(Icons.close_rounded, size: 13, color: AppColors.primary),
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
// Full-Screen Single User Vertical Feed
// ---------------------------------------------------------------------------

class _VerticalProfilesFeed extends StatefulWidget {
  const _VerticalProfilesFeed({required this.controller});

  final SearchProfilesController controller;

  @override
  State<_VerticalProfilesFeed> createState() => _VerticalProfilesFeedState();
}

class _VerticalProfilesFeedState extends State<_VerticalProfilesFeed> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: widget.controller.reload,
      child: Obx(() {
        final List<SearchProfileModel> visible = widget.controller.visibleProfiles;

        if (visible.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'No more profiles to show right now.',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ),
          );
        }

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: visible.length + (widget.controller.hasMore ? 1 : 0),
          onPageChanged: (int index) {
            if (index >= visible.length - 2) {
              widget.controller.loadMore();
            }
          },
          itemBuilder: (BuildContext ctx, int i) {
            if (i >= visible.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            final SearchProfileModel profile = visible[i];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88), // clears bottom navigation bar
              child: _SingleUserProfileCard(
                profile: profile,
                controller: widget.controller,
                onIgnore: () {
                  widget.controller.ignoreProfile(profile.id);
                  AppSnackbar.info('Profile ignored.');
                  if (i < visible.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            );
          },
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Single User Card matching exact reference design:
// - Left/Center: Full-Screen Portrait Photo Card
// - Right: Inside Card Action Icons (3-Dots, Interest, Full Profile, Shortlist, Ignore, Report)
// - Bottom Overlay: Name, Verification Badge, Trust Score, Religion, Country, City, Marital Status
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
    final InterestController? interestCtrl = Get.isRegistered<InterestController>()
        ? Get.find<InterestController>()
        : null;

    final String? marital = controller.maritalStatusLabel(profile.maritalStatusId);
    final String? religion = controller.religionLabel(profile.religionId);
    final String? city = controller.cityLabel(profile.cityId);
    final String? country = controller.countryLabel(profile.countryId);

    final int trustPercentage = profile.compatibilityPercentage ?? (profile.isVerified ? 80 : 70);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // ==============================================================
            // 1. Profile Picture or Styled Fallback
            // ==============================================================
            profile.hasPhoto
                ? Image.network(
                    profile.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _FallbackBackground(profile: profile),
                    loadingBuilder: (BuildContext ctx, Widget child, ImageChunkEvent? p) {
                      if (p == null) return child;
                      return _FallbackBackground(profile: profile);
                    },
                  )
                : _FallbackBackground(profile: profile),

            // ==============================================================
            // 2. Bottom Gradient Shadow for text readability & right vignette
            // ==============================================================
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0.35, 0.7, 1.0],
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.38),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),

            // ==============================================================
            // 3. RIGHT SIDE: Action Icons placed INSIDE the card
            // (3-Dots, Interest, Full Profile, Shortlist, Ignore, Report)
            // ==============================================================
            Positioned(
              right: 12,
              top: 20,
              bottom: 90,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // 1. Three-dots Menu (More options)
                  _glassIconButton(
                    icon: Icons.more_vert_rounded,
                    tooltip: 'More options',
                    onTap: () {
                      _showOptionsMenu(context);
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. Chat Icon (Direct Message)
                  _glassIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Chat',
                    onTap: () => _handleChatTap(context, profile),
                  ),
                  const SizedBox(height: 12),


                  // 3. Interest (Heart Icon)
                  Obx(() {
                    final bool hasSent = interestCtrl?.hasSentInterestTo(profile.id) == true;
                    return _glassIconButton(
                      icon: hasSent ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                      iconColor: hasSent ? const Color(0xFFE93B77) : Colors.white,
                      tooltip: 'Interest',
                      onTap: () => SendInterestDialog.show(context, profile),
                    );
                  }),
                  const SizedBox(height: 12),

                  // 4. Full Profile (Person Icon)
                  _glassIconButton(
                    icon: Icons.person_outline_rounded,
                    tooltip: 'Full Profile',
                    onTap: () => PublicProfileDetailSheet.show(
                      context,
                      profileId: profile.id,
                      searchProfile: profile,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Shortlist (Bookmark Icon)
                  Obx(() {
                    final bool isShortlisted = controller.isShortlisted(profile.id);
                    return _glassIconButton(
                      icon: isShortlisted ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                      iconColor: isShortlisted ? AppColors.gold : Colors.white,
                      tooltip: 'Shortlist',
                      onTap: () => controller.toggleShortlist(profile.id, displayName: profile.displayName),
                    );
                  }),
                  const SizedBox(height: 12),


                  // 5. Ignore (Dismiss Icon)
                  _glassIconButton(
                    icon: Icons.do_not_disturb_on_outlined,
                    tooltip: 'Ignore',
                    onTap: onIgnore,
                  ),
                  const SizedBox(height: 12),

                  // 6. Report (Flag Icon)
                  _glassIconButton(
                    icon: Icons.flag_outlined,
                    tooltip: 'Report',
                    onTap: () => ReportProfileDialog.show(context, profile),
                  ),
                ],
              ),
            ),

            // ==============================================================
            // 4. BOTTOM OVERLAY: Complete Profile Details
            // (Name, Verification Badge, Trust Score, Religion, Country, City, Marital Status)
            // ==============================================================
            Positioned(
              left: 18,
              right: 68,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Row 1: Name + Verification Icon + Trust Score Pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                profile.displayName,
                                style: AppTextStyles.display.copyWith(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Verification Status Icon
                            Icon(
                              profile.isVerified ? Icons.verified_rounded : Icons.shield_outlined,
                              color: profile.isVerified ? const Color(0xFF1DA1F2) : Colors.white70,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Trust Score Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[Color(0xFFE89538), Color(0xFFE93B77)],
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text(
                              'Trust Score ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$trustPercentage%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Colors.white24),
                  const SizedBox(height: 8),

                  // Detail rows: icon + label + value (always shown, N/A if null)
                  _detailRow(Icons.wc_rounded, 'Marital', marital ?? 'N/A'),
                  const SizedBox(height: 5),
                  _detailRow(Icons.mosque_outlined, 'Religion', religion ?? 'N/A'),
                  const SizedBox(height: 5),
                  _detailRow(Icons.location_city_rounded, 'City', city ?? 'N/A'),
                  const SizedBox(height: 5),
                  _detailRow(Icons.public_rounded, 'Country', country ?? 'N/A'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _subtitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    shadows: <Shadow>[
      Shadow(
        color: Colors.black54,
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ],
  );

  /// Icon + label + value row shown in the bottom overlay. Always shown;
  /// displays "N/A" when [value] is null or empty.
  Widget _detailRow(IconData icon, String label, String value) {
    final bool isNull = value == 'N/A';
    return Row(
      children: <Widget>[
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: _subtitleStyle.copyWith(
            fontSize: 12.5,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: _subtitleStyle.copyWith(
              fontSize: 12.5,
              color: isNull ? Colors.white38 : Colors.white,
              fontStyle: isNull ? FontStyle.italic : FontStyle.normal,
              fontWeight: isNull ? FontWeight.w300 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 22),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
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
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                title: const Text('Chat'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleChatTap(context, profile);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
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
                final ProposalController? proposalCtrl = Get.isRegistered<ProposalController>()
                    ? Get.find<ProposalController>()
                    : null;
                final bool proposed = proposalCtrl?.hasSentProposalTo(profile.id) == true;
                if (proposed) {
                  return ListTile(
                    leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                    title: const Text(
                      'Already Sent',
                      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
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
                  leading: const Icon(Icons.mail_outline_rounded, color: AppColors.primary),
                  title: const Text('Send Proposal'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    SendProposalDialog.show(context, profile);
                  },
                );
              }),

              ListTile(
                leading: const Icon(Icons.favorite_border_rounded, color: AppColors.primary),
                title: const Text('Send Interest'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  SendInterestDialog.show(context, profile);
                },
              ),

              ListTile(
                leading: const Icon(Icons.bookmark_outline_rounded, color: AppColors.gold),
                title: const Text('Shortlist'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.toggleShortlist(profile.id, displayName: profile.displayName);
                },
              ),

              ListTile(
                leading: const Icon(Icons.visibility_off_outlined, color: Colors.grey),
                title: const Text('Ignore Profile'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.ignoreProfile(profile.id);
                  AppSnackbar.info('Profile ignored.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.error),
                title: const Text('Report Profile', style: TextStyle(color: AppColors.error)),
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
    final ChatThread? thread = await chatCtrl.findExistingThreadWithUser(profile.id);
    if (thread != null && thread.id > 0) {
      ChatConversationView.open(thread);
    } else {
      if (context.mounted) {
        _showChatConnectPrompt(context, profile);
      }
    }
  }

  void _showChatConnectPrompt(BuildContext context, SearchProfileModel profile) {
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
                  child: const Icon(Icons.mark_chat_unread_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  'Connect to Chat',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Direct messaging with ${profile.displayName} is enabled once an Express Interest proposal is accepted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
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
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                    ),
                    icon: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                    label: const Text('Send Express Interest', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      SendInterestDialog.show(context, profile);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fallback background when member has no photo yet.
class _FallbackBackground extends StatelessWidget {
  const _FallbackBackground({required this.profile});

  final SearchProfileModel profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF0D9488), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 54,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              child: Text(
                profile.initial,
                style: AppTextStyles.display.copyWith(color: Colors.white, fontSize: 46),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              profile.displayName,
              style: AppTextStyles.bodyStrong.copyWith(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
