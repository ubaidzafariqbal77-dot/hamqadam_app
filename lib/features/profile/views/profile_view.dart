import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/feature_access.dart';
import '../../../controllers/profile_controller.dart';
import '../../../controllers/verification_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/storage/profile_completion_service.dart';
import '../../../models/ai_verification_model.dart';
import '../../../models/profile_model.dart';
import '../../../models/verification_model.dart';
import '../../../widgets/state_widgets.dart';
import 'edit_profile_view.dart';

/// Premium, fully dynamic profile screen backed by [ProfileController]
/// (`GET /api/v1/profile`). Rendered as the "Profile" tab body inside the
/// authenticated home shell.
///
/// Everything the endpoint returns is shown. The typed blocks (`user`,
/// `member`, `photos`, `privacy`) have hand-built cards; the nine registration
/// groups (`religion_and_language`, `location`, `career`, …) are rendered
/// generically from [ProfileSection], with their raw foreign keys resolved to
/// names by the controller — so a field the backend adds later appears without
/// a UI change instead of staying invisible.
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

  /// Icon per registration group, so the generic section cards still read as
  /// designed screens rather than a dump of key/value pairs.
  static const Map<String, IconData> _sectionIcons = <String, IconData>{
    'religion_and_language': Icons.mosque_rounded,
    'caste': Icons.diversity_3_rounded,
    'location': Icons.place_rounded,
    'education': Icons.school_rounded,
    'career': Icons.work_outline_rounded,
    'physical': Icons.accessibility_new_rounded,
    'lifestyle_and_interests': Icons.interests_rounded,
    'family': Icons.family_restroom_rounded,
    'marriage_expectations': Icons.favorite_outline_rounded,
  };

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
          _HeroCard(controller: controller, profile: profile),
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
          if (profile.photos.hasGallery || profile.photos.coverPhotoUrl != null) ...<Widget>[
            _PhotosCard(photos: profile.photos),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_hasIntro(profile.member)) ...<Widget>[
            _IntroMediaCard(member: profile.member),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_notEmpty(profile.member.aboutMe) ||
              _notEmpty(profile.member.aiGeneratedBio)) ...<Widget>[
            _AboutCard(member: profile.member),
            const SizedBox(height: AppSpacing.md),
          ],
          _PersonalCard(controller: controller, profile: profile),
          const SizedBox(height: AppSpacing.md),
          _AccountCard(user: profile.user, member: profile.member),
          const SizedBox(height: AppSpacing.md),
          // The nine registration groups, in the order the model declares.
          for (final ({String key, String title, ProfileSection section}) s in profile.sections)
            if (s.section.values.isNotEmpty) ...<Widget>[
              _SectionCard(
                controller: controller,
                title: s.title,
                icon: _sectionIcons[s.key] ?? Icons.article_outlined,
                section: s.section,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          _VerificationCard(verification: profile.verification),
          const SizedBox(height: AppSpacing.md),
          const _QuickActionsCard(),
          const SizedBox(height: AppSpacing.md),
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
// Hero — gradient header with the avatar, approval badge, identity and stats.
// ---------------------------------------------------------------------------

/// Shown over the avatar once the account is approved by the HamQadam team.
const String _kApprovedBadge = 'assets/icons/verified_bagde.png';

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller, required this.profile});

  final ProfileController controller;
  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final ProfileUser u = profile.user;
    final MemberDetails m = profile.member;

    return Obx(() {
      // Subscribes to the lookup store so the chips below fill in as soon as
      // the gender / on-behalf lists land.
      controller.lookupRevision;

      final List<String> chips = <String?>[
        controller.genderLabel(m.gender),
        m.age != null ? '${m.age} years' : null,
        controller.maritalLabel(m.maritalStatusId),
        _city(controller, profile),
      ].whereType<String>().toList();

      return Container(
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
              blurRadius: 28,
              offset: const Offset(0, 14),
              spreadRadius: -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.xlAll,
          child: Stack(
            children: <Widget>[
              // Soft light bloom, so the flat gradient reads as depth.
              const Positioned(top: -50, right: -40, child: _Bloom(size: 170)),
              const Positioned(bottom: -70, left: -50, child: _Bloom(size: 150)),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (u.code != null)
                          _GlassChip(text: 'ID ${u.code}', icon: Icons.qr_code_2_rounded),
                        const Spacer(),
                        const _EditButton(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Avatar(
                      url: u.photoUrl,
                      initial: u.initial,
                      verified: profile.verification.identityVerified,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            u.displayName,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.display.copyWith(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.verification.identityVerified) ...<Widget>[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 21),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    _StatusPill(gate: VerificationGate.of(profile.verification)),
                    if (chips.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: chips.map((String t) => _GlassChip(text: t)).toList(),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _StatStrip(profile: profile),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// The city sits in the `location` group, not on `member`, so the hero reads
  /// it straight from the section.
  static String? _city(ProfileController c, ProfileModel p) {
    final dynamic city = p.location['city_id'];
    return c.displayValue('city_id', city);
  }
}

/// A blurred highlight used to give the hero gradient some depth.
class _Bloom extends StatelessWidget {
  const _Bloom({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: <Color>[Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.initial, required this.verified});

  final String? url;
  final String initial;

  /// Identity verified by a moderator. NOT `user.approved` — the API sets that
  /// to 1 the moment an account is created, so it says nothing about identity.
  final bool verified;

  static const double _size = 104;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size + 12,
      height: _size + 12,
      child: Stack(
        children: <Widget>[
          Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.25),
                border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2),
              ),
              child: ClipOval(
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child: url != null
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
            ),
          ),
          // The badge the account earns once HamQadam verifies the identity.
          if (verified)
            Positioned(
              right: 2,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: Image.asset(
                  _kApprovedBadge,
                  width: 28,
                  height: 28,
                  // A missing asset must never break the header.
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.verified_rounded, size: 28, color: AppColors.info),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback() => Container(
    color: Colors.white.withValues(alpha: 0.2),
    alignment: Alignment.center,
    child: Text(initial, style: AppTextStyles.display.copyWith(color: Colors.white, fontSize: 38)),
  );
}

/// Account status under the name.
///
/// This used to read "Approved account" whenever `user.approved` was true — but
/// the API sets `approved = 1` at registration (AuthService::register), so every
/// account claimed to be approved while its documents were still queued for
/// manual review. The pill now reports the identity-verification state itself,
/// which is the thing members actually care about.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.gate});

  final VerificationGate gate;

  @override
  Widget build(BuildContext context) {
    final bool verified = gate == VerificationGate.verified;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: verified ? Colors.white : Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: verified
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (verified)
            Image.asset(
              _kApprovedBadge,
              width: 14,
              height: 14,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.verified_rounded, size: 14, color: AppColors.info),
            )
          else
            Icon(_icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            gate.label,
            style: AppTextStyles.badge.copyWith(
              color: verified ? AppColors.primaryDark : Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon => switch (gate) {
    VerificationGate.verified => Icons.verified_rounded,
    VerificationGate.inManualReview => Icons.hourglass_top_rounded,
    VerificationGate.rejected => Icons.error_outline_rounded,
    VerificationGate.notSubmitted => Icons.shield_outlined,
  };
}

/// Completion / verification / photos, on one glass strip under the identity.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.profile});
  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final int pct = profile.member.profileCompletion > 0
        ? profile.member.profileCompletion
        : profile.registration.completionPercentage;
    // Reads the document workflow, so it agrees with the badge and the
    // verification card instead of reporting an AI pass as "Verified".
    final String verification = switch (VerificationGate.of(profile.verification)) {
      VerificationGate.verified => 'Verified',
      VerificationGate.inManualReview => 'In review',
      VerificationGate.rejected => 'Rejected',
      VerificationGate.notSubmitted => 'Not verified',
    };
    final int photos =
        profile.photos.galleryUrls.length + (profile.photos.profilePhotoUrl != null ? 1 : 0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _StatCell(value: '$pct%', label: 'Complete')),
          const _StatDivider(),
          Expanded(child: _StatCell(value: verification, label: 'Identity')),
          const _StatDivider(),
          Expanded(child: _StatCell(value: '$photos', label: 'Photos')),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyStrong.copyWith(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 1),
      Text(
        label.toUpperCase(),
        style: AppTextStyles.badge.copyWith(
          color: Colors.white.withValues(alpha: 0.82),
          letterSpacing: 0.7,
        ),
      ),
    ],
  );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.28));
}

class _EditButton extends StatelessWidget {
  const _EditButton();
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Get.to<void>(() => const EditProfileView()),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.edit_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            'Edit',
            style: AppTextStyles.badge.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.text, this.icon});
  final String text;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: icon == null ? 11 : 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
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
// Photos — cover banner + gallery strip.
// ---------------------------------------------------------------------------

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.photos});
  final ProfilePhotos photos;

  @override
  Widget build(BuildContext context) {
    final List<String> gallery = photos.galleryUrls;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardHeader(
            icon: Icons.photo_library_outlined,
            title: 'Photos',
            trailing: gallery.isEmpty ? null : '${gallery.length}',
          ),
          if (photos.coverPhotoUrl != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => _openPhoto(context, photos.coverPhotoUrl!),
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: AspectRatio(
                  aspectRatio: 16 / 8,
                  child: Image.network(
                    photos.coverPhotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _PhotoFallback(),
                  ),
                ),
              ),
            ),
          ],
          if (gallery.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: gallery.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
                itemBuilder: (BuildContext ctx, int i) => GestureDetector(
                  onTap: () => _openPhoto(ctx, gallery[i]),
                  child: ClipRRect(
                    borderRadius: AppRadius.mdAll,
                    child: Image.network(
                      gallery[i],
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _PhotoFallback(width: 96),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _openPhoto(BuildContext context, String url) {
    Get.dialog<void>(
      Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const _PhotoFallback(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({this.width});
  final double? width;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 96,
    color: AppColors.primary.withValues(alpha: 0.08),
    alignment: Alignment.center,
    child: Icon(
      Icons.image_not_supported_outlined,
      color: AppColors.primary.withValues(alpha: 0.5),
    ),
  );
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
          const _CardHeader(icon: Icons.play_circle_outline_rounded, title: 'Introduction'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              if (member.videoIntroUrl != null)
                const Expanded(
                  child: _MediaTile(icon: Icons.videocam_rounded, label: 'Video intro'),
                ),
              if (member.videoIntroUrl != null && member.voiceIntroUrl != null)
                const SizedBox(width: AppSpacing.sm),
              if (member.voiceIntroUrl != null)
                const Expanded(child: _MediaTile(icon: Icons.mic_rounded, label: 'Voice intro')),
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
          const _CardHeader(icon: Icons.person_outline_rounded, title: 'About me'),
          if (about != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(about, style: AppTextStyles.body.copyWith(height: 1.5)),
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
// Personal details (the typed `member` block).
// ---------------------------------------------------------------------------

class _PersonalCard extends StatelessWidget {
  const _PersonalCard({required this.controller, required this.profile});

  final ProfileController controller;
  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final MemberDetails m = profile.member;

    return Obx(() {
      controller.lookupRevision;
      final List<String> langs = controller.languageLabels(m.knownLanguages);

      final List<_Field> fields = <_Field>[
        _Field('Gender', controller.genderLabel(m.gender)),
        _Field('Date of birth', controller.displayValue('date_of_birth', m.dateOfBirth)),
        _Field('Age', m.age == null ? null : '${m.age} years'),
        _Field('Marital status', controller.maritalLabel(m.maritalStatusId)),
        _Field('Children', m.children?.toString()),
        _Field('Profile for', controller.onBehalfLabel(m.onBehalfId)),
        _Field('Mother tongue', controller.languageLabel(m.motherTongue)),
        _Field('Known languages', langs.isEmpty ? null : langs.join(', '), chips: langs),
        _Field('Travel preferences', _clean(m.travelPreferences)),
        _Field('Future goals', _clean(m.futureGoals)),
      ];

      return _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _CardHeader(icon: Icons.badge_outlined, title: 'Personal details'),
            const SizedBox(height: AppSpacing.sm),
            _FieldGrid(fields: fields),
            _MissingNote(labels: _Field.missingLabels(fields)),
          ],
        ),
      );
    });
  }

  static String? _clean(String? s) => (s != null && s.trim().isNotEmpty) ? s.trim() : null;
}

// ---------------------------------------------------------------------------
// Account & contact (the typed `user` block).
// ---------------------------------------------------------------------------

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.member});
  final ProfileUser user;
  final MemberDetails member;

  @override
  Widget build(BuildContext context) {
    final List<_Field> fields = <_Field>[
      _Field('Full name', user.displayName),
      _Field('Member ID', user.code),
      _Field('Email', user.email),
      _Field('Phone', user.phone),
      // "Active", not "Approved": `user.approved` is set to 1 the moment the
      // account is created, so it only means the account is usable. Identity
      // approval is a separate thing and lives on the verification card.
      _Field('Account status', user.blocked
          ? 'Blocked'
          : user.deactivated
              ? 'Deactivated'
              : user.approved
                  ? 'Active'
                  : 'Pending activation'),
      _Field('Profile visibility', member.hideProfile ? 'Hidden from search' : 'Visible'),
    ];

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardHeader(icon: Icons.contact_mail_outlined, title: 'Account & contact'),
          const SizedBox(height: AppSpacing.sm),
          _FieldGrid(fields: fields),
          _MissingNote(labels: _Field.missingLabels(fields)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic registration section (religion, location, career, family, …).
// ---------------------------------------------------------------------------

/// Renders one [ProfileSection] — whatever the backend put in it.
///
/// Values arrive as raw columns (`religion_id`, `employment_status`,
/// `annual_income`), so every entry goes through
/// [ProfileController.displayValue] for its label and text. Fields the server
/// returned empty are summarised at the bottom instead of being dropped
/// silently, which is what makes a half-filled section obvious.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.controller,
    required this.title,
    required this.icon,
    required this.section,
  });

  final ProfileController controller;
  final String title;
  final IconData icon;
  final ProfileSection section;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Rebuilds as lookup lists land, turning ids into names in place.
      controller.lookupRevision;

      final List<_Field> fields = <_Field>[];
      final List<String> missing = <String>[];

      section.values.forEach((String key, dynamic raw) {
        if (ProfileController.hiddenFields.contains(key)) return;
        final String label = ProfileController.fieldLabel(key);
        final List<String> parts = controller.displayList(key, raw);
        if (parts.isEmpty) {
          // Genuinely empty on the server — worth telling the member about.
          // A value we simply cannot label yet is not "missing", so it is left
          // out of both lists.
          if (_isBlank(raw)) missing.add(label);
          return;
        }
        fields.add(_Field(label, parts.join(', '), chips: parts.length > 1 ? parts : const <String>[]));
      });

      if (fields.isEmpty && missing.isEmpty) return const SizedBox.shrink();

      return _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CardHeader(
              icon: icon,
              title: title,
              trailing: fields.isEmpty ? null : '${fields.length}',
            ),
            if (fields.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _FieldGrid(fields: fields),
            ],
            _MissingNote(labels: missing),
          ],
        ),
      );
    });
  }

  static bool _isBlank(dynamic raw) {
    if (raw == null) return true;
    if (raw is String) return raw.trim().isEmpty;
    if (raw is Iterable) return raw.isEmpty;
    if (raw is Map) return raw.isEmpty;
    return false;
  }
}

