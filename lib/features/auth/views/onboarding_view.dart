import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/storage_keys.dart';
import '../../../core/routes/app_routes.dart';

class _OnbPage {
  const _OnbPage({required this.lottie, required this.title, required this.subtitle});
  final String lottie;
  final String title;
  final String subtitle;
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
  int _index = 0;

  static const List<_OnbPage> _pages = <_OnbPage>[
    _OnbPage(
      lottie: 'assets/lottie/onboard1.json',
      title: 'Find Your Perfect Match',
      subtitle: 'Meet Couples on Our App',
    ),
    _OnbPage(
      lottie: 'assets/lottie/onboard2.json',
      title: 'Revitalize Your Marriage',
      subtitle: 'Marriage Made Easy',
    ),
    _OnbPage(
      lottie: 'assets/lottie/onboard3.json',
      title: 'Forever and always, together as one',
      subtitle: 'We may not have it all together, but together we have it all',
    ),
  ];

  bool get _isLast => _index == _pages.length - 1;

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
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (int i) => setState(() => _index = i),
                itemBuilder: (BuildContext c, int i) => _PageContent(page: _pages[i]),
              ),
            ),
            _BottomControls(
              index: _index,
              count: _pages.length,
              isLast: _isLast,
              onSkip: _finish,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page});
  final _OnbPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.display.copyWith(color: AppColors.primary, fontSize: 27),
          ),
          Expanded(
            child: Center(
              child: Lottie.asset(page.lottie, fit: BoxFit.contain, repeat: true),
            ),
          ),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(color: AppColors.primary),
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
    required this.onSkip,
    required this.onNext,
  });

  final int index;
  final int count;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: isLast
          ? SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: onNext,
                child: Text(
                  'Get Started',
                  style: AppTextStyles.button.copyWith(color: Colors.white, fontSize: 16),
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary, fontSize: 16),
                  ),
                ),
                _Dots(index: index, count: count),
                TextButton(
                  onPressed: onNext,
                  child: Text(
                    'Next',
                    style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary, fontSize: 16),
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
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 9,
          width: active ? 24 : 9,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
