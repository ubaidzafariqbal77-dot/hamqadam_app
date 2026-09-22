import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/registration_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/app_logger.dart';

/// Branded splash that bootstraps the session and routes to the correct entry
/// point: resume registration, home, or login.
///
/// Visual design follows the product reference: a soft pink radiant backdrop
/// with sparkles, and a single frosted-white rounded card in the centre
/// carrying the logo, the name, the tagline and a slim loading bar.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  late final Animation<double> _cardScale;
  late final Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _cardScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
    );
    _cardFade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

    _entrance.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final AuthController auth = Get.find<AuthController>();

    // Before the cosmetic delay, not after: a call that is already ringing must
    // not be made to wait behind a 1.4 s animation. `main()` checks too, but the
    // record is written by the FCM background isolate and can land a beat after
    // the main isolate has looked for it, so this is the catch-all.
    //
    // Routing on to Discover without this check is what used to strand the
    // member: `Get.offAllNamed` wipes the stack, so a ringing screen raised
    // during startup went with it and the tray rang on alone.
    if (await _routedToPendingCall()) return;

    // Small delay so the splash is perceivable and layout settles.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    // Once more, for a push that landed during the delay itself.
    if (await _routedToPendingCall()) return;

    final RegistrationController reg = Get.find<RegistrationController>();
    // Registration is now filled in locally and submitted in one go, so a
    // half-finished signup has no token yet — the local draft decides too.
    if (auth.hasToken || reg.buffer.hasDraftInProgress) {
      await reg.resume();
    } else {
      // Not signed in (and no draft): always the onboarding flow. The
      // previous "seen" flag made restarts jump straight to login, which hid
      // the welcome experience from anyone who had opened the app before but
      // never actually signed in — so the flag is gone and onboarding is the
      // fixed entry point until a token or draft exists.
      Get.offAllNamed(AppRoutes.onboarding);
    }
  }

  /// Sends the app to the ringing screen if a call is waiting. Returns true
  /// when it did, so the caller stops its own routing.
  Future<bool> _routedToPendingCall() async {
    final PendingCall? pending =
        await NotificationService.instance.peekPendingIncomingCall();
    if (pending == null || !mounted) return false;

    AppLogger.push(
      'splash handing over to the ringing screen for call ${pending.callId}',
    );
    Get.offAllNamed<dynamic>(
      AppRoutes.incomingCall,
      arguments: <String, dynamic>{
        'callId': pending.callId,
        'callerName': pending.callerName,
        'isVideoCall': pending.isVideo,
        // It replaced the splash, so there is nothing underneath it either.
        'launchedTheApp': true,
      },
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double cardWidth = size.width.clamp(0.0, 340.0) * 0.78;
    final double cardHeight = cardWidth * 1.42;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Soft pink radiant backdrop (light, airy, brand-tinted).
            const _Backdrop(),

            // Sparkle dust, clustered to the upper-right / lower-left like the
            // reference art. Purely decorative.
            const Positioned.fill(child: _Sparkles()),

            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _cardFade,
                  child: ScaleTransition(
                    scale: _cardScale,
                    child: _SplashCard(
                      width: cardWidth,
                      height: cardHeight,
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

/// The centred frosted-white card: logo, name, tagline, loading bar.
class _SplashCard extends StatelessWidget {
  const _SplashCard({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            // Barely-pink glass: brighter than the backdrop, hairline white rim.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.82),
                Colors.white.withValues(alpha: 0.62),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFB4487B).withValues(alpha: 0.18),
                blurRadius: 44,
                offset: const Offset(0, 22),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              const Spacer(flex: 5),
              // Logo mark.
              Image.asset(
                'assets/icons/logo.png',
                width: width * 0.34,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.favorite_rounded,
                  color: AppColors.primary,
                  size: width * 0.28,
                ),
              ),
              const Spacer(flex: 2),
              // Name.
              Text(
                AppStrings.appName,
                style: AppTextStyles.display.copyWith(
                  fontSize: (width * 0.1).clamp(26.0, 34.0),
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              // Tagline.
              Text(
                AppStrings.tagline,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const Spacer(flex: 5),
              // Slim loading bar.
              SizedBox(
                width: width * 0.55,
                height: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.lightDivider,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft pink radiant gradient with gentle bokeh blobs — the backdrop family of
/// the reference art, tuned to the HamQadam brand palette.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFBE0EB), // airy rose
            Color(0xFFF7C6D9), // mid rose
            Color(0xFFF3B0C8), // deeper rose
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            right: -90,
            child: _Bokeh(size: 340, opacity: 0.5),
          ),
          Positioned(
            bottom: -140,
            left: -110,
            child: _Bokeh(size: 400, opacity: 0.42),
          ),
          Positioned(
            top: 120,
            left: -70,
            child: _Bokeh(size: 220, opacity: 0.30),
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

/// Tiny glitter dots, hand-placed to echo the reference's sparkle clusters.
class _Sparkles extends StatelessWidget {
  const _Sparkles();

  static const List<({double dx, double dy, double size, double opacity})> _dots =
      <({double dx, double dy, double size, double opacity})>[
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
