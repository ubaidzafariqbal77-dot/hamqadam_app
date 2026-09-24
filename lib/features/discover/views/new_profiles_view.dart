import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../repositories/search_repository.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';
import '../widgets/discover_profile_card.dart';

/// New Profiles.
///
/// The newest members, straight from `GET /search/profiles?new_profiles=1`
/// (the API's own "joined in the last 14 days" rule) sorted by newest — the
/// same listing Discover uses, so nothing here can show a profile Discover
/// would hide. The "never viewed" switch is the same `exclude_viewed` flag the
/// filter sheet sends, which lets a member walk the new arrivals without
/// re-opening anyone.
class NewProfilesView extends StatefulWidget {
  const NewProfilesView({super.key});

  @override
  State<NewProfilesView> createState() => _NewProfilesViewState();
}

class _NewProfilesViewState extends State<NewProfilesView> {
  final SearchRepository _repo = Get.find<SearchRepository>();

  final RxList<SearchProfileModel> _profiles = <SearchProfileModel>[].obs;
  final RxBool _loading = true.obs;
  final RxBool _hideViewed = false.obs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _loading.value = true;
    _error = null;
    try {
      final SearchProfilesPage page = await _repo.fetchProfiles(
        filter: SearchFilterModel(
          // 14 days on the server, newest first.
          newProfiles: true,
          sort: 'newest',
          excludeViewed: _hideViewed.value,
        ),
        perPage: 40,
      );
      _profiles.assignAll(page.profiles);
    } catch (e) {
      _error = '$e';
    } finally {
      _loading.value = false;
    }
  }

  /// "Joined 3 days ago" / "New today" — read from the member's own join date.
  static String _joined(DateTime? createdAt) {
    if (createdAt == null) return '';
    final Duration gap = DateTime.now().difference(createdAt);
    if (gap.inHours < 24) return 'Joined today';
    if (gap.inDays == 1) return 'Joined yesterday';
    return 'Joined ${gap.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PremiumAppBar(
        title: 'New Profiles',
        subtitle: 'Members who joined recently',
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
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Obx(() => FilterChip(
                    label: const Text('Hide profiles I have opened'),
                    avatar: const Icon(Icons.visibility_off_outlined, size: 16),
                    selected: _hideViewed.value,
                    selectedColor: AppColors.roseSelectedFill,
                    onSelected: (bool value) {
                      _hideViewed.value = value;
                      _load();
                    },
                  )),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return Obx(() {
      if (_loading.value && _profiles.isEmpty) return const SkeletonList();
      if (_error != null && _profiles.isEmpty) {
        return ErrorStateWidget(message: _error, onRetry: _load);
      }
      if (_profiles.isEmpty) {
        return EmptyStateWidget(
          title: 'No new profiles',
          message: _hideViewed.value
              ? 'Every recent joiner has already been viewed by you. Turn the '
                  'switch off to see them again.'
              : 'Nobody has joined in the last two weeks. Pull down to check '
                  'again.',
          onRefresh: _load,
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          itemCount: _profiles.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (BuildContext ctx, int i) {
            final SearchProfileModel profile = _profiles[i];
            final String joined = _joined(profile.createdAt);
            return DiscoverProfileCard(
              profile: profile,
              badgeLabel: joined.isEmpty ? 'New' : joined,
              badgeIcon: Icons.fiber_new_rounded,
            );
          },
        ),
      );
    });
  }
}
