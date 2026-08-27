import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/profile_view_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/chat_model.dart';
import '../../../models/lookup_item_model.dart';
import '../../../models/profile_view_model.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../../chat/views/chat_conversation_view.dart';
import '../../discover/widgets/public_profile_detail_sheet.dart';
import '../../discover/widgets/send_interest_dialog.dart';

/// Full screen displaying members who viewed the user's profile and profiles the user viewed,
/// with package balance & view allowance summary.
class ProfileViewsView extends StatefulWidget {
  const ProfileViewsView({super.key});

  @override
  State<ProfileViewsView> createState() => _ProfileViewsViewState();
}

class _ProfileViewsViewState extends State<ProfileViewsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ProfileViewController _controller = Get.find<ProfileViewController>();
  final ScrollController _receivedScrollCtrl = ScrollController();
  final ScrollController _myViewsScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _controller.activeTabIndex.value,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _controller.activeTabIndex.value = _tabController.index;
      }
    });

    _receivedScrollCtrl.addListener(() {
      if (_receivedScrollCtrl.position.pixels >=
          _receivedScrollCtrl.position.maxScrollExtent - 200) {
        _controller.loadMoreReceived();
      }
    });

    _myViewsScrollCtrl.addListener(() {
      if (_myViewsScrollCtrl.position.pixels >=
          _myViewsScrollCtrl.position.maxScrollExtent - 200) {
        _controller.loadMoreMyViews();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _receivedScrollCtrl.dispose();
    _myViewsScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: const PremiumAppBar(
        title: 'Profile Views',
        subtitle: 'Track visitors & your viewed profiles',
      ),
      body: Column(
        children: <Widget>[
          // Top Balance & Package Summary Card
          _buildBalanceCard(isDark),

          // Segmented Tabs Header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
              ),
            ),
            child: Obx(() {
              final int receivedCount = _controller.totalReceivedCount.value;
              final int myViewsCount = _controller.totalMyViewsCount.value;

              return TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.brandGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                tabs: <Widget>[
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.remove_red_eye_rounded, size: 16),
                        const SizedBox(width: 6),
                        const Text('Who Viewed Me'),
                        if (receivedCount > 0) ...<Widget>[
                          const SizedBox(width: 6),
                          _CountBadge(count: receivedCount),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.history_rounded, size: 16),
                        const SizedBox(width: 6),
                        const Text('Profiles I Viewed'),
                        if (myViewsCount > 0) ...<Widget>[
                          const SizedBox(width: 6),
                          _CountBadge(count: myViewsCount),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                // 1. Who Viewed Me Tab
                _buildReceivedTab(),
                // 2. Profiles I Viewed Tab
                _buildMyViewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(bool isDark) {
    return Obx(() {
      final ProfileViewSummary? sum = _controller.summary.value;
      final int remaining = sum?.remainingViews ?? 0;
      final int used = sum?.usedViews ?? 0;
      final bool isActive = sum?.isActive ?? false;
      final String? validity = sum?.packageValidity;

      return Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? <Color>[const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : <Color>[const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                // Remaining Views Pill
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.visibility_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Remaining Views',
                                style: AppTextStyles.caption.copyWith(
                                  color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '$remaining',
                                style: AppTextStyles.title.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Used Views Pill
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppColors.gold,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Used Views',
                                style: AppTextStyles.caption.copyWith(
                                  color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '$used',
                                style: AppTextStyles.title.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Package validity footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      isActive ? Icons.verified_rounded : Icons.info_outline_rounded,
                      size: 14,
                      color: isActive ? AppColors.success : AppColors.lightTextHint,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isActive ? 'Package Active' : 'Package Inactive',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.success : AppColors.lightTextHint,
                      ),
                    ),
                  ],
                ),
                if (validity != null && validity.isNotEmpty)
                  Text(
                    'Validity: $validity',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildReceivedTab() {
    return Obx(() {
      final ApiState<List<ProfileViewItem>> state = _controller.receivedState.value;
      switch (state.status) {
        case ApiStatus.initial:
        case ApiStatus.loading:
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        case ApiStatus.noInternet:
          return NoInternetWidget(onRetry: () => _controller.loadReceived(refresh: true));
        case ApiStatus.serverError:
        case ApiStatus.unauthorized:
        case ApiStatus.validationError:
          return ErrorStateWidget(
            message: state.message ?? 'Failed to load profile views.',
            onRetry: () => _controller.loadReceived(refresh: true),
          );
        case ApiStatus.empty:
          return const EmptyStateWidget(
            title: 'No Profile Visitors',
            message: 'No members have viewed your profile yet. Boost your activity by expressing interest!',
          );
        case ApiStatus.success:
          final List<ProfileViewItem> list = state.data ?? <ProfileViewItem>[];
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _controller.loadReceived(refresh: true),
            child: ListView.builder(
              controller: _receivedScrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 80),
              itemCount: list.length + (_controller.isLoadingMoreReceived.value ? 1 : 0),
              itemBuilder: (BuildContext ctx, int i) {
                if (i >= list.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  );
                }
                return _ProfileViewCard(
                  item: list[i],
                  isReceived: true,
                );
              },
            ),
          );
      }
    });
  }

  Widget _buildMyViewsTab() {
    return Obx(() {
      final ApiState<List<ProfileViewItem>> state = _controller.myViewsState.value;
      switch (state.status) {
        case ApiStatus.initial:
        case ApiStatus.loading:
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        case ApiStatus.noInternet:
          return NoInternetWidget(onRetry: () => _controller.loadMyViews(refresh: true));
        case ApiStatus.serverError:
        case ApiStatus.unauthorized:
        case ApiStatus.validationError:
          return ErrorStateWidget(
            message: state.message ?? 'Failed to load viewed profiles.',
            onRetry: () => _controller.loadMyViews(refresh: true),
          );
        case ApiStatus.empty:
          return const EmptyStateWidget(
            title: 'No Viewed Profiles',
            message: 'You have not viewed any member profiles yet. Discover matches now!',
          );
        case ApiStatus.success:
          final List<ProfileViewItem> list = state.data ?? <ProfileViewItem>[];
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _controller.loadMyViews(refresh: true),
            child: ListView.builder(
              controller: _myViewsScrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 80),
              itemCount: list.length + (_controller.isLoadingMoreMyViews.value ? 1 : 0),
              itemBuilder: (BuildContext ctx, int i) {
                if (i >= list.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  );
                }
                return _ProfileViewCard(
                  item: list[i],
                  isReceived: false,
                );
              },
            ),
          );
      }
    });
  }
}

/// Profile view list tile card
class _ProfileViewCard extends StatelessWidget {
  const _ProfileViewCard({
    required this.item,
    required this.isReceived,
  });

  final ProfileViewItem item;
  final bool isReceived;

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('d MMM yyyy').format(date);
    }
  }

  String _resolveLocation(SearchProfileModel p, LookupController lookup) {
    final String? city = lookup.nameOf(LookupKeys.cities, p.cityId);
    final String? country = lookup.nameOf(LookupKeys.countries, p.countryId);
    final List<String> parts = <String>[
      if (city != null && city.isNotEmpty) city,
      if (country != null && country.isNotEmpty) country,
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final LookupController lookup = Get.find<LookupController>();
    final SearchProfileModel profile = item.profile;

    final String? religion = lookup.nameOf(LookupKeys.religions, profile.religionId);
    final String? caste = lookup.nameOf(LookupKeys.castes, profile.casteId);
    final String location = _resolveLocation(profile, lookup);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => PublicProfileDetailSheet.show(
          context,
          profileId: profile.id,
          name: profile.displayName,
          photo: profile.photoUrl,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Top Row: Avatar + Details + Timestamp
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Avatar
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: AppColors.brandGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profile.photoUrl != null
                          ? Image.network(
                              profile.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Text(
                                  profile.initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                profile.initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Middle Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                profile.displayName,
                                style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile.isVerified) ...<Widget>[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                            ],
                          ],
                        ),
                        if (profile.code != null && profile.code!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${profile.code}',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.lightTextHint,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),

                        // Subtitle: Age, Religion, Caste, Location
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: <Widget>[
                            if (profile.ageLabel.isNotEmpty)
                              Text(
                                profile.ageLabel,
                                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                              ),
                            if (religion != null && religion.isNotEmpty) ...<Widget>[
                              Text('•', style: AppTextStyles.caption),
                              Text(religion, style: AppTextStyles.caption),
                            ],
                            if (caste != null && caste.isNotEmpty) ...<Widget>[
                              Text('•', style: AppTextStyles.caption),
                              Text(caste, style: AppTextStyles.caption),
                            ],
                            if (location.isNotEmpty) ...<Widget>[
                              Text('•', style: AppTextStyles.caption),
                              Text(location, style: AppTextStyles.caption),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Timestamp Badge
                  if (item.viewedAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceAlt : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _formatTime(item.viewedAt),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.lightDivider),
              const SizedBox(height: AppSpacing.xs),

              // Bottom Action Bar: View Profile & Chat
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.person_outline_rounded, size: 16),
                      label: const Text('Full Profile', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
                        ),
                      ),
                      onPressed: () => PublicProfileDetailSheet.show(
                        context,
                        profileId: profile.id,
                        name: profile.displayName,
                        photo: profile.photoUrl,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                      label: const Text('Chat', style: TextStyle(fontSize: 12.5, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final ChatController chatCtrl = Get.find<ChatController>();
                        final ChatThread? thread = await chatCtrl.findExistingThreadWithUser(profile.id);
                        if (thread != null && thread.id > 0) {
                          ChatConversationView.open(thread);
                        } else if (context.mounted) {
                          SendInterestDialog.show(
                            context,
                            SearchProfileModel(
                              id: profile.id,
                              name: profile.name,
                              code: profile.code,
                              photo: profile.photo,
                              age: profile.age,
                              gender: profile.gender,
                              cityId: profile.cityId,
                              stateId: profile.stateId,
                              countryId: profile.countryId,
                              identityVerified: profile.identityVerified,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

extension on LookupController {
  String? nameOf(String key, int? id) {
    if (id == null) return null;
    final List<LookupItem> items = itemsOf(key);
    for (final LookupItem item in items) {
      if (item.id == id) return item.name;
    }
    return null;
  }
}
