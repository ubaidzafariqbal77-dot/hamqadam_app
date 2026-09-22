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
  static const String faithIslam = '${_p}8521.jpg'; // crescent + star
  static const String faithChristianity = '${_p}4334.jpg'; // latin cross
  static const String faithHinduism = '${_p}9559.jpg'; // Om
  static const String faithSikhism = '${_p}3522.jpg'; // Khanda
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

  /// Watercolour floral briefcase — Career & Income (step 10).
  static const String careerBriefcase = '${_p}5077.jpg';

  /// 3D fingerprint — Security (step 11).
  static const String fingerprint = '${_p}7708.jpg';

  // ── Per-step hero artwork (watercolour medallions) ─────────────────────
  // Ordered through the icon set; each step renders its medallion above the
  // title. Swap any path when the artwork is formally named.
  static const String step02BasicInfo = dateBubble; // calendar bubble fits DOB
  static const String step03Faith = religionArt; // watercolour open book
  static const String step04Location = '${_p}4002.jpg'; // rose line-art pin
  static const String step05Contact = contactArt; // 3D shield heroine
  static const String step06Caste = floralArch; // floral-arch portrait
  static const String step08Education = '${_p}3893.jpg';
  // Step 09 (Physical) has no image slot in its reference — no art constant.
  static const String step10Career = careerBriefcase; // floral briefcase (ref_01)
  static const String step11Security = fingerprint; // 3D fingerprint
  static const String step12Photos = '${_p}4478.jpg';
  static const String step13About = '${_p}4515.jpg';
  static const String step14Verification = '${_p}4637.jpg';
  static const String step15Interests = '${_p}4724.jpg';
  static const String step16Family = '${_p}4990.jpg';
  static const String step17FamilyDetails = '${_p}5077.jpg';
  static const String step18Partner = '${_p}5146.jpg';
}
