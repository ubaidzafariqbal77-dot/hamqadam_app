import 'package:flutter/material.dart';

/// Central colour palette for the whole app.
///
/// Premium, elegant matrimonial theme: brand pastel pink #F4BFD1 (RGB
/// 244, 191, 209) reserved for fills, chips, badges and accents — while text,
/// borders and hints use a calm neutral ink scale so hierarchy actually reads.
/// Because the brand accent is a light pastel, every foreground drawn ON it
/// uses the deep dusty-rose inks below (white text is unreadable on it).
/// Every colour used anywhere in the UI must come from here so light/dark
/// theming stays consistent.
class AppColors {
  const AppColors._();

  // ---- Brand ----------------------------------------------------------------
  // Retuned to the requested pastel accent #F4BFD1 (RGB 244, 191, 209). The
  // pastel carries fills, chips, edges and gradients; `primaryInk` (deep dusty
  // rose) carries text/icons drawn ON the pastel, and `primaryDark` is the
  // readable brand ink on white/light surfaces.
  static const Color primary = Color(0xFFF4BFD1); // brand pastel pink accent
  static const Color primaryDark = Color(0xFFB25C82); // deep dusty rose ink on white
  static const Color primaryInk = Color(0xFF8E3D60); // readable foreground on the pastel
  static const Color primaryLight = Color(0xFFFBE3EC); // soft pink tint
  static const Color accent = Color(0xFFF4BFD1); // matches primary
  static const Color gold = Color(0xFFC9A24B); // subtle premium accent
  static const Color goldLight = Color(0xFFFBE3EC); // soft pink highlight

