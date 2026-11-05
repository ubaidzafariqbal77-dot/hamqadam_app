import 'package:flutter/material.dart';

/// Central registry for the registration flow's iconography.
///
/// The flow used to ship ~15 MB of raster watercolour art. Every constant here
/// is now a symbolic key (`icon:<name>`) that [iconFor] resolves to a rounded
/// Material glyph, drawn by `RegIconBadge` on the brand gradient. Keys stay
/// strings so each step keeps passing `art:` / `image:` exactly as before.
class RegIcons {
  const RegIcons._();

  static const String _k = 'icon:';

  /// True when [key] names one of the registration icons below.
  static bool isIcon(String? key) => key != null && key.startsWith(_k);

  /// The glyph behind a key (heart for an unknown key).
  static IconData iconFor(String key) => _glyphs[key] ?? Icons.favorite_rounded;

  static const Map<String, IconData> _glyphs = <String, IconData>{
    heightRuler: Icons.straighten_rounded,
    dateBubble: Icons.calendar_month_rounded,
    religionArt: Icons.mosque_rounded,
    contactArt: Icons.contact_phone_rounded,
    faithIslam: Icons.mosque_rounded,
    faithChristianity: Icons.church_rounded,
    faithHinduism: Icons.temple_hindu_rounded,
    faithSikhism: Icons.self_improvement_rounded,
    faithInterfaith: Icons.diversity_3_rounded,
    languageGlobe: Icons.translate_rounded,
    floralArch: Icons.account_tree_rounded,
    careerBriefcase: Icons.work_rounded,
    fingerprint: Icons.lock_person_rounded,
    preferredAge: Icons.cake_rounded,
    step04Location: Icons.location_on_rounded,
    step08Education: Icons.school_rounded,
    step12Photos: Icons.photo_camera_rounded,
    step13About: Icons.edit_note_rounded,
    step14Verification: Icons.verified_user_rounded,
    step15Interests: Icons.interests_rounded,
    step16Family: Icons.family_restroom_rounded,
    step17FamilyDetails: Icons.home_rounded,
    step18Partner: Icons.favorite_rounded,
    educationBookHeart: Icons.auto_stories_rounded,
    educationCap: Icons.school_rounded,
    educationBooks: Icons.menu_book_rounded,
    educationCapBook: Icons.workspace_premium_rounded,
    _partnerHeight: Icons.height_rounded,
    _partnerLocation: Icons.map_rounded,
    _partnerIncome: Icons.account_balance_wallet_rounded,
    _partnerDiet: Icons.restaurant_rounded,
    _partnerReligion: Icons.mosque_rounded,
  };

  // ── Field / step icons ──────────────────────────────────────────────────
  static const String heightRuler = '${_k}height';
  static const String heightRulerAlt = heightRuler;
  static const String dateBubble = '${_k}calendar';
  static const String religionArt = '${_k}religion';
  static const String contactArt = '${_k}contact';

  static const String faithIslam = '${_k}islam';
  static const String faithChristianity = '${_k}christianity';
  static const String faithHinduism = '${_k}hinduism';
  static const String faithSikhism = '${_k}sikhism';
  static const String faithInterfaith = '${_k}other_faith';

  /// `religion_id → icon` (ids match `assets/lookups/dropdown_reference.json`).
  static const Map<int, String> religionRowArt = <int, String>{
    1: faithIslam,
    2: faithChristianity,
    3: faithHinduism,
    4: faithSikhism,
    5: faithInterfaith,
  };

  static const String languageGlobe = '${_k}language';
  static const String floralArch = '${_k}caste';
  static const String careerBriefcase = '${_k}career';
  static const String fingerprint = '${_k}security';
  static const String preferredAge = '${_k}age';

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

  // ── Per-step hero icons ────────────────────────────────────────────────
  static const String step02BasicInfo = dateBubble;
  static const String step03Faith = religionArt;
  static const String step04Location = '${_k}location';
  static const String step05Contact = contactArt;
  static const String step06Caste = floralArch;
  static const String step08Education = '${_k}education';
  static const String step10Career = careerBriefcase;
  static const String step11Security = fingerprint;
  static const String step12Photos = '${_k}photos';
  static const String step13About = '${_k}about';
  static const String step14Verification = '${_k}verification';
  static const String step15Interests = '${_k}interests';
  static const String step16Family = '${_k}family';
  static const String step17FamilyDetails = '${_k}home';
  static const String step18Partner = '${_k}partner';
  static const String heartsWatercolor = step18Partner;

  static const String educationBookHeart = '${_k}edu_any';
  static const String educationCap = '${_k}edu_cap';
  static const String educationBooks = '${_k}edu_books';
  static const String educationCapBook = '${_k}edu_degree';

  static const String _partnerHeight = '${_k}p_height';
  static const String _partnerLocation = '${_k}p_location';
  static const String _partnerIncome = '${_k}p_income';
  static const String _partnerDiet = '${_k}p_diet';
  static const String _partnerReligion = '${_k}p_religion';

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
    'marital': '',
    'age': preferredAge,
    'height': _partnerHeight,
    'religion': _partnerReligion,
    'caste': floralArch,
    'language': languageGlobe,
    'location': _partnerLocation,
    'education': step08Education,
    'profession': careerBriefcase,
    'income': _partnerIncome,
    'diet': _partnerDiet,
  };
}
