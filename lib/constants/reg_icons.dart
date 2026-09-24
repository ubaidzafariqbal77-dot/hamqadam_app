import 'package:flutter/material.dart';

/// Central registry for the watercolour icon set shipped in
/// `assets/latest_reg_icons/` (92 WhatsApp imports, mixed png/jpg, all
/// 1600×1600 squares).
///
/// Files keep their original names so replacing any artwork later is a plain
/// file swap — no code change. Identified so far:
///  * `1403` / `9480`        — height measuring rulers (physical + partner height)
///  * `3585`                 — calendar bubble showing "30" (basic-info DOB field)
///  * `1684`/`3935`/`2533`/`3678` — numbered gradient badges 01–04 (choice rows)
///  * `relegion.png`         — watercolour open book (Religion & language hero)
///  * `contact-info.jpg`     — 3D heroine with security shield (Contact hero)
///  * WA8521 crescent+star · WA4334 latin cross · WA9559 Om · WA3522 Khanda ·
///    WA3228 Star of David  — the 3D faith-symbol set (religion picker rows)
///  * WA7298                 — 3D globe + speech bubbles (language)
///  * WA4002                 — rose line-art location pin (Location hero)
///  * WA7369 / WA4515        — floral-arch line-art portraits (caste / about)
///  * WA7708                 — 3D fingerprint (Security hero)
///
/// Unidentified squares are decorative watercolour medallions; steps pick one
/// that matches their theme. When the artwork is finally named properly just
/// update the constant here — every screen reads through this registry.
class RegIcons {
  const RegIcons._();

  static const String _dir = 'assets/latest_reg_icons';
  static const String _p = '$_dir/IMG-20260921-WA';

  // ── Identified artwork ──────────────────────────────────────────────────
  /// Height measuring ruler — Physical information (step 09).
  static const String heightRuler = '$_dir/1403.png';

  /// Second ruler variant — Partner height range (step 18).
  static const String heightRulerAlt = '$_dir/9480.png';

  /// Calendar bubble "30" — Basic info date of birth (step 02).
  static const String dateBubble = '$_dir/3585.png';

  /// Numbered gradient badges — the 01–04 choice-row discs (step 01 rows).
  static const String badge01 = '$_dir/1684.png';
  static const String badge02 = '$_dir/3935.png';
  static const String badge03 = '$_dir/2533.png';
  static const String badge04 = '$_dir/3678.png';

  /// Watercolour open book — Religion & language (step 03).
  static const String religionArt = '$_dir/relegion.png';

  /// 3D heroine with security shield — Contact information (step 05).
  static const String contactArt = '$_dir/contact-info.jpg';

  /// 3D faith symbols — the Religion picker's per-row icons.
  // Verified against the artwork itself: 8521 is a house outline, 4334 is the
  // graduation cap, and 3522 is a blank swatch — those three rows were drawing
  // the wrong picture (or none at all) in the religion picker.
  static const String faithIslam = '${_p}6383.jpg'; // crescent + star
  static const String faithChristianity = '${_p}0029.jpg'; // latin cross
  static const String faithHinduism = '${_p}9559.jpg'; // Om
  static const String faithSikhism = '${_p}3986.jpg'; // Khanda
  static const String faithInterfaith = '${_p}3228.jpg'; // Star of David

  /// Offline `religion_id → artwork` map (ids match
  /// `assets/lookups/dropdown_reference.json`). Rows without an entry render
  /// without a glyph.
  static const Map<int, String> religionRowArt = <int, String>{
    1: faithIslam,
    2: faithChristianity,
    3: faithHinduism,
    4: faithSikhism,
    5: faithInterfaith,
  };

  /// 3D globe + speech bubbles — Language field disc.
  static const String languageGlobe = '${_p}7298.jpg';

  /// Floral-arch line-art portrait — Caste (step 06).
  static const String floralArch = '${_p}7369.jpg';

  /// Briefcase in a soft pink disc — Career & Income (step 10).
  ///
  /// 5077 is a black line-art briefcase: correct subject, wrong palette — it
  /// read as a stray monochrome sticker on the rose canvas.
  static const String careerBriefcase = '${_p}0659.jpg';

  /// 3D fingerprint — Security (step 11).
  static const String fingerprint = '${_p}7708.jpg';

  /// Clock artwork on the Preferred-age range question (named import — the
  /// reference's hero + "TIME MACHINE" badge art).
  static const String preferredAge = '$_dir/pre_age.png';

  /// The Marital-status reference's option glyphs, drawn as thin Material
  /// line-art inside each option's soft pink disc: person (Never Married),
  /// broken heart (Divorced), filled heart (Widowed), hourglass (Awaiting
  /// Divorce), plus (Annulled), two people (Separated). Matched on the
  /// server's wording rather than list position, so a renamed or reordered
  /// lookup still draws the right mark.
  static IconData maritalStatusGlyph(String name) {
    final String n = name.toLowerCase();
    if (n.contains('never')) return Icons.person_outline_rounded;
    if (n.contains('divorc') && n.contains('await')) {
      return Icons.hourglass_bottom_rounded;
    }
    if (n.contains('divorc')) return Icons.heart_broken_rounded;
    if (n.contains('widow')) return Icons.favorite_rounded;
    if (n.contains('annul')) return Icons.add_rounded;
    if (n.contains('separat')) return Icons.people_outline_rounded;
    return Icons.person_outline_rounded;
  }

