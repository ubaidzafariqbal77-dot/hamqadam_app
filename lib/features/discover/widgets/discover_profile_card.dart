import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/search_profiles_controller.dart';
import '../../../models/search_filter_profile_model.dart';
import 'public_profile_detail_sheet.dart';

/// One member, as every Discover sub-screen lists them.
///
/// Search, Swipe Matching, Interest-Based Recommendations, New Profiles and
/// Recently Viewed all show the same row — photo, name, the facts a member
/// scans for (age · height · city) and whatever score the screen is about.
/// Sharing one card keeps those screens from drifting apart, and it takes its
/// data only from [SearchProfileModel], so nothing here invents a value the
/// API did not send.
class DiscoverProfileCard extends StatelessWidget {
  const DiscoverProfileCard({
    super.key,
    required this.profile,
    this.trailing,
    this.badgeLabel,
    this.badgeIcon,
    this.footnote,
    this.onTap,
  });

  final SearchProfileModel profile;

  /// Action buttons on the right (e.g. the deck's pass/like pair).
  final Widget? trailing;

  /// Small rose chip above the name — "74% interests", "New", "2d ago".
  final String? badgeLabel;
  final IconData? badgeIcon;

  /// Line under the meta row, e.g. the shared interests a recommendation
  /// matched on.
  final String? footnote;

  final VoidCallback? onTap;

  String get _metaLine {
    final List<String> parts = <String>[];
    if (profile.age != null) parts.add('${profile.age} yrs');
    final String? height = profile.heightFormatted;
    if (height != null) parts.add(height);
    final String? city = _cityName();
    if (city != null) parts.add(city);
    return parts.join('  ·  ');
  }

  /// City arrives as a lookup id, so it is resolved through the same controller
  /// the Discover feed uses — and omitted rather than rendered as a raw id when
  /// the lookup tables have not loaded.
  String? _cityName() {
    final int? id = profile.cityId;
    if (id == null || id <= 0) return null;
    if (!Get.isRegistered<SearchProfilesController>()) return null;
    final String? name = Get.find<SearchProfilesController>().cityLabel(id);
    return (name == null || name.isEmpty) ? null : name;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = (profile.photo ?? '').isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap ??
            () => PublicProfileDetailSheet.show(
                  context,
                  profileId: profile.id,
                  name: profile.name,
                  photo: profile.photo,
                  searchProfile: profile,
                ),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.chatCardFill,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.chatCardBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 16,
                spreadRadius: -4,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    width: 64,
                    height: 76,
                    child: hasPhoto
                        ? Image.network(
                            profile.photo!,
                            fit: BoxFit.cover,
                            // A dead photo URL must not blank the whole row.
                            errorBuilder: (_, __, ___) =>
                                _Initial(name: profile.name),
                          )
                        : _Initial(name: profile.name),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (badgeLabel != null) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.roseSelectedFill,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (badgeIcon != null) ...<Widget>[
                                Icon(
                                  badgeIcon,
                                  size: 12,
                                  color: AppColors.chatPillInk,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                badgeLabel!,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.chatPillInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        profile.name ?? 'Member',
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 15.5,
                          color: AppColors.roseTitleInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_metaLine.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          _metaLine,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12.5,
                            color: AppColors.chatPreviewInk,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          if (profile.identityVerified) ...<Widget>[
                            const Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (profile.compatibilityPercentage != null) ...<Widget>[
                            const Icon(
                              Icons.favorite_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${profile.compatibilityPercentage}% match',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (footnote != null && footnote!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          footnote!,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: AppColors.chatTimeInk,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final String initial =
        (name ?? '').trim().isEmpty ? '?' : name!.trim()[0].toUpperCase();
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.14),
      child: Center(
        child: Text(
          initial,
          style: AppTextStyles.title.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
