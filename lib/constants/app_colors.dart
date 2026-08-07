import 'package:flutter/material.dart';

/// Central colour palette for the whole app.
///
/// Clean, premium, elegant matrimonial theme built on the primary pink #F75F87.
/// Backgrounds stay pure white; cards and subtle sections use off-white #FCFCFC
/// and a soft pink wash #FFF5F8. Every colour used anywhere in the UI must come
/// from here so light/dark theming and the required/optional field system stay
/// consistent.
class AppColors {
  const AppColors._();

  // ---- Brand ----------------------------------------------------------------
  static const Color primary = Color(0xFFFF3B6B); // primary button pink
  static const Color primaryDark = Color(0xFFE92B58); // pressed / dark pink
  static const Color primaryLight = Color(0xFFFF7A9B); // soft pink tint
  static const Color accent = Color(0xFFFF3B6B); // matches primary
  static const Color gold = Color(0xFFC9A24B); // subtle premium accent
  static const Color goldLight = Color(0xFFFFD9E4); // soft pink highlight

  // Brand gradient used on premium surfaces (auth headers, buttons).
  static const List<Color> brandGradient = <Color>[
    Color(0xFFFF3B6B),
    Color(0xFFF52E5E),
    Color(0xFFE92B58),
  ];

  // ---- Semantic -------------------------------------------------------------
  static const Color success = Color(0xFF2E7D5B);
  static const Color warning = Color(0xFFC98A19);
  static const Color error = Color(0xFFC0392B);
  static const Color info = Color(0xFF2F6FB0);

  // ---- Light scheme — white base, brand-pink text (NEVER black/grey) --------
  // All text/icon colours are shades of the primary #FF3B6B so nothing renders
  // black or neutral-grey anywhere in the app.
  static const Color lightBackground = Color(0xFFFFFFFF); // pure white (all screens)
  static const Color lightSurface = Color(0xFFFAFAFA); // off-white cards
  static const Color lightSurfaceAlt = Color(0xFFF3F3F3); // subtle neutral section
  static const Color lightTextPrimary = Color(0xFFFF3B6B); // primary text & icons (brand pink)
  static const Color lightTextSecondary = Color(0xFFC23557); // body/secondary text (deep rose)
  static const Color lightTextHint = Color(0xFFFF8FAB); // field hints / placeholders (soft pink)
  static const Color lightInputText = Color(0xFF000000); // text the USER types (black, readable)
  static const Color lightBorder = primaryDark; // field & card borders (dark pink)
  static const Color lightBorder2 = primaryDark;
  static const Color lightDivider = Color(0xFFE5E5E5); // section dividers stay neutral

  // ---- Dark scheme — dark base, pink-tinted text (no neutral grey) ----------
  static const Color darkBackground = Color(0xFF121316); // near-black neutral
  static const Color darkSurface = Color(0xFF1C1D21);
  static const Color darkSurfaceAlt = Color(0xFF26272C);
  static const Color darkTextPrimary = Color(0xFFFF7A9B); // light brand pink (readable on dark)
  static const Color darkTextSecondary = Color(0xFFD98FA6); // muted pink
  static const Color darkTextHint = Color(0xFFB07186); // dim pink hints
  static const Color darkInputText = Color(0xFFF2F3F5); // text the USER types (near-white on dark)
  static const Color darkBorder = Color(0xFF33353B);
  static const Color darkDivider = Color(0xFF2A2C31);

  // ---- Field system (light) — clean white, neutral borders ------------------
  // Mandatory fields get a whisper of neutral fill; optional stay crisp white.
  // (Red is reserved for the error state.)
  static const Color requiredFieldBackgroundLight = Color(0xFFFAFAFA); // subtle neutral
  static const Color optionalFieldBackgroundLight = Color(0xFFFFFFFF); // crisp white
  static const Color requiredFieldBorderLight = primaryDark;
  static const Color optionalFieldBorderLight = primaryDark;
  static const Color fieldErrorBackgroundLight = Color(0xFFFDECEA);
  static const Color fieldDisabledBackgroundLight = Color(0xFFFF3B6B);

  // ---- Field system (dark) — elevated neutral surfaces ----------------------
  static const Color requiredFieldBackgroundDark = Color(0xFF262029); // elevated
  static const Color optionalFieldBackgroundDark = Color(0xFF1E1A22); // recessed
  static const Color requiredFieldBorderDark = Color(0xFF3C3542);
  static const Color optionalFieldBorderDark = Color(0xFF332D39);
  static const Color fieldErrorBackgroundDark = Color(0xFF3A1E1C);
  static const Color fieldDisabledBackgroundDark = Color(0xFF241E26);

  // Legend badge colours.
  static const Color requiredBadge = accent;
  static const Color optionalBadge = Color(0xFFFF9DB5); // soft pink (no grey)
}