  // ── Per-step hero artwork (watercolour medallions) ─────────────────────
  // Ordered through the icon set; each step renders its medallion above the
  // title. Swap any path when the artwork is formally named.
  static const String step02BasicInfo = dateBubble; // calendar bubble fits DOB
  static const String step03Faith = religionArt; // watercolour open book
  static const String step04Location = '${_p}4002.jpg'; // rose line-art pin
  static const String step05Contact = contactArt; // 3D shield heroine
  static const String step06Caste = floralArch; // floral-arch portrait
  // Was a plain heart; the reference's Education hero is the gold cap + book.
  static const String step08Education = '${_p}4334.jpg'; // grad cap + open book
  // Step 09 (Physical) has no image slot in its reference — no art constant.
  static const String step10Career = careerBriefcase; // floral briefcase (ref_01)
  static const String step11Security = fingerprint; // 3D fingerprint
  static const String step12Photos = '${_p}7771.jpg'; // 3D couple (was a roast dinner)
  static const String step13About = '${_p}6720.jpg'; // open book + heart (was a broken heart)
  static const String step14Verification = '${_p}4637.jpg';
  static const String step15Interests = '${_p}0506.jpg'; // sparkles (was a map pin)
  static const String step16Family = '${_p}6684.jpg'; // group of people
  static const String step17FamilyDetails = '${_p}7768.jpg'; // home + hearts (was a briefcase)
  // 5146 is a black line-art handshake — same monochrome clash as the old
  // briefcase, and a handshake is a business gesture, not a marriage one.
  static const String step18Partner = '${_p}0704.jpg'; // two watercolour hearts

  /// Watercolour double hearts — the hero on the Partner-preferences marital
  /// status screen (reference mockup).
  static const String heartsWatercolor = '${_p}4032.jpg';

  /// 3D education artwork for the Preferred-education tiles, matched on the
  /// option's wording so a renamed or reordered list still draws the right
  /// picture (the reference draws a book + heart for "Any", then steps up
  /// through caps, stacked books and, for Masters, a rolled degree).
  static const String educationBookHeart = '${_p}6832.jpg'; // open book + heart
  static const String educationCap = '${_p}5246.jpg'; // graduation cap
  static const String educationBooks = '${_p}6385.jpg'; // stacked books
  static const String educationCapBook = '${_p}4334.jpg'; // cap + open book

  /// Artwork per Preferred-education option. "Masters or above" is left out on
  /// purpose — that artwork is not in the set yet, so the card falls back to
  /// [educationGlyph] until the file is named and added here.
  static const Map<String, String> partnerEducationArt = <String, String>{
    'Any': educationBookHeart,
    'Matric or above': educationCap,
    'Intermediate or above': educationBooks,
    'Bachelors or above': educationCapBook,
  };

  /// Thin line-art fallback for a Preferred-education card without artwork.
  static IconData educationGlyph(String name) {
    final String n = name.toLowerCase();
    if (n.contains('master')) return Icons.workspace_premium_outlined;
    if (n.contains('bachelor')) return Icons.school_outlined;
    if (n.contains('intermediate')) return Icons.menu_book_outlined;
    if (n.contains('matric')) return Icons.school_rounded;
    return Icons.auto_stories_outlined; // Any
  }

  /// Thin line-art fallback for a Preferred-profession tile.
  static IconData professionGlyph(String name) {
    final String n = name.toLowerCase();
    if (n.contains('government')) return Icons.account_balance_outlined;
    if (n.contains('private')) return Icons.apartment_outlined;
    if (n.contains('business') || n.contains('self')) {
      return Icons.storefront_outlined;
    }
    if (n.contains('defence') || n.contains('defense')) {
      return Icons.shield_outlined;
    }
    if (n.contains('professional') || n.contains('doctor')) {
      return Icons.medical_services_outlined;
    }
    return Icons.work_outline_rounded; // Any
  }

  /// Thin line-art fallback for a Preferred-diet tile.
  static IconData dietGlyph(String name) {
    final String n = name.toLowerCase();
    if (n.contains('non') || n.contains('no-veg')) return Icons.set_meal_outlined;
    if (n.contains('veg')) return Icons.eco_outlined;
    return Icons.restaurant_outlined; // Any
  }

  /// Line-art glyph for a "Profile managed by" tile.
  static IconData managedByGlyph(String name) {
    final String n = name.toLowerCase();
    if (n.contains('parent')) return Icons.family_restroom_rounded;
    if (n.contains('sibling')) return Icons.people_outline_rounded;
    if (n.contains('relative')) return Icons.diversity_1_outlined;
    if (n.contains('guardian')) return Icons.shield_outlined;
    return Icons.person_outline_rounded; // Self
  }

  /// Line-art fallback for a faith tile whose artwork is not in the set.
  static IconData faithGlyph(String name) => Icons.auto_awesome_outlined;

  /// Artwork for each Partner-preferences sub-question.
  ///
  /// That step asks twelve questions behind one heading, and every one of them
  /// used to sit under the same pair of hearts. The references give each its
  /// own subject — a map for location, faith symbols for religion, a ruler for
  /// height — which is also the only thing on screen that tells the member the
  /// question changed. Keys match `Step18Controller.questions`; a key with no
  /// entry falls back to [step18Partner].
  static const Map<String, String> partnerQuestionArt = <String, String>{
    // The Family-details-style reference draws this question straight on the
    // canvas with no illustration slot — an empty string suppresses the hero.
    'marital': '',
    'age': preferredAge, // clock (age-range reference)
    'height': '${_p}7905.jpg', // two people against a height chart
    'religion': '${_p}3585.jpg', // clustered faith symbols
    'caste': '${_p}7708.jpg', // fingerprint (lineage)
    'language': languageGlobe, // globe + speech bubbles
    'location': '${_p}6608.jpg', // map, pin and hearts
    'education': '${_p}8371.jpg', // graduation cap + book
    'profession': careerBriefcase, // briefcase disc
    'income': '${_p}8315.jpg', // diamond
    'diet': '${_p}8003.jpg', // bowl of vegetables
  };
}
