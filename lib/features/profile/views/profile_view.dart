import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/profile_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/storage/profile_completion_service.dart';
import '../../../models/ai_verification_model.dart';
import '../../../models/profile_model.dart';
import '../../../widgets/state_widgets.dart';
import 'edit_profile_view.dart';

/// Premium, fully dynamic profile screen backed by [ProfileController]
/// (`GET /api/v1/profile`). Rendered as the "Profile" tab body inside the
/// authenticated home shell.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController c = Get.find<ProfileController>();
    return Obx(() {
      final ApiState<ProfileModel> s = c.state.value;
      switch (s.status) {
        case ApiStatus.initial:
        case ApiStatus.loading:
          return const _LoadingState();
        case ApiStatus.noInternet:
          return NoInternetWidget(onRetry: c.load);
        case ApiStatus.unauthorized:
        case ApiStatus.serverError:
        case ApiStatus.validationError:
          return ErrorStateWidget(message: s.message, onRetry: c.load);
        case ApiStatus.empty:
          return ErrorStateWidget(
            title: 'No profile yet',
            message: 'We couldn’t find your profile details.',
            onRetry: c.load,
          );
        case ApiStatus.success:
          return _ProfileBody(controller: c, profile: s.data!);
      }
    });
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.controller, required this.profile});

  final ProfileController controller;
  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          // Clear the floating bottom nav.
          AppSpacing.xxxl + AppSpacing.xl,
        ),
        children: <Widget>[
          _HeaderCard(controller: controller, profile: profile),
          const SizedBox(height: AppSpacing.md),
          // Only while unverified: the same prompt the web dashboard shows, so
          // a member who was sent away from the signup gate unverified has an
          // obvious way back in.
          if (!profile.verification.identityVerified) ...<Widget>[
            _VerificationBanner(verification: profile.verification),
            const SizedBox(height: AppSpacing.md),
          ],
          const _CompletionCard(),
          const SizedBox(height: AppSpacing.md),
          const _QuickActionsCard(),
          const SizedBox(height: AppSpacing.md),
          if (_hasIntro(profile.member)) ...<Widget>[
            _IntroMediaCard(member: profile.member),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_notEmpty(profile.member.aboutMe) ||
              _notEmpty(profile.member.aiGeneratedBio)) ...<Widget>[
            _AboutCard(member: profile.member),
            const SizedBox(height: AppSpacing.md),
          ],
          _DetailsCard(controller: controller, member: profile.member),
          const SizedBox(height: AppSpacing.md),
          if (_notEmpty(profile.member.travelPreferences) ||
              _notEmpty(profile.member.futureGoals)) ...<Widget>[
            _AspirationsCard(member: profile.member),
            const SizedBox(height: AppSpacing.md),
          ],
          _PrivacyCard(privacy: profile.privacy),
        ],
      ),
    );
  }

  static bool _hasIntro(MemberDetails m) =>
      _notEmpty(m.videoIntroUrl) || _notEmpty(m.voiceIntroUrl);
  static bool _notEmpty(String? s) => s != null && s.trim().isNotEmpty;
}

// ---------------------------------------------------------------------------
// Header — gradient hero with avatar, name, code, key chips & badges.
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.controller, required this.profile});

  final ProfileController controller;
  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final ProfileUser u = profile.user;
    final MemberDetails m = profile.member;
    final String? gender = controller.genderLabel(m.gender);
    final int? age = m.age;
    final String? onBehalf = controller.onBehalfLabel(m.onBehalfId);

    final List<String> chips = <String?>[
      gender,
      age != null ? '$age yrs' : null,
      onBehalf != null ? 'For: $onBehalf' : null,
    ].whereType<String>().toList();

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
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Avatar(url: u.photoUrl, initial: u.initial),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            u.displayName,
                            style: AppTextStyles.title.copyWith(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (m.isVerified) ...<Widget>[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                        ],
                        const Spacer(),
                        const _EditButton(),
                      ],
                    ),
                    if (u.code != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        'ID • ${u.code}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: chips.map((String t) => _GlassChip(text: t)).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              _StatusPill(
                icon: m.isVerified ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                label: m.isVerified
                    ? 'Verified'
                    : (m.verificationStatus ?? 'Unverified').capitalizeFirst!,
              ),
              const SizedBox(width: 8),
              _StatusPill(
                icon: u.approved ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
                label: u.approved ? 'Approved' : 'Pending',
              ),
              if (m.hideProfile) ...<Widget>[
                const SizedBox(width: 8),
                const _StatusPill(icon: Icons.visibility_off_rounded, label: 'Hidden'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.initial});
  final String? url;
  final String initial;

  @override
  Widget build(BuildContext context) {
    const double size = 72;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 2),
      ),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: (url != null)
              ? Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(),
                  loadingBuilder: (BuildContext ctx, Widget child, ImageChunkEvent? p) =>
                      p == null ? child : _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    color: Colors.white.withValues(alpha: 0.2),
    alignment: Alignment.center,
    child: Text(initial, style: AppTextStyles.display.copyWith(color: Colors.white, fontSize: 30)),
  );
}

