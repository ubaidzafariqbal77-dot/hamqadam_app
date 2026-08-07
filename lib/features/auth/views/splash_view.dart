import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/storage_keys.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/registration_controller.dart';
import '../../../core/routes/app_routes.dart';

/// Branded splash that bootstraps the session and routes to the correct entry
/// point: resume registration, home, or login.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _contentController;
  late final AnimationController _bgController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _ringScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _ringScale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    _textFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic));

    _logoController.forward();
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _contentController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final AuthController auth = Get.find<AuthController>();
    // Small delay so the splash is perceivable and layout settles.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    if (auth.hasToken) {
      // Server status is the source of truth for where to resume.
      await Get.find<RegistrationController>().resume();
    } else {
      // First launch → onboarding; afterwards go straight to login.
      final SharedPreferences prefs = Get.find<SharedPreferences>();
      final bool seenOnboarding = prefs.getBool(StorageKeys.onboardingSeen) ?? false;
      Get.offAllNamed(seenOnboarding ? AppRoutes.login : AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Animated brand gradient background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.brandGradient,
                    begin: Alignment(-1 + _bgController.value * 0.4, -1),
                    end: Alignment(1, 1 - _bgController.value * 0.4),
                  ),
                ),
              );
            },
          ),

          // Decorative soft glow blobs for depth
          Positioned(
            top: -size.width * 0.25,
            right: -size.width * 0.2,
            child: _GlowBlob(size: size.width * 0.7, opacity: 0.18),
          ),
          Positioned(
            bottom: -size.width * 0.3,
            left: -size.width * 0.25,
            child: _GlowBlob(size: size.width * 0.8, opacity: 0.14),
          ),

          // Subtle grain / vignette overlay for a premium finish
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: <Color>[Colors.transparent, Color(0x33000000)],
                radius: 1.2,
                center: Alignment.center,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Animated logo with glass ring + glow
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoFade.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 148,
                      height: 148,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          // Pulsing outer ring
                          AnimatedBuilder(
                            animation: _ringScale,
                            builder: (context, _) {
                              return Transform.scale(
                                scale: _ringScale.value,
                                child: Container(
                                  width: 148,
                                  height: 148,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Frosted glass circle
                          ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                width: 116,
                                height: 116,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: <Color>[
                                      Colors.white.withValues(alpha: 0.28),
                                      Colors.white.withValues(alpha: 0.08),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 30,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // App logo asset
                          Padding(
                            padding: const EdgeInsets.all(28.0),
                            child: Image.asset(
                              'assets/icons/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 56,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Animated title + tagline
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: <Widget>[
                          ShaderMask(
                            shaderCallback: (Rect bounds) => const LinearGradient(
                              colors: <Color>[Colors.white, Color(0xFFF1F1FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              AppStrings.appName,
                              style: AppTextStyles.display.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    offset: const Offset(0, 2),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppStrings.tagline,
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Slim, elegant loading indicator
                  FadeTransition(
                    opacity: _textFade,
                    child: SizedBox(
                      height: 3,
                      width: 64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft radial glow used as a background decoration for depth.
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.opacity});

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
              Colors.white.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}