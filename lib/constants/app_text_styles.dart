import 'package:flutter/material.dart';

/// Typography scale for the app.
///
/// Only TWO families are used (declared in pubspec, loaded globally via
/// [AppTheme]):
///   • [bodyFont] / [headingFont] = Plus Jakarta Sans → all Latin/English text.
///   • [urduFont] = NotoNastaliqUrdu → Urdu text shown beside/under English.
///
/// Hierarchy: Titles = ExtraBold (800) 28–32px · Body = Regular/Medium
/// (400–500) 16px · Buttons = Bold (700) 16–18px · Tags/Badges = SemiBold (600)
/// 12px.
///
/// Colours are intentionally omitted so the active [TextTheme] supplies
/// theme-aware colours; call `.copyWith` where a specific colour is required.
class AppTextStyles {
  const AppTextStyles._();

  /// Plus Jakarta Sans — clean, modern, premium; the global default everywhere.
  static const String bodyFont = 'PlusJakartaSans';

  /// Headings use Plus Jakarta Sans too (single English family across the app).
  static const String headingFont = bodyFont;

  /// Noto Nastaliq Urdu — for the Urdu line rendered under English text.
  static const String urduFont = 'NotoNastaliqUrdu';

  /// Global default family applied in ThemeData (never the platform default).
  static const String fontFamily = bodyFont;

  /// Builds the Urdu companion style for a given English [base] style.
  ///
  /// Nastaliq glyphs are tall and need generous line-height; the Urdu line is
  /// rendered slightly smaller than its English counterpart and (optionally)
  /// tinted to read as a secondary line.
  static TextStyle urdu(TextStyle base, {Color? color}) {
    final double size = (base.fontSize ?? 15) * 0.86;
    return base.copyWith(
      fontFamily: urduFont,
      fontSize: size < 12 ? 12 : size,
      fontWeight: FontWeight.w500,
      height: 1.9,
      letterSpacing: 0,
      color: color,
    );
  }

  // ---- Headings (Plus Jakarta Sans, ExtraBold 800) --------------------------
  // Titles sit in the 28–32px range at weight 800 for a premium, modern feel.
  static const TextStyle display = TextStyle(
    fontFamily: headingFont,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.2,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: headingFont,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const TextStyle title = TextStyle(
    fontFamily: headingFont,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.1,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: headingFont,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
  );

  // ---- Body / UI (Plus Jakarta Sans) ---------------------------------------
  static const TextStyle body = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  static const TextStyle label = TextStyle(
    fontFamily: bodyFont,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: bodyFont,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Primary button text — Bold, 16–18px.
  static const TextStyle button = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  /// Tags / badges — SemiBold 600, 12px (typically white on black).
  static const TextStyle badge = TextStyle(
    fontFamily: bodyFont,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );
}