class _EditButton extends StatelessWidget {
  const _EditButton();
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Get.to<void>(() => const EditProfileView()),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
    ),
  );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.badge.copyWith(color: Colors.white)),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Profile completion.
// ---------------------------------------------------------------------------

/// Profile-completion graph. Driven by [ProfileCompletionService]: every
/// registration section the user actually filled counts, sections skipped
/// during signup stay pending until they are completed from the hub — so the
/// percentage only ever moves when real data is added.
class _CompletionCard extends StatelessWidget {
  const _CompletionCard();

  @override
  Widget build(BuildContext context) {
    final ProfileCompletionService completion = Get.find<ProfileCompletionService>();

    return Obx(() {
      final int pct = completion.percent;
      final int pending = completion.pendingCount;

      return _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: completion.fraction,
                          strokeWidth: 5,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Profile completion', style: AppTextStyles.bodyStrong),
                      const SizedBox(height: 2),
                      Text(
                        pending == 0
                            ? 'Your profile is complete.'
                            : '$pending ${pending == 1 ? 'section' : 'sections'} left — '
                                  'complete them for better matches.',
                        style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (pending > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Get.toNamed<void>(AppRoutes.profileCompletion),
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 20),
                  label: const Text('Complete your profile'),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Intro media (video / voice) — availability indicators.
// ---------------------------------------------------------------------------

class _IntroMediaCard extends StatelessWidget {
  const _IntroMediaCard({required this.member});
  final MemberDetails member;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardTitle(icon: Icons.play_circle_outline_rounded, title: 'Introduction'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              if (member.videoIntroUrl != null)
                Expanded(
                  child: _MediaTile(icon: Icons.videocam_rounded, label: 'Video intro'),
                ),
              if (member.videoIntroUrl != null && member.voiceIntroUrl != null)
                const SizedBox(width: AppSpacing.sm),
              if (member.voiceIntroUrl != null)
                Expanded(
                  child: _MediaTile(icon: Icons.mic_rounded, label: 'Voice intro'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
    ),
    child: Column(
      children: <Widget>[
        Icon(icon, color: AppColors.primary, size: AppDimensions.iconLg),
        const SizedBox(height: 6),
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
        Text('Uploaded', style: AppTextStyles.badge.copyWith(color: AppColors.success)),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// About.
// ---------------------------------------------------------------------------

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.member});
  final MemberDetails member;

  @override
  Widget build(BuildContext context) {
    final String? about = _clean(member.aboutMe);
    final String? bio = _clean(member.aiGeneratedBio);
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardTitle(icon: Icons.person_outline_rounded, title: 'About me'),
          if (about != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(about, style: AppTextStyles.body),
          ],
          if (bio != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.goldLight.withValues(alpha: 0.4),
                borderRadius: AppRadius.smAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bio,
                      style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? _clean(String? s) => (s != null && s.trim().isNotEmpty) ? s.trim() : null;
}

// ---------------------------------------------------------------------------
// Details.
// ---------------------------------------------------------------------------

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.controller, required this.member});
  final ProfileController controller;
  final MemberDetails member;

  @override
  Widget build(BuildContext context) {
    final List<String> langs = controller.languageLabels(member.knownLanguages);
    final List<_Detail> rows = <_Detail>[
      _Detail(Icons.wc_rounded, 'Gender', controller.genderLabel(member.gender)),
      _Detail(Icons.cake_outlined, 'Date of birth', _fmtDate(member.dateOfBirth)),
      _Detail(
        Icons.favorite_border_rounded,
        'Marital status',
        controller.maritalLabel(member.maritalStatusId),
      ),
      _Detail(Icons.family_restroom_rounded, 'Children', member.children?.toString()),
      _Detail(Icons.groups_2_outlined, 'Profile for', controller.onBehalfLabel(member.onBehalfId)),
      _Detail(
        Icons.translate_rounded,
        'Mother tongue',
        controller.languageLabel(member.motherTongue),
      ),
      _Detail(Icons.language_rounded, 'Known languages', langs.isEmpty ? null : langs.join(', ')),
    ].where((_Detail d) => d.value != null && d.value!.trim().isNotEmpty).toList();

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardTitle(icon: Icons.badge_outlined, title: 'Personal details'),
          const SizedBox(height: AppSpacing.xs),
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            _DetailRow(detail: rows[i]),
            if (i != rows.length - 1)
              Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }

  static String? _fmtDate(DateTime? d) {
    if (d == null) return null;
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _Detail {
  const _Detail(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String? value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.detail});
  final _Detail detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: AppRadius.smAll,
          ),
          child: Icon(detail.icon, size: AppDimensions.iconSm, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            detail.label,
            style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(detail.value!, textAlign: TextAlign.end, style: AppTextStyles.bodyStrong),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Aspirations (travel & goals).
// ---------------------------------------------------------------------------

class _AspirationsCard extends StatelessWidget {
  const _AspirationsCard({required this.member});
  final MemberDetails member;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardTitle(icon: Icons.explore_outlined, title: 'Lifestyle & goals'),
          if (_ne(member.travelPreferences)) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _MiniBlock(
              icon: Icons.flight_takeoff_rounded,
              label: 'Travel preferences',
              value: member.travelPreferences!.trim(),
            ),
          ],
          if (_ne(member.futureGoals)) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _MiniBlock(
              icon: Icons.flag_rounded,
              label: 'Future goals',
              value: member.futureGoals!.trim(),
            ),
          ],
        ],
      ),
    );
  }

  static bool _ne(String? s) => s != null && s.trim().isNotEmpty;
}

class _MiniBlock extends StatelessWidget {
  const _MiniBlock({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Icon(icon, size: AppDimensions.iconSm, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(value, style: AppTextStyles.body),
    ],
  );
}

// ---------------------------------------------------------------------------
// Privacy.
// ---------------------------------------------------------------------------

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.privacy});
  final ProfilePrivacy privacy;

