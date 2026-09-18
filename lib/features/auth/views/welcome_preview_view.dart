import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../widgets/entry_dialog.dart';

/// First-look marketing screen shown right after onboarding (reference:
/// "Proposals for you"). It previews what members see after signing in —
/// handpicked matches, live totals — with every interactive element opening
/// the shared Create Account / Login dialog.
///
/// The WhatsApp banner at the bottom dials the owner directly: talking to a
/// human is often what convinces a hesitant visitor to sign up.
class WelcomePreviewView extends StatelessWidget {
  const WelcomePreviewView({super.key});

  /// Owner support line shown on the banner. `wa.me` links work on both
  /// platforms without any extra setup.
  static const String _whatsappNumber = '923001234567';

  static const List<_PreviewProfile> _profiles = <_PreviewProfile>[
    _PreviewProfile(
      name: 'Eleanor Rowe',
      meta: 'Age 27 · San Francisco · Product Designer',
      about:
          'Creative strategist passionate about design systems and user-centered solutions.',
      match: '95% MATCH',
    ),
    _PreviewProfile(
      name: 'Marcus Chen',
      meta: 'Age 30 · New York · Software Engineer',
      about: 'Builder at heart, loves scalable systems and clean code.',
      match: '92% MATCH',
    ),
    _PreviewProfile(
      name: 'Isabella Martinez',
      meta: 'Age 26 · Austin · UX Researcher',
      about: 'Empathy-driven, exploring behavioral patterns and user insights.',
      match: '90% MATCH',
    ),
  ];

  Future<void> _openWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/$_whatsappNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _openEntryDialog(BuildContext context) => EntryDialog.show(context);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // The reference's soft pink canvas; content scrolls so the WhatsApp
        // banner is always reachable on small phones.
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFFF9D3E0), // soft rose
                Color(0xFFF6C3D4), // mid rose
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // ---- Brand row (tappable too) -------------------
                        GestureDetector(
                          onTap: () => _openEntryDialog(context),
                          child: Row(
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  'assets/icons/logo.png',
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.favorite_rounded,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'HamQadam',
                                style: AppTextStyles.title.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // ---- Headline -----------------------------------
                        Text(
                          'Proposals for you',
                          style: AppTextStyles.display.copyWith(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: AppColors.lightTextPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Handpicked matches aligned with your preferences',
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ---- Search preview (tappable) ------------------
                        GestureDetector(
                          onTap: () => _openEntryDialog(context),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.search_rounded,
                                  color: AppColors.lightTextSecondary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Search by location, profession...',
                                    style: AppTextStyles.bodyStrong.copyWith(
                                      color: AppColors.lightTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ---- Match preview cards ------------------------
                        ..._profiles.map(
                          (_PreviewProfile p) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _PreviewCard(
                              profile: p,
                              onTap: () => _openEntryDialog(context),
                            ),
                          ),
                        ),

                        // ---- Bottom action row --------------------------
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openEntryDialog(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryDark,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Log in',
                                  style: AppTextStyles.button.copyWith(
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _openEntryDialog(context),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: AppColors.primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Create Account',
                                  style: AppTextStyles.button.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),

                // ---- WhatsApp banner (always visible) -----------------
                _WhatsAppBanner(onTap: _openWhatsApp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One preview profile card — a taste of the real feed behind login.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.profile, required this.onTap});

  final _PreviewProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFB4487B).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.lightSurfaceAlt,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        profile.name,
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.meta,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    profile.match,
                    style: AppTextStyles.badge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              profile.about,
              style: AppTextStyles.caption.copyWith(
                height: 1.45,
                color: AppColors.lightInputText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewProfile {
  const _PreviewProfile({
    required this.name,
    required this.meta,
    required this.about,
    required this.match,
  });

  final String name;
  final String meta;
  final String about;
  final String match;
}

/// Green WhatsApp strip pinned above the bottom safe area, matching the
/// reference. Tap opens the owner's chat.
class _WhatsAppBanner extends StatelessWidget {
  const _WhatsAppBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Material(
        color: const Color(0xFF25D366),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.chat_rounded, color: Colors.white, size: 26),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Need help? Talk to owner directly',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '+92 300 1234567',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Chat on WhatsApp',
                    style: AppTextStyles.badge.copyWith(
                      color: const Color(0xFF25D366),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
