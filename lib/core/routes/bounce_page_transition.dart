import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Bottom-to-top "slide up + bounce" page transition for HamQadam.
///
/// The whole incoming screen slides up from the bottom edge and eases into
/// place with a subtle overshoot (a premium bounce), driven by
/// [SlideTransition] + [CurvedAnimation] with [Curves.easeOutBack].
///
/// Two entry points share the exact same motion:
///  • [BounceUpPageTransition] — a GetX [CustomTransition] wired into every
///    `GetPage` (see `AppPages`), so all named routes bounce up automatically.
///  • [BounceRoute.to] — a reusable [PageRouteBuilder] for plain [Navigator]
///    usage (`Navigator.of(context).push(BounceRoute.to(const TargetScreen()))`).
class BounceMotion {
  const BounceMotion._();

  /// How long the slide-up + bounce takes.
  static const Duration duration = Duration(milliseconds: 480);

  /// Reverse (pop) is a touch quicker for a snappy feel.
  static const Duration reverseDuration = Duration(milliseconds: 320);

  /// Curve that produces the gentle overshoot/bounce.
  /// Swap for [Curves.bounceOut] if you want a stronger, springier bounce.
  static const Curve curve = Curves.easeOutBack;

  /// Curve used while popping (plain ease-in, no overshoot on the way out).
  static const Curve reverseCurve = Curves.easeInCubic;

  static final Tween<Offset> _offsetTween = Tween<Offset>(
    begin: const Offset(0, 1), // fully below the screen
    end: Offset.zero, // resting position
  );

  /// Builds the shared slide-up transition around [child].
  static Widget build(Animation<double> animation, Widget child) {
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: curve,
      reverseCurve: reverseCurve,
    );
    return SlideTransition(
      position: _offsetTween.animate(curved),
      child: child,
    );
  }
}

/// GetX custom transition — attach to a `GetPage` via `customTransition:` so
/// the route slides up and bounces into place.
///
/// (Not `const`: GetX's [CustomTransition] has no const constructor, so a
/// single shared instance is created in `AppPages` instead.)
class BounceUpPageTransition extends CustomTransition {
  BounceUpPageTransition();

  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return BounceMotion.build(animation, child);
  }
}

/// Reusable [PageRouteBuilder] for plain [Navigator] navigation.
///
/// Example:
/// ```dart
/// Navigator.of(context).push(BounceRoute.to(const TargetScreen()));
/// ```
class BounceRoute {
  const BounceRoute._();

  /// Returns a route that slides [page] up from the bottom with a bounce.
  static Route<T> to<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: BounceMotion.duration,
      reverseTransitionDuration: BounceMotion.reverseDuration,
      pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) =>
          page,
      transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) =>
          BounceMotion.build(animation, child),
    );
  }
}
