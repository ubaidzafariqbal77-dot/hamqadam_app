import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/storage_keys.dart';
import '../../../core/routes/app_routes.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/bilingual_text.dart';

class _OnbPage {
  const _OnbPage({
    required this.lottie,
    required this.title,
    required this.subtitle,
    required this.glow,
  });

  final String lottie;
  final String title;
  final String subtitle;
  final Color glow;
}

/// Three-page swipeable onboarding shown before login (first launch only).
/// Skip or Get Started routes to the login screen and marks onboarding as seen.
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
      lottie: 'assets/lottie/onboard1.json',
      title: 'Find Your Perfect Match',
      subtitle: 'Meet Couples on Our App',
      glow: AppColors.primary,
    ),
    _OnbPage(
      lottie: 'assets/lottie/onboard2.json',
      title: 'Revitalize Your Marriage',
      subtitle: 'Marriage Made Easy',
      glow: AppColors.gold,
    ),
    _OnbPage(
      lottie: 'assets/lottie/onboard3.json',
      title: 'Forever and always, together as one',
      subtitle: 'We may not have it all together, but together we have it all',
      glow: AppColors.primaryDark,
    ),
  ];

  bool get _isLast => _index == _pages.length - 1;

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

  Future<void> _finish() async {
    final SharedPreferences prefs = Get.find<SharedPreferences>();
    await prefs.setBool(StorageKeys.onboardingSeen, true);
    Get.offAllNamed(AppRoutes.login);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Stack(
          children: <Widget>[
            Positioned.fill(child: _Backdrop(glow: _pages[_index].glow)),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _TopBar(showSkip: !_isLast, onSkip: _finish),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      onPageChanged: (int i) => setState(() => _index = i),
                      itemBuilder: (BuildContext c, int i) => _PageContent(
                        page: _pages[i],
                        index: i,
                        pageOffset: _page - i,
                      ),
                    ),
                  ),
                  _BottomControls(
                    index: _index,
                    count: _pages.length,
                    isLast: _isLast,
                    onNext: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft, colour-shifting glow blobs anchored behind the content. Purely
/// decorative — gives the white canvas depth without boxing anything in.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.glow});

  final Color glow;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            top: -90,
            right: -70,
            child: _Blob(color: glow, size: 260, opacity: 0.16),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            bottom: 40,
            left: -90,
            child: _Blob(color: AppColors.gold, size: 220, opacity: 0.12),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color.withValues(alpha: opacity), color.withValues(alpha: 0)],
        ),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: FadeInDown(
        duration: const Duration(milliseconds: 500),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: AppColors.brandGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Color(0x40D6185E), blurRadius: 14, offset: Offset(0, 5)),
                ],
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: showSkip ? 1 : 0,
              child: IgnorePointer(
                ignoring: !showSkip,
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.lightSurfaceAlt,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                  ),
                  child: BiText.inline(
                    'Skip',
                    style: AppTextStyles.bodyStrong.copyWith(color: AppColors.lightTextSecondary),
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

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page, required this.index, required this.pageOffset});

  final _OnbPage page;
  final int index;

  /// `PageController.page - index`: 0 when this page is centred, ±1 when a
  /// neighbour is fully in view. Drives a subtle scale/fade as pages swipe by.
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    final double t = pageOffset.abs().clamp(0.0, 1.0);
    final double scale = 1 - (t * 0.12);
    final double fade = 1 - (t * 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: fade,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              page.glow.withValues(alpha: 0.14),
                              page.glow.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                      Lottie.asset(page.lottie, fit: BoxFit.contain, repeat: true, width: 260, height: 260),
                    ],
                  ),
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
                BiText(
                  page.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headline.copyWith(color: AppColors.lightTextPrimary),
                ),
                const SizedBox(height: AppSpacing.md),
                BiText(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.lightTextSecondary),
                  urduColor: AppColors.lightTextSecondary,
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

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.index,
    required this.count,
    required this.isLast,
    required this.onNext,
  });

  final int index;
  final int count;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        child: isLast
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
              BoxShadow(color: Color(0x40D6185E), blurRadius: 18, offset: Offset(0, 8), spreadRadius: -2),
            ],
          ),
          child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
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
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(right: 6),
          height: 9,
          width: active ? 28 : 9,
          decoration: BoxDecoration(
            gradient: active ? const LinearGradient(colors: AppColors.brandGradient) : null,
            color: active ? null : AppColors.lightDivider,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? const <BoxShadow>[
                    BoxShadow(color: Color(0x33D6185E), blurRadius: 6, offset: Offset(0, 2)),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
