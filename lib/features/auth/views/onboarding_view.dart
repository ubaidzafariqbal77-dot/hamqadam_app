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
    required this.title,
    required this.subtitle,
  });

  final String image;
  final String title;
  final String subtitle;
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
      image: 'assets/images/onboard1.png',
      title: 'Find Your Perfect Match',
      subtitle: 'Meet couples who share your values on HamQadam',
    ),
    _OnbPage(
      image: 'assets/images/onboard2.png',
      title: 'Revitalize Your Marriage',
      subtitle: 'A respectful, wali-friendly path — marriage made easy',
    ),
    _OnbPage(
      image: 'assets/images/onboard3.png',
      title: 'Forever and always, together as one',
      subtitle:
          'We may not have it all together, but together we have it all',
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
                        itemBuilder: (BuildContext c, int i) => i < _pages.length
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

/// Pages 1–3: illustration inside a soft glow, title and subtitle below.
class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.page,
    required this.index,
    required this.pageOffset,
  });

  final _OnbPage page;
  final int index;

  /// `PageController.page - index`: 0 when this page is centred, ±1 when a
  /// neighbour is fully in view. Drives a subtle scale/fade as pages swipe by.
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    final double t = pageOffset.abs().clamp(0.0, 1.0);
    final double scale = 1 - (t * 0.10);
    final double fade = 1 - (t * 0.55);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: fade,
                // Height tracks the available space (capped) so small phones
                // never overflow while large ones still show it generously.
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final double h = c.maxHeight.clamp(120.0, 380.0);
                    return Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Container(
                            width: h * 0.95,
                            height: h * 0.95,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: <Color>[
                                  Color(0x40D63F73),
                                  Color(0x00D63F73),
                                ],
                              ),
                            ),
                          ),
                          // Page-specific product illustration.
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              page.image,
                              fit: BoxFit.contain,
                              height: h,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.favorite_rounded,
                                color: AppColors.primary,
                                size: h * 0.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          FadeInUp(
            key: ValueKey<int>(index),
            duration: const Duration(milliseconds: 520),
            from: 22,
            child: Column(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    gradient: const LinearGradient(colors: AppColors.brandGradient),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headline.copyWith(
                    fontSize: 22,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.lightTextSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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
    // The reference's closing page: brand logo + wordmark, the serif
    // "It's who you marry." headline with the pink emphasis line, a rounded
    // hero photo, then the full-width Continue pill. (Tapping anywhere still
    // opens the entry dialog — the parent GestureDetector keeps working.)
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          // Brand logo + wordmark + tagline.
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/icons/logo.png',
              width: 74,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFE0175B),
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.appName,
            style: AppTextStyles.headline.copyWith(
              fontSize: 24,
              color: const Color(0xFFC2185B),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            AppStrings.tagline,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              letterSpacing: 1.6,
              color: const Color(0xFFC2185B).withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 20),
          // Headline: ink lines, then the serif pink emphasis.
          Text(
            'The biggest decision of your life is not business or job.',
            textAlign: TextAlign.center,
            style: AppTextStyles.headline.copyWith(
              fontSize: 24,
              height: 1.25,
              color: const Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "It's who you marry.",
            textAlign: TextAlign.center,
            style: AppTextStyles.displaySerif.copyWith(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFC2185B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose with purpose.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 15,
              color: const Color(0xFF2D3748),
            ),
          ),
          Text(
            'Choose Forever.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFC2185B),
            ),
          ),
          const SizedBox(height: 16),
          // Rounded hero photo.
          ScaleTransition(
            scale: _pulse,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/onboard3.png',
                fit: BoxFit.cover,
                height: 240,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  height: 240,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0F4),
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFE0175B),
                    size: 72,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Single CTA: the bottom bar's Get Started pill is THE one button on
          // the hand-off page. The old in-page Continue pill duplicated it and
          // the two stacked screens showed two identical-looking buttons.
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
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
                color: Color(0xFFE0175B),
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
                      color: const Color(0xFFE0175B),
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
                  _NextFab(onTap: onNext),
                ],
              ),
      ),
    );
  }
}

class _NextFab extends StatelessWidget {
  const _NextFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: AppColors.brandGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x40D63F73),
                blurRadius: 18,
                offset: Offset(0, 8),
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
        // The reference's pager: solid hot-pink active dot, soft pink idle
        // dots — all circles, no pill stretch.
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(right: 6),
          height: 9,
          width: 9,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFE0175B)
                : const Color(0xFFFFD3E1),
            shape: BoxShape.circle,
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
          colors: <Color>[
            Colors.white,
            Color(0xFFFAFAFA),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(top: -120, right: -90, child: _Bokeh(size: 340, opacity: 0.35)),
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
