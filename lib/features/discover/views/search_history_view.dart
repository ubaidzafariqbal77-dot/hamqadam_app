import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/search_extra_controller.dart';
import '../../../controllers/search_profiles_controller.dart';
import '../../../repositories/search_extra_repository.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../../auth/views/home_view.dart';

/// Search History.
///
/// Every `GET /search/profiles` the server saw is recorded against the member
/// (`search_history`), and this screen plays them back: tap one to re-run that
/// exact search, swipe one away to forget it, or clear the lot. History is a
/// convenience, not a record — so clearing it is two taps, not a support
/// request.
class SearchHistoryView extends StatefulWidget {
  const SearchHistoryView({super.key});

  @override
  State<SearchHistoryView> createState() => _SearchHistoryViewState();
}

class _SearchHistoryViewState extends State<SearchHistoryView> {
  final SearchExtraController _controller = Get.find<SearchExtraController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadHistory());
  }

  /// Re-runs a recorded search: rebuild the filter the API stored, hand it to
  /// Discover and land the member there.
  Future<void> _apply(Map<String, dynamic> item) async {
    final Map<String, dynamic> filters = item['filters'] is Map<String, dynamic>
        ? item['filters'] as Map<String, dynamic>
        : <String, dynamic>{};
    if (filters.isEmpty) {
      AppSnackbar.info('This search has no filters to re-apply.');
      return;
    }

    if (Get.isRegistered<SearchProfilesController>()) {
      Get.find<SearchProfilesController>()
          .applyFilter(SearchExtraRepository.savedToFilter(filters));
    }
    AppSnackbar.success('Search applied.');
    Get.back<void>();
    HomeView.goToTab(0);
  }

  String _summary(Map<String, dynamic> item) {
    final Map<String, dynamic> filters = item['filters'] is Map<String, dynamic>
        ? item['filters'] as Map<String, dynamic>
        : <String, dynamic>{};
    final List<String> parts = <String>[];

    final int? ageMin = (filters['age_min'] as num?)?.toInt();
    final int? ageMax = (filters['age_max'] as num?)?.toInt();
    if (ageMin != null || ageMax != null) {
      parts.add('Age ${ageMin ?? 18}–${ageMax ?? '30+'}');
    }
    final String? search = filters['search']?.toString();
    if (search != null && search.isNotEmpty) parts.add('“$search”');
    if (filters['verified_only'] == true || filters['verified_only'] == 1) {
      parts.add('Verified');
    }
    if (filters['photo_only'] == true || filters['photo_only'] == 1) {
      parts.add('With photo');
    }
    if (filters['new_profiles'] == true || filters['new_profiles'] == 1) {
      parts.add('New profiles');
    }
    if (filters['exclude_viewed'] == true || filters['exclude_viewed'] == 1) {
      parts.add('Never viewed');
    }
    if (filters['partner_preference'] == true ||
        filters['partner_preference'] == 1 ||
        filters['partner_preference'] == 'true') {
      parts.add('Partner match');
    }

    if (parts.isEmpty) return 'All profiles';
    return parts.join('  ·  ');
  }

  static String _when(DateTime? at) {
    if (at == null) return '';
    final Duration gap = DateTime.now().difference(at);
    if (gap.inMinutes < 1) return 'Just now';
    if (gap.inMinutes < 60) return '${gap.inMinutes} min ago';
    if (gap.inHours < 24) return '${gap.inHours} h ago';
    if (gap.inDays == 1) return 'Yesterday';
    if (gap.inDays < 7) return '${gap.inDays} d ago';
    return '${at.day}/${at.month}/${at.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Search History',
        subtitle: 'Searches you have run',
        actions: <Widget>[
          Obx(() {
            final bool hasHistory = _controller.searchHistory.isNotEmpty;
            final bool busy = _controller.clearingHistory.value;
            return IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: (hasHistory && !busy) ? _confirmClear : null,
            );
          }),
        ],
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
          final bool loading = _controller.loading.value;
          final List<Map<String, dynamic>> items = _controller.searchHistory;

          if (loading && items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (items.isEmpty) {
            return const EmptyStateWidget(
              title: 'No searches yet',
              message: 'Filters you apply in Discover are listed here so you '
                  'can run them again with one tap.',
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _controller.loadHistory,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (BuildContext ctx, int i) {
                final Map<String, dynamic> item = items[i];
                final int id = (item['id'] as num?)?.toInt() ?? 0;
                final int results = (item['result_count'] as num?)?.toInt() ?? 0;

                return Dismissible(
                  key: ValueKey<int>(id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error),
                  ),
                  onDismissed: (_) => _controller.deleteHistoryEntry(id),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () => _apply(item),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: AppColors.chatCardFill,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.chatCardBorder),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.history_rounded,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      _summary(item),
                                      style: AppTextStyles.bodyStrong.copyWith(
                                        fontSize: 14,
                                        color: AppColors.roseTitleInk,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_when(DateTime.tryParse('${item['created_at'] ?? ''}'))}'
                                      '  ·  $results result${results == 1 ? '' : 's'}',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 11.5,
                                        color: AppColors.chatTimeInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.replay_rounded,
                                  size: 18, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text('Clear search history?'),
        content: const Text(
          'Every recorded search will be removed from your account.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _controller.clearHistory();
  }
}