// ---------------------------------------------------------------------------
// Identity verification summary.
// ---------------------------------------------------------------------------

/// Identity verification, broken out per check.
///
/// The card reports FOUR things separately, because they genuinely differ and
/// collapsing them is what produced the "approved account, still in manual
/// review" contradiction:
///
///  * CNIC / ID card — both sides uploaded?
///  * Selfie — uploaded?
///  * Liveness & face match — the server's own comparison verdict.
///  * AI pre-screen — advisory only; never sets the badge on its own.
///
/// …plus the overall status, which is whatever the human reviewer decided.
///
/// The per-document detail lives on `GET /verification/current`, so this reads
/// [VerificationController]. It falls back to the summary block embedded in
/// `GET /profile` while that request is still in flight.
class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.verification});
  final ProfileVerification verification;

  @override
  Widget build(BuildContext context) {
    final VerificationController c = Get.find<VerificationController>();

    return Obx(() {
      final VerificationModel record = c.current;

      // Before /verification/current lands, the profile's summary block is the
      // best picture we have.
      final VerificationGate gate = record.exists
          ? c.gate
          : VerificationGate.of(verification);

      final VerificationItemStatus overall = switch (gate) {
        VerificationGate.verified => VerificationItemStatus.passed,
        VerificationGate.rejected => VerificationItemStatus.failed,
        VerificationGate.inManualReview => VerificationItemStatus.inReview,
        VerificationGate.notSubmitted => VerificationItemStatus.missing,
      };

      final AiVerificationModel ai = verification.ai;
      final Color color = _colorFor(overall);

      return _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _CardHeader(icon: Icons.verified_user_outlined, title: 'Identity verification'),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                _StatusChip(status: overall, label: gate.label),
                const Spacer(),
                TextButton(
                  onPressed: () => Get.toNamed(AppRoutes.aiVerification),
                  child: const Text('Details'),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              record.exists ? record.headline : _fallbackHeadline(gate),
              style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: AppSpacing.sm),

            // The individual checks.
            if (record.exists)
              ...record.checklist.map(
                (({String label, VerificationItemStatus status}) item) =>
                    _CheckRow(label: item.label, status: item.status),
              )
            else
              const _CheckRow(
                label: 'CNIC / ID card, selfie and liveness',
                status: VerificationItemStatus.missing,
              ),

            // The AI pre-screen, labelled as advisory so nobody reads it as the
            // decision again.
            _CheckRow(
              label: 'AI pre-screen (advisory)',
              status: switch (ai.status) {
                'approved' => VerificationItemStatus.passed,
                'rejected' || 'failed' => VerificationItemStatus.failed,
                'not_started' => VerificationItemStatus.missing,
                _ => VerificationItemStatus.inReview,
              },
            ),

            if (record.faceMatchScore != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Face match confidence: ${record.faceMatchScore!.toStringAsFixed(1)}%',
                style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
              ),
            ],

            if (gate == VerificationGate.inManualReview) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'While your documents are in review you can browse, edit your '
                  'profile and reply to interests. Sending interests, messaging '
                  'and contact details unlock once a reviewer approves you.',
                  style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  static String _fallbackHeadline(VerificationGate gate) => switch (gate) {
    VerificationGate.verified => 'Your identity is verified.',
    VerificationGate.rejected => 'Verification was rejected. Please submit again.',
    VerificationGate.inManualReview =>
      'Your documents are in manual review. This usually takes 24–48 hours.',
    VerificationGate.notSubmitted =>
      'Verify your identity to unlock messaging and interests.',
  };

  static Color _colorFor(VerificationItemStatus s) => switch (s) {
    VerificationItemStatus.passed => AppColors.success,
    VerificationItemStatus.failed => AppColors.error,
    VerificationItemStatus.inReview => AppColors.warning,
    VerificationItemStatus.missing => AppColors.info,
  };
}

/// One line of the verification checklist.
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.status});

  final String label;
  final VerificationItemStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = _VerificationCard._colorFor(status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(_icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(
            status.label,
            style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  IconData get _icon => switch (status) {
    VerificationItemStatus.passed => Icons.check_circle_rounded,
    VerificationItemStatus.failed => Icons.cancel_rounded,
    VerificationItemStatus.inReview => Icons.hourglass_top_rounded,
    VerificationItemStatus.missing => Icons.radio_button_unchecked_rounded,
  };
}

/// Pill showing the overall verification verdict.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final VerificationItemStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = _VerificationCard._colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            status.isPassed
                ? Icons.check_circle_rounded
                : status.isFailed
                    ? Icons.cancel_rounded
                    : Icons.hourglass_bottom_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.badge.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
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
          const _CardHeader(icon: Icons.lock_outline_rounded, title: 'Privacy & visibility'),
          const SizedBox(height: AppSpacing.sm),
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
// Field grid — the aligned label/value layout every card shares.
// ---------------------------------------------------------------------------

class _Field {
  const _Field(this.label, this.value, {this.chips = const <String>[]});

  final String label;
  final String? value;

  /// Set when the value is a list, so it can render as chips.
  final List<String> chips;

  bool get isEmpty => value == null || value!.trim().isEmpty;

  /// A long value (or a chip row) gets the full card width; short ones pair up
  /// two per row, which is what keeps the columns aligned.
  bool get isWide => chips.length > 1 || (value != null && value!.length > 26);

  static List<String> missingLabels(List<_Field> fields) =>
      fields.where((_Field f) => f.isEmpty).map((_Field f) => f.label).toList(growable: false);
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.fields});
  final List<_Field> fields;

  static const double _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final List<_Field> shown = fields.where((_Field f) => !f.isEmpty).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double full = constraints.maxWidth;
        final double half = (full - _gap) / 2;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: shown
              .map(
                (_Field f) => SizedBox(
                  width: f.isWide ? full : half,
                  child: _FieldTile(field: f),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.field});
  final _Field field;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: dark ? 0.07 : 0.04),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.primary.withValues(alpha: dark ? 0.16 : 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            field.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.badge.copyWith(
              color: Theme.of(context).hintColor,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          if (field.chips.length > 1)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: field.chips.map((String c) => _ValueChip(text: c)).toList(),
            )
          else
            Text(
              field.value!,
              style: AppTextStyles.bodyStrong.copyWith(fontSize: 14, height: 1.35),
            ),
        ],
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
    ),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// The "what is still empty" line under a card.
///
/// This is the part that answers "what is missing from my profile?" — without
/// it an empty column is indistinguishable from a column that does not exist.
class _MissingNote extends StatelessWidget {
  const _MissingNote({required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, size: 14, color: Theme.of(context).hintColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Not added yet: ${labels.join(', ')}',
              style: AppTextStyles.caption.copyWith(
                color: Theme.of(context).hintColor,
                height: 1.35,
              ),
            ),
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

/// Card header: a tinted icon tile, the title, and an optional count on the
/// right. Shared by every card so the whole screen keeps one rhythm.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: AppRadius.smAll,
        ),
        child: Icon(icon, size: AppDimensions.iconSm, color: AppColors.primary),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(child: Text(title, style: AppTextStyles.subtitle.copyWith(fontSize: 16))),
      if (trailing != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            trailing!,
            style: AppTextStyles.badge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
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
          const _CardHeader(icon: Icons.tune_rounded, title: 'Manage'),
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
