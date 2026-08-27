import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/interest_controller.dart';
import '../../../controllers/search_profiles_controller.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../widgets/app_button.dart';
import 'send_interest_dialog.dart';

/// Bottom modal sheet displaying complete details of a selected member profile.
class PublicProfileDetailSheet extends StatelessWidget {
  const PublicProfileDetailSheet({super.key, required this.profile});

  final SearchProfileModel profile;

  static void show(BuildContext context, SearchProfileModel profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => PublicProfileDetailSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final SearchProfilesController searchCtrl = Get.find<SearchProfilesController>();
    final InterestController? interestCtrl = Get.isRegistered<InterestController>()
        ? Get.find<InterestController>()
        : null;

    final String? religion = searchCtrl.religionLabel(profile.religionId);
    final String? caste = searchCtrl.casteLabel(profile.casteId);
    final String? marital = searchCtrl.maritalStatusLabel(profile.maritalStatusId);
    final String location = searchCtrl.formatLocation(profile);
    final String? gender = searchCtrl.genderLabel(profile.gender);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.hintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            // Header Image / Gradient Hero
            Stack(
              children: <Widget>[
                Container(
                  height: 170,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.brandGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: profile.hasPhoto
                      ? Image.network(
                          profile.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        )
                      : null,
                ),
                Container(
                  height: 170,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                if (profile.compatibilityPercentage != null)
                  Positioned(
                    top: 14,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.favorite_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${profile.compatibilityPercentage}% Match',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage:
                              profile.hasPhoto ? NetworkImage(profile.photoUrl!) : null,
                          child: !profile.hasPhoto
                              ? Text(
                                  profile.initial,
                                  style: AppTextStyles.title.copyWith(color: Colors.white),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    profile.displayName,
                                    style: AppTextStyles.title.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (profile.isVerified) ...<Widget>[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                                ],
                              ],
                            ),
                            if (profile.code != null)
                              Text(
                                'ID: ${profile.code}',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Profile details list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  // Key attributes strip
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (profile.age != null)
                        _infoChip(Icons.cake_outlined, '${profile.age} Years'),
                      if (profile.heightFormatted != null)
                        _infoChip(Icons.height_rounded, profile.heightFormatted!),
                      if (gender != null)
                        _infoChip(Icons.person_outline_rounded, gender),
                      if (marital != null)
                        _infoChip(Icons.favorite_border_rounded, marital),
                      if (location.isNotEmpty)
                        _infoChip(Icons.location_on_outlined, location),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Detail rows
                  _detailTile('Religion', religion ?? 'Not specified', Icons.mosque_outlined),
                  _detailTile('Caste / Community', caste ?? 'Not specified', Icons.diversity_3_outlined),
                  _detailTile('Location', location.isNotEmpty ? location : 'Not specified', Icons.map_outlined),
                  _detailTile(
                    'Identity Verification',
                    profile.isVerified ? 'Verified Member' : 'Pending Verification',
                    profile.isVerified ? Icons.verified_rounded : Icons.shield_outlined,
                    iconColor: profile.isVerified ? AppColors.info : AppColors.warning,
                  ),
                  if (profile.membership != null)
                    _detailTile('Membership Plan', 'Tier ${profile.membership}', Icons.workspace_premium_outlined),
                ],
              ),
            ),
            // Connect Button
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBackground,
                border: const Border(top: BorderSide(color: AppColors.lightDivider)),
              ),
              child: Obx(() {
                final bool alreadySent = interestCtrl?.hasSentInterestTo(profile.id) == true;
                if (alreadySent) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Interest Already Sent',
                          style: AppTextStyles.bodyStrong.copyWith(color: AppColors.success),
                        ),
                      ],
                    ),
                  );
                }
                return AppButton(
                  label: 'Express Interest',
                  icon: Icons.favorite_rounded,
                  onPressed: () => SendInterestDialog.show(context, profile),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value, IconData icon, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.lightTextHint)),
                Text(value, style: AppTextStyles.bodyStrong),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