  @override
  Widget build(BuildContext context) {
    final List<_Priv> rows = <_Priv>[
      _Priv('Show photo', privacy.showPhoto),
      _Priv('Show gallery', privacy.showGallery),
      _Priv('Show contact', privacy.showContact),
      _Priv('Show email', privacy.showEmail),
      _Priv('Show phone', privacy.showPhone),
      _Priv('Show location', privacy.showLocation),
      _Priv('Profile-view notifications', privacy.allowProfileViewNotifications),
    ];
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardTitle(icon: Icons.lock_outline_rounded, title: 'Privacy & visibility'),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rows.map((_Priv p) => _PrivChip(priv: p)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Priv {
  const _Priv(this.label, this.on);
  final String label;
  final bool on;
}

class _PrivChip extends StatelessWidget {
  const _PrivChip({required this.priv});
  final _Priv priv;
  @override
  Widget build(BuildContext context) {
    final Color color = priv.on ? AppColors.success : Theme.of(context).hintColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(priv.on ? Icons.check_rounded : Icons.lock_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            priv.label,
            style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared building blocks.
// ---------------------------------------------------------------------------

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.primary.withValues(alpha: dark ? 0.18 : 0.10)),
        boxShadow: dark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -8,
                ),
              ],
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: AppDimensions.iconMd, color: AppColors.primary),
      const SizedBox(width: AppSpacing.xs),
      Text(title, style: AppTextStyles.subtitle),
    ],
  );
}

/// Prompt shown while identity verification has not passed.
///
/// Mirrors the web dashboard: registration is never blocked by the model, so an
/// unverified member needs a visible way to finish the check.
class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.verification});

  final ProfileVerification verification;

  @override
  Widget build(BuildContext context) {
    final AiVerificationModel ai = verification.ai;
    final (Color color, IconData icon, String title, String body) = _copy(context, ai);
    return InkWell(
      borderRadius: AppRadius.lgAll,
      onTap: () => Get.toNamed(AppRoutes.aiVerification),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: AppDimensions.iconLg),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppTextStyles.bodyStrong.copyWith(color: color)),
                  const SizedBox(height: 2),
                  Text(body, style: AppTextStyles.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  (Color, IconData, String, String) _copy(BuildContext context, AiVerificationModel ai) {
    if (ai.isPending) {
      return (
        AppColors.info,
        Icons.hourglass_top_rounded,
        'Verification in progress',
        'We are checking the documents you submitted. Tap for details.',
      );
    }
    if (ai.needsManualReview) {
      return (
        AppColors.warning,
        Icons.person_search_rounded,
        'Verification needs review',
        'Our team is reviewing your documents. Tap to see the status.',
      );
    }
    if (ai.isRejected) {
      return (
        AppColors.error,
        Icons.gpp_bad_rounded,
        'Verification did not pass',
        'Tap to see why and try again.',
      );
    }
    if (ai.hasFailed) {
      return (
        AppColors.warning,
        Icons.error_outline_rounded,
        'Verification incomplete',
        'We could not reach the verification service. Tap to retry.',
      );
    }
    return (
      AppColors.primary,
      Icons.verified_user_outlined,
      'Verify your identity',
      'Verified profiles are trusted more and get better responses.',
    );
  }
}

/// Entry points for the post-signup features that live on their own screens.
class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardTitle(icon: Icons.tune_rounded, title: 'Manage'),
          const SizedBox(height: AppSpacing.xs),
          _ActionTile(
            icon: Icons.favorite_border_rounded,
            title: 'Interests',
            subtitle: 'Proposals you sent and received',
            route: AppRoutes.expressInterests,
          ),
          _ActionTile(
            icon: Icons.filter_alt_outlined,
            title: 'Partner preferences',
            subtitle: 'Shapes which matches you see',
            route: AppRoutes.partnerPreferencesEdit,
          ),
          _ActionTile(
            icon: Icons.verified_user_outlined,
            title: 'Identity verification',
            subtitle: 'Status, history and re-check',
            route: AppRoutes.aiVerification,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.body),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor),
      onTap: () => Get.toNamed(route),
    );
  }
}
