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
  // Registration canvas, sampled from the references (#FFF3F3 / #F7EEEF /
  // #FBEFEF across screens): a very light warm blush that barely graduates,
  // not the deeper pink this used to be — which is what made our screens read
  // hotter than the designs.
  static const Color roseCanvas = Color(0xFFFDF4F4); // registration canvas (reference)
  static const Color roseCanvasDeep = Color(0xFFF7EAEB); // canvas gradient end
  static const Color roseFieldBorder = Color(0xFFF5C6D6); // field hairline on white cards
  static const Color lightSurface = Color(0xFFFFFFFF); // cards
  static const Color lightSurfaceAlt = Color(0xFFF6F4F5); // subtle neutral section
  static const Color lightTextPrimary = Color(0xFF1C1B20); // headings & values (ink)
  static const Color lightTextSecondary = Color(0xFF5D5A64); // body copy
  static const Color lightTextHint = Color(0xFF9B97A1); // field hints / placeholders
  static const Color lightInputText = Color(0xFF1C1B20); // text the USER types (ink)
  static const Color lightBorder = Color(0xFFE6E2E6); // field & card borders (neutral hairline)
  static const Color lightBorder2 = Color(0xFFE6E2E6);
  static const Color lightDivider = Color(0xFFECE9EC); // dividers

  // ---- Registration selection state (sampled from the design references) ----
  // The references do NOT fill a chosen card with the saturated button pink:
  // the card takes a soft dusty-rose wash and its label stays dark ink, so a
  // grid of options still reads as text rather than as a row of buttons.
  // Sampled off the Marital status and Preferred education screens.
  // Re-sampled at full resolution off the Marital status reference.
  static const Color roseSelectedFill = Color(0xFFEAB7BC); // chosen card wash
  static const Color roseSelectedBorder = Color(0xFFDFA3AA); // chosen card edge
  static const Color roseSelectedInk = Color(0xFF291017); // label on a chosen card
  static const Color roseSelectedDisc = Color(0xFFF0D0D5); // icon disc on a chosen card
  static const Color roseUnselectedDisc = Color(0xFFF7E3E5); // disc on an unchosen card

  // ---- Partner-preferences icon tiles (sampled from the reference mockup) ---
  // Unlike the dusty-rose wash above, a chosen tile here takes a PINK gradient
  // that deepens toward the bottom-right under a clear pink edge, and its label
  // turns pink rather than staying ink. Sampled off the Preferred-education
  // reference ("Any" tile).
  static const List<Color> partnerSelectedGradient = <Color>[
    Color(0xFFFDE7F1),
    Color(0xFFF4B6D2),
  ];
  static const Color partnerSelectedBorder = Color(0xFFDE8CB6); // chosen tile edge
  static const Color partnerSelectedInk = Color(0xFFD6538C); // label on a chosen tile
  static const Color partnerTileBorder = Color(0xFFF2E3E9); // unchosen tile hairline
  static const Color partnerTileInk = Color(0xFF3E3A46); // unchosen tile label
  static const Color partnerSectionInk = Color(0xFF3E3A46); // "Preferred education" heading

  // ---- Chat conversations ("Chat Conversations" reference) ----------------
  // The chat list is drawn on a blush canvas, NOT the brand-gradient header the
  // rest of the shell uses: white cards float on a warm pink wash, an unread
  // conversation is marked by a rose bar down the card's left edge, and the
  // count badge is the one saturated pink element on the screen.
  static const Color chatCanvasTop = Color(0xFFFEF8FA); // canvas, top
  static const Color chatCanvasBottom = Color(0xFFFBE6EC); // canvas, bottom
  static const Color chatCardFill = Color(0xFFFEFCFD); // conversation card
  static const Color chatCardBorder = Color(0xFFF6E2E9); // card hairline
  static const Color chatTimeInk = Color(0xFFBE8B9B); // "10:24 AM"
  static const Color chatPreviewInk = Color(0xFF5A4550); // last-message line
  static const Color chatDottedLine = Color(0xFFEBC8D3); // dotted separator

  /// Rose bar down the left edge of an unread conversation.
  static const List<Color> chatAccentBar = <Color>[
    Color(0xFFF7C6D5),
    Color(0xFFE79EB5),
  ];

  /// The selected Chats/Calls pill.
  static const List<Color> chatPillGradient = <Color>[
    Color(0xFFF6C4D2),
    Color(0xFFE8A2B7),
  ];
  static const Color chatPillInk = Color(0xFF7C3A4C); // label on the rose pill
  static const Color chatPillIdleInk = Color(0xFF9C8792); // label on a white pill

  /// Ink for the Playfair step headings.
  ///
  /// Sampled off the references: most screens set the heading in a dark,
  /// slightly warm plum (Education #4A2D36, Caste #281711, Location #1F1E1E),
  /// so that is the default.
  static const Color roseTitleInk = Color(0xFF3E2732);

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

  // ---- Registration chrome (reference-sampled) ------------------------------
  // The designs do NOT use the saturated brand pink inside the registration
  // flow: the primary button, the progress fill and the back chevron are all a
  // muted dusty rose (sampled #DC8193 … #C78690). Scoped to this flow so the
  // rest of the app keeps [brandGradient].
  static const Color regAccent = Color(0xFFD98B9B);
  static const Color regAccentSoft = Color(0xFFEBBFC7);
  static const List<Color> regPrimaryGradient = <Color>[
    Color(0xFFE9A8B5),
    Color(0xFFDC8E9C),
    Color(0xFFCE8492),
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
  static const Color requiredFieldBorderLight = Color(0xFFF5C6D6); // soft pink hairline
  static const Color optionalFieldBorderLight = Color(0xFFF5C6D6); // soft pink hairline
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
