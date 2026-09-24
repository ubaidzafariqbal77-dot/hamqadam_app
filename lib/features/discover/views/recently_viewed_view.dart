import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../controllers/search_extra_controller.dart';
import '../../../repositories/discover_extra_repository.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../widgets/discover_profile_card.dart';

/// Recently Viewed Profiles.
///
/// The members this account has opened, newest first, from
/// `GET /profile-views` — the API's own record, so it stays right across
/// reinstall and never disagrees with what the profile-view balance counted.
class RecentlyViewedView extends StatefulWidget {
  const RecentlyViewedView({super.key});

  @override
  State<RecentlyViewedView> createState() => _RecentlyViewedViewState();
}

class _RecentlyViewedViewState extends State<RecentlyViewedView> {
  final SearchExtraController _controller = Get.find<SearchExtraController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _controller.loadRecentlyViewed());
  }

  /// "2 h ago" style gap, matching the rest of the app's lists.
  static String _ago(DateTime? at) {
    if (at == null) return '';
    final Duration gap = DateTime.now().difference(at);
    if (gap.inMinutes < 1) return 'just now';
    if (gap.inMinutes < 60) return '${gap.inMinutes} min ago';
    if (gap.inHours < 24) return '${gap.inHours} h ago';
    if (gap.inDays == 1) return 'yesterday';
    if (gap.inDays < 7) return '${gap.inDays} days ago';
    return '${at.day}/${at.month}/${at.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PremiumAppBar(
        title: 'Recently Viewed',
        subtitle: 'Profiles you opened',
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.chatCanvasTop,
              AppColors.chatCanvasBottom,
            ],
          ),
        ),
        child: Obx(() {
          final bool loading = _controller.loadingRecentlyViewed.value;
          final List<ViewedProfile> items = _controller.recentlyViewed;

          if (loading && items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (items.isEmpty) {
            return const EmptyStateWidget(
              title: 'Nothing viewed yet',
              message: 'Profiles you open from Discover show up here, so you '
                  'can find them again without searching twice.',
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _controller.loadRecentlyViewed,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext ctx, int i) {
                final ViewedProfile view = items[i];
                final String when = _ago(view.viewedAt);
                return DiscoverProfileCard(
                  profile: view.profile,
                  badgeLabel: when.isEmpty ? null : when,
                  badgeIcon: Icons.visibility_outlined,
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
