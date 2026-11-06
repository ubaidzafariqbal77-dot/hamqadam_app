import 'dart:ui';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../core/routes/app_routes.dart';
import '../../../widgets/app_button.dart';
import '../widgets/entry_dialog.dart';

class _OnbPage {
  const _OnbPage({
    required this.image,
    required this.eyebrow,
    required this.title,
    required this.highlight,
    required this.subtitle,
    required this.badgeIcon,
    required this.badge,
    required this.features,
  });

  final String image;

  /// Small caps label above the title.
  final String eyebrow;
  final String title;

  /// Part of [title] drawn in the brand serif + ink colour.
  final String highlight;
  final String subtitle;

  /// Floating glass chip over the illustration.
  final IconData badgeIcon;
  final String badge;

  /// Three short feature chips under the copy.
  final List<({IconData icon, String label})> features;
}

/// Four-page onboarding shown before login (first launch only).
///
/// Pages 1–3 are swipeable; page 4 is the hand-off — tapping anywhere on it
/// opens the Create Account / Login dialog. Skip jumps straight there too.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _controller = PageController();
  double _page = 0;
  int _index = 0;

  static const List<_OnbPage> _pages = <_OnbPage>[
    _OnbPage(
      image: 'assets/images/onboarding/onb_match.jpg',
      eyebrow: 'DISCOVER',
      title: 'Find your perfect match',
      highlight: 'perfect match',
      subtitle:
          'Browse verified profiles that share your faith, values and goals.',
      badgeIcon: Icons.favorite_rounded,
      badge: 'Matched on values',
      features: <({IconData icon, String label})>[
        (icon: Icons.verified_rounded, label: 'Verified'),
        (icon: Icons.auto_awesome_rounded, label: 'AI matches'),
        (icon: Icons.mosque_rounded, label: 'Shared faith'),
      ],
    ),
    _OnbPage(
      image: 'assets/images/onboarding/onb_family.jpg',
      eyebrow: 'FAMILY FIRST',
      title: 'Rishta, the respectful way',
      highlight: 'respectful way',
      subtitle:
          'Bring your family along. Wali-friendly tools keep every step dignified and halal.',
      badgeIcon: Icons.family_restroom_rounded,
      badge: 'Wali-friendly',
      features: <({IconData icon, String label})>[
        (icon: Icons.shield_moon_rounded, label: 'Wali mode'),
        (icon: Icons.groups_rounded, label: 'Family'),
        (icon: Icons.chat_bubble_rounded, label: 'Halal chat'),
      ],
    ),
    _OnbPage(
      image: 'assets/images/onboarding/onb_trust.jpg',
      eyebrow: 'TRUST & SAFETY',
      title: 'Safe, private & verified',
      highlight: 'verified',
      subtitle:
          'ID-verified members, photo privacy and report tools keep you protected.',
      badgeIcon: Icons.verified_user_rounded,
      badge: 'ID verified members',
      features: <({IconData icon, String label})>[
        (icon: Icons.badge_rounded, label: 'ID check'),
        (icon: Icons.lock_rounded, label: 'Photo privacy'),
        (icon: Icons.flag_rounded, label: 'Report'),
      ],
    ),
  ];

  static const int _handoffIndex = 3;

  bool get _isHandoff => _index == _handoffIndex;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!mounted) return;
      setState(() => _page = _controller.page ?? _index.toDouble());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _handoffIndex) {
      // Get Started lands on the first-look preview ("Proposals for you");
      // the login/create-account dialog opens from there.
      //
      // The flag is deliberately NOT set here (nor on Skip): the member has
      // only seen marketing pages — the onboarding replays on the next launch
      // until they actually sign in or register. AuthController clears the
      // flag again on logout, keeping that promise symmetrical.
      Get.offAllNamed<dynamic>(AppRoutes.welcomePreview);
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finishTo(String route) async {
    if (!mounted) return;
    Get.offAllNamed(route);
  }

  /// The shared Create Account / Login hand-off dialog (reference screen 5).
  void _openEntryDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xFF5E2A44).withValues(alpha: 0.35),
      builder: (BuildContext dialogContext) {
        return Center(
          child: EntryDialog(
            onCreateAccount: () => _finishTo(AppRoutes.accountFor),
            onLogin: () => _finishTo(AppRoutes.login),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // The hand-off page answers taps anywhere on the screen (buttons and
        // the pager still get first claim, so swiping keeps working).
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _isHandoff ? _openEntryDialog : null,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const _Backdrop(),
              const Positioned.fill(child: _Sparkles()),
              SafeArea(
                child: Column(
                  children: <Widget>[
                    _TopBar(
                      showSkip: !_isHandoff,
                      onSkip: () => _finishTo(AppRoutes.login),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _pages.length + 1,
                        onPageChanged: (int i) => setState(() => _index = i),
                        itemBuilder: (BuildContext c, int i) =>
                            i < _pages.length
                            ? _PageContent(
                                page: _pages[i],
                                index: i,
                                pageOffset: _page - i,
                              )
                            : const _HandoffContent(),
                      ),
                    ),
                    _BottomControls(
                      index: _index,
                      count: _pages.length + 1,
                      isHandoff: _isHandoff,
                      onNext: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pages 1–3: framed illustration with a floating glass badge, then eyebrow,
/// two-tone title, subtitle and three feature chips. Swiping drives a
/// parallax shift, tilt-free scale and fade.
class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.page,
    required this.index,
    required this.pageOffset,
  });

  final _OnbPage page;
  final int index;

  /// `PageController.page - index`: 0 when centred, ±1 at the edges.
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    final double t = pageOffset.clamp(-1.0, 1.0);
    final double a = t.abs();
    final double scale = 1 - (a * 0.12);
    final double fade = 1 - (a * 0.6);

    return Column(
      children: <Widget>[
        // Full-bleed illustration: no card, no frame. Slightly zoomed to crop
        // the generator's pale edges, then faded into the backdrop at the
        // bottom so it melts into the page.
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              return Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (Rect r) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.transparent,
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: <double>[0, 0.06, 0.72, 1],
                          ).createShader(r),
                          child: ClipRect(
                            child: Transform.translate(
                              offset: Offset(t * c.maxWidth * 0.2, 0),
                              child: Transform.scale(
                                scale: 1.22,
                                child: Image.asset(
                                  page.image,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  alignment: const Alignment(0, -0.2),
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.primaryLight,
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      color: AppColors.primaryDark,
                                      size: c.maxHeight * 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Floating glass badge near the faded bottom edge.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: Center(
                          child: ZoomIn(
                            key: ValueKey<String>('badge-$index'),
                            duration: const Duration(milliseconds: 450),
                            delay: const Duration(milliseconds: 150),
                            child: _GlassBadge(
                              icon: page.badgeIcon,
                              label: page.badge,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 14),
              FadeInUp(
                key: ValueKey<int>(index),
                duration: const Duration(milliseconds: 520),
                from: 22,
                child: Column(
                  children: <Widget>[
                    Text(
                      page.eyebrow,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TwoToneTitle(title: page.title, highlight: page.highlight),
                    const SizedBox(height: 10),
                    Text(
                      page.subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: AppColors.lightTextSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final ({IconData icon, String label}) f
                            in page.features)
                          _FeatureChip(icon: f.icon, label: f.label),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ],
    );
  }
}

/// Title with one phrase in the brand serif + ink, the rest in dark sans.
class _TwoToneTitle extends StatelessWidget {
  const _TwoToneTitle({required this.title, required this.highlight});

  final String title;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = AppTextStyles.headline.copyWith(
      fontSize: 25,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: AppColors.roseTitleInk,
    );
    final TextStyle accent = AppTextStyles.displaySerif.copyWith(
      fontSize: 28,
      height: 1.15,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      color: AppColors.primaryInk,
    );
    final int i = title.indexOf(highlight);
    return Text.rich(
      i < 0
          ? TextSpan(text: title, style: base)
          : TextSpan(
              children: <InlineSpan>[
                TextSpan(text: title.substring(0, i), style: base),
                TextSpan(text: highlight, style: accent),
                TextSpan(
                  text: title.substring(i + highlight.length),
                  style: base,
                ),
              ],
            ),
      textAlign: TextAlign.center,
    );
  }
}

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primaryInk.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.primaryDark,
                      AppColors.primaryInk,
                    ],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFF7FA), Color(0xFFFBE3EC)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF8D3E0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.primaryDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 4: same glass card language, with a pulsing "tap anywhere" hint.
class _HandoffContent extends StatefulWidget {
  const _HandoffContent();

  @override
  State<_HandoffContent> createState() => _HandoffContentState();
}

class _HandoffContentState extends State<_HandoffContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.97,
      upperBound: 1.03,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Closing page: glowing logo disc + serif wordmark, the two-line promise
    // with the italic serif emphasis, and a borderless illustration with a
    // floating glass badge. Tapping anywhere still opens the entry dialog.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double imgH = (c.maxHeight * 0.42).clamp(180.0, 340.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 4),
              ZoomIn(
                duration: const Duration(milliseconds: 500),
                child: Container(
                  width: 78,
                  height: 78,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.30),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icons/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.primaryDark,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.appName,
                style: AppTextStyles.displaySerif.copyWith(
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                AppStrings.tagline.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.6,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 20),
              FadeInUp(
                duration: const Duration(milliseconds: 520),
                from: 18,
                child: Column(
                  children: <Widget>[
                    Text(
                      'The biggest decision of your life is not business or job.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headline.copyWith(
                        fontSize: 21,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.roseTitleInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "It's who you marry.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displaySerif.copyWith(
                        fontSize: 32,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryInk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 22,
                            height: 1.4,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Choose with purpose',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 14,
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                          Text(
                            '  ·  ',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Choose Forever',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryInk,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 22,
                            height: 1.4,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Borderless illustration, gently breathing, with a glass badge.
              ScaleTransition(
                scale: _pulse,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    // Full-bleed (edge to edge past the page padding),
                    // edges cropped and faded into the backdrop.
                    SizedBox(
                      height: imgH,
                      width: double.infinity,
                      child: OverflowBox(
                        maxWidth: c.maxWidth,
                        minWidth: c.maxWidth,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (Rect r) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.transparent,
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: <double>[0, 0.08, 0.75, 1],
                          ).createShader(r),
                          child: ClipRect(
                            child: Transform.scale(
                              scale: 1.18,
                              child: Image.asset(
                                'assets/images/onboarding/onb_forever.jpg',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: imgH,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.primaryLight,
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    color: AppColors.primaryDark,
                                    size: 64,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 2,
                      child: Center(
                        child: _GlassBadge(
                          icon: Icons.favorite_rounded,
                          label: 'Your forever starts here',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: FadeInDown(
        duration: const Duration(milliseconds: 500),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // The reference's soft-pink circle mark with the white heart.
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFE1EA),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.primaryDark,
                size: 18,
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: showSkip ? 1 : 0,
              child: IgnorePointer(
                ignoring: !showSkip,
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.65),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Skip',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.primaryInk,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.index,
    required this.count,
    required this.isHandoff,
    required this.onNext,
  });

  final int index;
  final int count;
  final bool isHandoff;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        child: isHandoff
            ? AppButton(
                key: const ValueKey<String>('get-started'),
                label: 'Get Started',
                icon: Icons.arrow_forward_rounded,
                onPressed: onNext,
              )
            : Row(
                key: const ValueKey<String>('next-row'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _Dots(index: index, count: count),
                  _NextFab(onTap: onNext, progress: (index + 1) / count),
                ],
              ),
      ),
    );
  }
}

class _NextFab extends StatelessWidget {
  const _NextFab({required this.onTap, required this.progress});

  final VoidCallback onTap;

  /// 0..1 — drawn as a ring around the button.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (_, double v, __) => SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.primaryLight,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryDark,
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: <Color>[
                      AppColors.primaryDark,
                      AppColors.primaryInk,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primaryInk.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(count, (int i) {
        final bool active = i == index;
        // Active page stretches into a gradient pill; the rest stay dots.
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(right: 7),
          height: 9,
          width: active ? 30 : 9,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: <Color>[
                      AppColors.primaryDark,
                      AppColors.primaryInk,
                    ],
                  )
                : null,
            color: active
                ? null
                : (i < index ? AppColors.primary : AppColors.primaryLight),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

/// White backdrop with faint neutral bokeh — the app-wide white + hot-pink
/// combination. The old rose gradient read as the previous theme.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFDEBF2), Colors.white, Color(0xFFFFF7FA)],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            right: -90,
            child: _Bokeh(size: 340, opacity: 0.35),
          ),
          Positioned(
            bottom: -140,
            left: -110,
            child: _Bokeh(size: 400, opacity: 0.30),
          ),
        ],
      ),
    );
  }
}

class _Bokeh extends StatelessWidget {
  const _Bokeh({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny glitter dots echoing the splash's sparkle clusters.
class _Sparkles extends StatelessWidget {
  const _Sparkles();

  static const List<({double dx, double dy, double size, double opacity})>
  _dots = <({double dx, double dy, double size, double opacity})>[
    // Upper-right cluster.
    (dx: 0.86, dy: 0.10, size: 5, opacity: 0.9),
    (dx: 0.92, dy: 0.16, size: 3, opacity: 0.7),
    (dx: 0.80, dy: 0.20, size: 2.5, opacity: 0.6),
    (dx: 0.95, dy: 0.26, size: 2, opacity: 0.5),
    (dx: 0.74, dy: 0.08, size: 2, opacity: 0.55),
    // Lower-left cluster.
    (dx: 0.10, dy: 0.86, size: 4, opacity: 0.8),
    (dx: 0.16, dy: 0.92, size: 2.5, opacity: 0.6),
    (dx: 0.06, dy: 0.78, size: 2, opacity: 0.5),
    (dx: 0.22, dy: 0.96, size: 2, opacity: 0.45),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Stack(
            children: <Widget>[
              for (final (:dx, :dy, :size, :opacity) in _dots)
                Positioned(
                  left: constraints.maxWidth * dx,
                  top: constraints.maxHeight * dy,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: opacity),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.white.withValues(alpha: opacity * 0.9),
                          blurRadius: size * 2.5,
                          spreadRadius: size * 0.8,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
