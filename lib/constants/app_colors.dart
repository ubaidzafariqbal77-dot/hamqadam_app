import 'package:flutter/material.dart';

/// Central colour palette for the whole app.
///
/// Premium, elegant matrimonial theme: brand pink #E85A8A reserved for
/// calls-to-action, focus rings, badges and accents — while text, borders and
/// hints use a calm neutral ink scale so hierarchy actually reads. Every colour
/// used anywhere in the UI must come from here so light/dark theming stays
/// consistent.
class AppColors {
  const AppColors._();

  // ---- Brand ----------------------------------------------------------------
  // Primary sits a touch deeper than the old #FF3B6B: it keeps the warmth but
  // passes contrast on white for text-sized uses (icons, links, chips).
  static const Color primary = Color(0xFFFE5783); // primary button pink
  static const Color primaryDark = Color(0xFFFE5783); // pressed / deep pink
  static const Color primaryLight = Color(0xFFF58BB0); // soft pink tint
  static const Color accent = Color(0xFFE85A8A); // matches primary
  static const Color gold = Color(0xFFC9A24B); // subtle premium accent
  static const Color goldLight = Color(0xFFFFD9E4); // soft pink highlight

  // Brand gradient used on premium surfaces (auth headers, hero cards).
  static const List<Color> brandGradient = <Color>[
    Color(0xFFF0689B),
    Color(0xFFE85A8A),
    Color(0xFFD63F73),
  ];

  // ---- Semantic -------------------------------------------------------------
  static const Color success = Color(0xFF2E7D5B);
  static const Color successSoft = Color(0xFFE4F3EC);
  static const Color warning = Color(0xFFC98A19);
  static const Color error = Color(0xFFD64541);
  static const Color info = Color(0xFF2F6FB0);

  // ---- Light scheme — white base, neutral ink text --------------------------
  // Buttons, links and selected chips are pink; the words people read are ink.
  // This is the single most important hierarchy rule in the app.
  static const Color lightBackground = Color(0xFFFDFBFC); // soft warm white
  static const Color lightSurface = Color(0xFFFFFFFF); // cards
  static const Color lightSurfaceAlt = Color(0xFFF6F4F5); // subtle neutral section
  static const Color lightTextPrimary = Color(0xFF1C1B20); // headings & values (ink)
  static const Color lightTextSecondary = Color(0xFF5D5A64); // body copy
  static const Color lightTextHint = Color(0xFF9B97A1); // field hints / placeholders
  static const Color lightInputText = Color(0xFF1C1B20); // text the USER types (ink)
  static const Color lightBorder = Color(0xFFE6E2E6); // field & card borders (neutral hairline)
  static const Color lightBorder2 = Color(0xFFE6E2E6);
  static const Color lightDivider = Color(0xFFECE9EC); // dividers

  // ---- Dark scheme — dark base, light neutral text --------------------------
  static const Color darkBackground = Color(0xFF141317); // near-black neutral
  static const Color darkSurface = Color(0xFF1D1C21);
  static const Color darkSurfaceAlt = Color(0xFF27262C);
  static const Color darkTextPrimary = Color(0xFFF4F2F5); // light neutral (readable on dark)
  static const Color darkTextSecondary = Color(0xFFB4B0BA); // muted
  static const Color darkTextHint = Color(0xFF7C7884); // dim hints
  static const Color darkInputText = Color(0xFFF4F2F5); // text the USER types
  static const Color darkBorder = Color(0xFF34323A);
  static const Color darkDivider = Color(0xFF2A2830);

  // ---- Field system (light) — clean white, neutral borders ------------------
  // Mandatory fields get a whisper of neutral fill; optional stay crisp white.
  // (Red is reserved for the error state.)
  static const Color requiredFieldBackgroundLight = Color(0xFFF8F6F7); // subtle neutral
  static const Color optionalFieldBackgroundLight = Color(0xFFFFFFFF); // crisp white
  static const Color requiredFieldBorderLight = Color(0xFFE6E2E6);
  static const Color optionalFieldBorderLight = Color(0xFFE6E2E6);
  static const Color fieldErrorBackgroundLight = Color(0xFFFDF1F0);
  static const Color fieldDisabledBackgroundLight = Color(0xFFF1EFF1); // greyed out, not pink

  // ---- Field system (dark) — elevated neutral surfaces ----------------------
  static const Color requiredFieldBackgroundDark = Color(0xFF27262C);
  static const Color optionalFieldBackgroundDark = Color(0xFF1D1C21);
  static const Color requiredFieldBorderDark = Color(0xFF3A3840);
  static const Color optionalFieldBorderDark = Color(0xFF34323A);
  static const Color fieldErrorBackgroundDark = Color(0xFF3A1E1C);
  static const Color fieldDisabledBackgroundDark = Color(0xFF1A191D);

  // Legend badge colours.
  static const Color requiredBadge = primary;
  static const Color optionalBadge = primaryLight;
}
