import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/proposal_extra_controller.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../repositories/proposal_extra_repository.dart';

/// The Discover "Ignored" list — every profile the member hid from their feed
/// (`GET /proposals/ignored`), each with a Restore action that removes it from
/// the server's ignored list (`DELETE /proposals/ignored/{user}`) so the
/// profile reappears in Discover.
class IgnoredProfilesView extends StatelessWidget {
  const IgnoredProfilesView({super.key});

  static void open() => Get.to<void>(() => const IgnoredProfilesView());

  ProposalExtraController get _ctrl {
    if (Get.isRegistered<ProposalExtraController>()) {
      return Get.find<ProposalExtraController>();
    }
    // Not pre-registered (e.g. a cold entry): register it for real, the same
    // wiring app_dependencies uses.
    return Get.put(
      ProposalExtraController(Get.find<ProposalExtraRepository>()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProposalExtraController c = _ctrl;
    // The list is fetched on entry; pull-to-refresh re-fetches.
    c.loadIgnored();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Ignored Profiles'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: c.loadIgnored,
        child: Obx(() {
          if (c.ignoredLoading.value && c.ignoredProfiles.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.ignoredProfiles.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 48,
                          color: AppColors.lightTextSecondary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No ignored profiles',
                          style: AppTextStyles.subtitle,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Profiles you ignore from Discover will appear here\nand can be restored any time.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: c.ignoredProfiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext ctx, int i) => _IgnoredRow(
              profile: c.ignoredProfiles[i],
              onRestore: () => c.unignoreUser(c.ignoredProfiles[i].id),
            ),
          );
        }),
      ),
    );
  }
}

/// One row: portrait (with initial fallback), name + age, and the Restore
/// button that puts the profile back into Discover.
class _IgnoredRow extends StatelessWidget {
  const _IgnoredRow({required this.profile, required this.onRestore});

  final SearchProfileModel profile;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3E2E8)),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              color: AppColors.primary.withValues(alpha: 0.08),
              child: profile.hasPhoto
                  ? Image.network(
                      profile.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          profile.initial,
                          style: AppTextStyles.title.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        profile.initial,
                        style: AppTextStyles.title.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  <String>[
                    if (profile.age != null) '${profile.age} yrs',
                    if ((profile.code ?? '').isNotEmpty) 'ID ${profile.code}',
                  ].join('  ·  '),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('Restore'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: AppTextStyles.label.copyWith(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