  // Brand gradient used on premium surfaces (auth headers, hero cards) —
  // a gentle pastel ramp around the brand accent.
  static const List<Color> brandGradient = <Color>[
    Color(0xFFF7CFDE),
    Color(0xFFF4BFD1),
    Color(0xFFEDA6C2),
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
  static const Color lightBackground = Color(0xFFFFFFFF); // pure white
  // Retuned white: the app-wide move to the white + hot-pink combination
  // means every canvas is plain white now. The rose* names stay so the many
  // call sites keep working — they just resolve to white/neutral today.
  static const Color roseCanvas = Color(0xFFFFFFFF); // former blush canvas → white
  static const Color roseCanvasDeep = Color(0xFFFAFAFA); // canvas gradient end → near-white
  static const Color roseFieldBorder = Color(0xFFE5E7EB); // field hairline → neutral gray
  static const Color lightSurface = Color(0xFFFFFFFF); // cards
  static const Color lightSurfaceAlt = Color(0xFFF6F4F5); // subtle neutral section
  static const Color lightTextPrimary = Color(0xFF1C1B20); // headings & values (ink)
  static const Color lightTextSecondary = Color(0xFF5D5A64); // body copy
  static const Color lightTextHint = Color(0xFF9B97A1); // field hints / placeholders
  static const Color lightInputText = Color(0xFF1C1B20); // text the USER types (ink)
  static const Color lightBorder = Color(0xFFE6E2E6); // field & card borders (neutral hairline)
  static const Color lightBorder2 = Color(0xFFE6E2E6);
  static const Color lightDivider = Color(0xFFECE9EC); // dividers

  // ---- Registration selection state -----------------------------------------
  // Retuned to white + hot-pink: a chosen card takes a soft pink wash (the
  // soul-50 tone) with a hot-pink edge, its label stays dark ink.
  static const Color roseSelectedFill = Color(0xFFFDF0F6); // chosen card wash
  static const Color roseSelectedBorder = Color(0xFFF4BFD1); // chosen card edge
  static const Color roseSelectedInk = Color(0xFF151515); // label on a chosen card
  static const Color roseSelectedDisc = Color(0xFFFBE3EC); // icon disc on a chosen card
  static const Color roseUnselectedDisc = Color(0xFFF3F4F6); // disc on an unchosen card

  // ---- Partner-preferences icon tiles (sampled from the reference mockup) ---
  // Unlike the dusty-rose wash above, a chosen tile here takes a PINK gradient
  // that deepens toward the bottom-right under a clear pink edge, and its label
  // turns pink rather than staying ink. Sampled off the Preferred-education
  // reference ("Any" tile).
  static const List<Color> partnerSelectedGradient = <Color>[
    Color(0xFFFDE7F1),
    Color(0xFFF4B6D2),
  ];
  static const Color partnerSelectedBorder = Color(0xFFEDA6C2); // chosen tile edge
  static const Color partnerSelectedInk = Color(0xFFB25C82); // label on a chosen tile
  static const Color partnerTileBorder = Color(0xFFF2E3E9); // unchosen tile hairline
  static const Color partnerTileInk = Color(0xFF3E3A46); // unchosen tile label
  static const Color partnerSectionInk = Color(0xFF3E3A46); // "Preferred education" heading

  // ---- Chat conversations ---------------------------------------------------
  // Retuned white + hot-pink: white canvas and cards, neutral inks, and the
  // saturated hot pink kept for the unread accent and the selected pill.
  static const Color chatCanvasTop = Color(0xFFFFFFFF); // canvas, top → white
  static const Color chatCanvasBottom = Color(0xFFFAFAFA); // canvas, bottom → near-white
  static const Color chatCardFill = Color(0xFFFFFFFF); // conversation card
  static const Color chatCardBorder = Color(0xFFF3F4F6); // card hairline → neutral
  static const Color chatTimeInk = Color(0xFF9CA3AF); // "10:24 AM"
  static const Color chatPreviewInk = Color(0xFF4B5563); // last-message line
  static const Color chatDottedLine = Color(0xFFE5E7EB); // dotted separator

  /// Pastel accent bar down the left edge of an unread conversation.
  static const List<Color> chatAccentBar = <Color>[
    Color(0xFFF4BFD1),
    Color(0xFFEDA6C2),
  ];

  /// The selected Chats/Calls pill — the pastel accent gradient.
  static const List<Color> chatPillGradient = <Color>[
    Color(0xFFF4BFD1),
    Color(0xFFEDA6C2),
  ];
  static const Color chatPillInk = Color(0xFF151515); // label on a white pill
  static const Color chatPillIdleInk = Color(0xFF9CA3AF); // label on an idle pill

  /// Ink for the Playfair step headings.
  ///
  /// Sampled off the references: most screens set the heading in a dark,
  /// slightly warm plum (Education #4A2D36, Caste #281711, Location #1F1E1E),
  /// so that is the default.
  static const Color roseTitleInk = Color(0xFF151515); // ink heading (was warm plum)

  /// The rose heading a few screens use instead — Gender (#874453),
  /// Interests (#9F5B67) and Family information (#A25C67) in the references.
  /// Passed explicitly via `StepScaffold.titleColor` on those screens only.
  static const Color roseTitleRose = Color(0xFF8C4552);

  // ---- Reference alert banner (Gender screen) -------------------------------
  // The references do not use a red error strip: the prompt is a soft pink card
  // with a gold "i" disc, a bold rose headline and a lighter second line.
  static const Color noticeBg = Color(0xFFFBE9E9);
  static const Color noticeInk = Color(0xFF632634);
  static const Color noticeIconDisc = Color(0xFFFBD5D2);
  static const Color noticeIconRing = Color(0xFFD9B36A);

  // ---- Registration chrome --------------------------------------------------
  // Retuned to the app-wide pastel voice: the accent is now the exact brand
  // pastel (F4BFD1) so registration matches the rest of the app.
  static const Color regAccent = Color(0xFFF4BFD1);
  static const Color regAccentSoft = Color(0xFFFBE3EC);
  static const List<Color> regPrimaryGradient = <Color>[
    Color(0xFFF7CFDE),
    Color(0xFFF4BFD1),
    Color(0xFFEDA6C2),
  ];

  // ---- Tip / "Did you know?" card (reference-sampled) -----------------------
  static const Color tipBg = Color(0xFFFCE8E9);
  static const Color tipTitleInk = Color(0xFF793542);
  static const Color tipBodyInk = Color(0xFF5B353A);
  static const Color tipDisc = Color(0xFFFBE7E8);
  static const Color tipGlyph = Color(0xFF89654B); // gold-brown outline bulb
  static const Color tipGoldBorder = Color(0xFFD9B36A);

  /// Rose the reference prints field labels in, inside the field card above
  /// the value (sampled from the Education screen).
  static const Color fieldLabelRose = Color(0xFF855966);

  /// The field's leading icon disc and glyph, sampled from the Education
  /// reference: a dusty rose circle with a dark warm outline mark.
  static const Color fieldIconDisc = Color(0xFFEAC9D0);
  static const Color fieldIconGlyph = Color(0xFF6B4741);

  /// Warm off-white the reference cards use instead of pure white.
  static const Color cardWarmWhite = Color(0xFFFDF9F8);

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
  static const Color requiredFieldBackgroundLight = Color(0xFFFFFFFF); // crisp white pill (reference style)
  static const Color optionalFieldBackgroundLight = Color(0xFFFFFFFF); // crisp white
  static const Color requiredFieldBorderLight = Color(0xFFE5E7EB); // neutral hairline
  static const Color optionalFieldBorderLight = Color(0xFFE5E7EB); // neutral hairline
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
  static const Color requiredBadge = primaryDark;
  static const Color optionalBadge = primaryLight;
}
