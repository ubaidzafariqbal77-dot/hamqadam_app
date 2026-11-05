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
/// (`search_histories`), and this screen plays them back: tap one to re-run that
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
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadHistory());
    // Near the bottom of the list, pull the next page — the server pages at
    // 20 rows and the member's complete history must be reachable.
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _controller.loadMoreHistory();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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

  /// One human-readable line per stored filter — the COMPLETE search, not just
  /// the text term. The backend stores every query parameter it received, so
  /// the summary mirrors what the member actually picked: age range, gender,
  /// city/religion/caste names via the same lookups Discover uses, the
  /// toggles, and the sort. An empty filter set still reads as its own thing
  /// ("All profiles") instead of looking like a broken row.
  String _summary(Map<String, dynamic> item) {
    final Map<String, dynamic> filters = item['filters'] is Map<String, dynamic>
        ? item['filters'] as Map<String, dynamic>
        : <String, dynamic>{};

    String? str(String key) {
      final dynamic v = filters[key];
      final String s = v?.toString() ?? '';
      return s.trim().isEmpty ? null : s.trim();
    }

    int? intOf(String key) => int.tryParse(str(key) ?? '');

    bool flag(String key) {
      final dynamic v = filters[key];
      return v == true || v == 1 || '$v' == '1' || '$v'.toLowerCase() == 'true';
    }

    final List<String> parts = <String>[];

    // Free-text term first — it is usually what the member remembers.
    final String? search = str('search');
    if (search != null) parts.add('"$search"');

    final int? ageMin = intOf('age_min');
    final int? ageMax = intOf('age_max');
    if (ageMin != null || ageMax != null) {
      parts.add('Age ${ageMin ?? 18}-${ageMax == null || ageMax >= 60 ? '60+' : ageMax}');
    }

    final String? gender = str('gender');
    if (gender != null) {
      parts.add(gender == '1' ? 'Male' : gender == '2' ? 'Female' : gender);
    }

    // Lookup-backed names resolve through the same controller the Discover
    // feed uses; an unloaded table degrades to the next filter, never a raw id.
    final SearchProfilesController? lookups =
        Get.isRegistered<SearchProfilesController>()
            ? Get.find<SearchProfilesController>()
            : null;
    // The controller's lookup methods return String? (null = unknown id), so
    // the helper takes the nullable form directly instead of forcing a
    // non-nullable fallback that fights the signature.
    String? label(int? id, String? Function(int) fn) {
      if (id == null || id <= 0 || lookups == null) return null;
      final String? name = fn(id);
      return (name == null || name.isEmpty) ? null : name;
    }

    String? via(String? Function(int)? fn, int? id) =>
        fn == null ? null : label(id, fn);

    final String? city = via(lookups?.cityLabel, intOf('city_id'));
    final String? religion = via(lookups?.religionLabel, intOf('religion_id'));
    final String? caste = via(lookups?.casteLabel, intOf('caste_id'));
    final String? marital =
        via(lookups?.maritalStatusLabel, intOf('marital_status_id'));
    if (city != null) parts.add(city);
    if (religion != null) parts.add(religion);
    if (caste != null) parts.add(caste);
    if (marital != null) parts.add(marital);

    if (flag('verified_only')) parts.add('Verified');
    if (flag('photo_only')) parts.add('With photo');
    if (flag('new_profiles') || flag('new_this_week')) parts.add('New profiles');
    if (flag('exclude_viewed')) parts.add('Never viewed');
    if (flag('online_now')) parts.add('Online now');
    if (flag('nearby')) parts.add('Nearby');
    if (flag('mutual_match')) parts.add('Mutual match');
    if (flag('partner_preference')) parts.add('Partner match');

    final String? sort = str('sort');
    if (sort != null && parts.isNotEmpty && sort != 'newest') {
      parts.add('Sorted: ${sort.replaceAll('_', ' ')}');
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
          final bool fetchingMore = _controller.loadingMoreHistory.value;

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
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              // +1 tail row: the "load older searches" spinner while the next
              // history page streams in.
              itemCount: items.length + (fetchingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (BuildContext ctx, int i) {
                if (i >= items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                final Map<String, dynamic> item = items[i];
                final int id = (item['id'] as num?)?.toInt() ?? 0;
                final int results = (item['result_count'] as num?)?.toInt() ?? 0;
                final Map<String, dynamic> filters =
                    item['filters'] is Map<String, dynamic>
                        ? item['filters'] as Map<String, dynamic>
                        : <String, dynamic>{};
                final int filterCount = filters.entries
                    .where((MapEntry<String, dynamic> e) =>
                        e.key != 'per_page' &&
                        e.key != 'page' &&
                        '${e.value}'.trim().isNotEmpty &&
                        '${e.value}' != '0')
                    .length;

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
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_when(DateTime.tryParse('${item['created_at'] ?? ''}')?.toLocal())}'
                                      '  ·  $results result${results == 1 ? '' : 's'}'
                                      '${filterCount > 0 ? '  ·  $filterCount filter${filterCount == 1 ? '' : 's'}' : ''}',
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.clearHistory();
    }
  }
}
