import 'package:flutter/widgets.dart';

/// Spacing scale. Use these instead of magic numbers.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  static const EdgeInsets card = EdgeInsets.all(16);
}

/// Corner radius scale.
class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
}

/// Misc layout dimensions.
class AppDimensions {
  const AppDimensions._();

  static const double buttonHeight = 54;
  static const double fieldMinHeight = 56;
  static const double minTouchTarget = 48;
  static const double maxContentWidth = 520;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
}
