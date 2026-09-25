import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/search_extra_controller.dart';
import '../../../controllers/search_profiles_controller.dart';
import '../../../features/auth/views/home_view.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../repositories/search_extra_repository.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/premium_app_bar.dart';

/// Saved searches: re-apply a saved filter to Discover with one tap, or remove
/// it. The apply flow rebuilds a [SearchFilterModel] from the stored filter
/// map, hands it to the Discover controller, and lands the member on the
/// Discover tab.
class SavedSearchesView extends StatefulWidget {
  const SavedSearchesView({super.key});

  @override
  State<SavedSearchesView> createState() => _SavedSearchesViewState();
}

class _SavedSearchesViewState extends State<SavedSearchesView> {
  final SearchExtraController _controller = Get.find<SearchExtraController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadSaved());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.roseCanvas,
      appBar: const PremiumAppBar(title: 'Saved Searches', subtitle: 'Your favourite filter combinations'),
      body: Obx(() {
        if (_controller.loading.value) {
          return const Center(child: CircularProgressIndicator(color: AppColors.regAccent));
        }

        final List<Map<String, dynamic>> items = _controller.savedSearches;

        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.bookmark_border_rounded, size: 52,
                      color: Theme.of(context).hintColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 14),
                  Text('No saved searches yet', style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 6),
                  Text(
                    'Set your filters on the Discover tab, then save the combination to re-run it any time.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.regAccent,
                      side: const BorderSide(color: AppColors.regAccent),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                    ),
                    onPressed: () => Get.back<void>(),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Go to Discover'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.regAccent,
          onRefresh: () => _controller.loadSaved(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (BuildContext ctx, int i) => _SavedSearchCard(item: items[i]),
          ),
        );
      }),
    );
  }
}

class _SavedSearchCard extends StatelessWidget {
  const _SavedSearchCard({required this.item});

  final Map<String, dynamic> item;

  /// Human summary of what this saved search looks for.
  String _summary() {
    final List<String> parts = <String>[];
    final int? ageMin = (item['age_min'] as num?)?.toInt();
    final int? ageMax = (item['age_max'] as num?)?.toInt();
    if (ageMin != null || ageMax != null) {
      parts.add('Age ${ageMin ?? 18}–${ageMax ?? '30+'}');
    }
    final String? city = item['city_name']?.toString();
    final String? country = item['country_name']?.toString();
    if (city != null && city.isNotEmpty) parts.add(city);
    if ((country != null && country.isNotEmpty) && city != country) parts.add(country);
    if (item['verified_only'] == true || item['verified_only'] == 1) parts.add('Verified');
    if (item['photo_only'] == true || item['photo_only'] == 1) parts.add('With photo');
    if (parts.isEmpty) return 'All profiles';
    return parts.join(' · ');
  }

  Future<void> _apply() async {
    final SearchFilterModel filter = SearchExtraRepository.savedToFilter(item);
    if (Get.isRegistered<SearchProfilesController>()) {
      final SearchProfilesController discover = Get.find<SearchProfilesController>();
      discover.applyFilter(filter);
    }
    AppSnackbar.success('Search applied — showing best matches.');
    // Land the member on the Discover tab with the filter active.
    Get.back<void>();
    HomeView.goToTab(0);
  }

  @override
  Widget build(BuildContext context) {
    final SearchExtraController controller = Get.find<SearchExtraController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int id = (item['id'] as num?)?.toInt() ?? 0;
    final String name = (item['name'] ?? 'Saved search').toString();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.regAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bookmark_rounded, color: AppColors.regAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(_summary(),
                    style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.regAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            ),
            onPressed: _apply,
            child: const Text('Apply', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline_rounded, size: 20,
                color: AppColors.error.withValues(alpha: 0.8)),
            onPressed: () {
              Get.defaultDialog<void>(
                title: 'Delete search?',
                titleStyle: AppTextStyles.bodyStrong,
                middleText: '"$name" will be removed from your saved searches.',
                middleTextStyle: AppTextStyles.caption,
                textCancel: 'Keep',
                textConfirm: 'Delete',
                confirmTextColor: Colors.white,
                buttonColor: AppColors.error,
                onConfirm: () {
                  controller.deleteSaved(id);
                  Get.back<void>();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
