import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/registration_sections.dart';
import '../../../controllers/registration_controller.dart';
import '../../../core/storage/profile_completion_service.dart';
import '../../../widgets/bilingual_text.dart';

/// "Complete your profile" — the hub for every registration section the user
/// skipped (or has not filled yet).
///
/// The ring at the top is the profile-completion graph: it counts only sections
/// that actually hold data, so skipping never inflates it and each section the
/// user finishes here moves it up. Tapping a pending section reopens that exact
/// registration step in edit mode, and saving submits just that section.
class ProfileCompletionView extends StatelessWidget {
  const ProfileCompletionView({super.key});

  /// Icon per registration section (keyed by step number).
  static const Map<int, IconData> _icons = <int, IconData>{
    1: Icons.favorite_border_rounded, // marriage plans
    3: Icons.mosque_outlined, // religion & language
    4: Icons.place_outlined, // location
    6: Icons.groups_2_outlined, // caste
    7: Icons.handshake_outlined, // marital status
    8: Icons.school_outlined, // education
    9: Icons.straighten_rounded, // physical
    10: Icons.work_outline_rounded, // career & income
    12: Icons.photo_camera_outlined, // photos
    13: Icons.edit_note_rounded, // about yourself
    14: Icons.verified_user_outlined, // verification
    15: Icons.interests_outlined, // interests
    16: Icons.family_restroom_rounded, // family information
    17: Icons.home_work_outlined, // family details
    18: Icons.people_outline_rounded, // partner preferences
  };

  /// Titles that read better here than the signup wording ("Account for" is
  /// where the marriage plans are collected).
  static const Map<int, String> _titles = <int, String>{1: 'Marriage plans'};

  @override
  Widget build(BuildContext context) {
    final ProfileCompletionService completion = Get.find<ProfileCompletionService>();
    final RegistrationController reg = Get.find<RegistrationController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            _ProgressHeader(completion: completion),
            const SizedBox(height: AppSpacing.lg),
            BiText(
              completion.isComplete
                  ? 'Everything is filled in'
                  : 'Sections you can still complete',
              style: AppTextStyles.bodyStrong,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...RegSections.profile.map(
              (int step) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SectionTile(
                  title: _titles[step] ?? reg.metaFor(step).title,
                  icon: _icons[step] ?? Icons.check_circle_outline_rounded,
                  done: completion.isDone(step),
                  skipped: completion.isSkipped(step),
                  onTap: () => reg.openSection(step),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.completion});

  final ProfileCompletionService completion;

  @override
  Widget build(BuildContext context) {
    final int pct = completion.percent;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xlAll,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: completion.fraction),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext c, double v, _) => SizedBox(
                    width: 74,
                    height: 74,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 7,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                Text(
                  '$pct%',
                  style: AppTextStyles.bodyStrong.copyWith(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${completion.doneCount} of ${completion.totalCount} sections done',
                  style: AppTextStyles.title.copyWith(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 4),
                BiText(
                  completion.isComplete
                      ? 'Your profile is complete.'
                      : 'Complete the remaining sections to get better matches.',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                  urduColor: Colors.white70,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.title,
    required this.icon,
    required this.done,
    required this.skipped,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool done;
  final bool skipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = done
        ? AppColors.success
        : (skipped ? AppColors.warning : AppColors.primary);
    final String statusLabel = done ? 'Completed' : (skipped ? 'Skipped' : 'Not added');

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: AppRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(done ? Icons.check_rounded : icon, color: statusColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    BiText(title, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                done ? Icons.edit_outlined : Icons.arrow_forward_ios_rounded,
                size: done ? 18 : 15,
                color: Theme.of(context).hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
