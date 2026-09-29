import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/api_endpoints.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../models/lookup_item_model.dart';
import '../widgets/entry_dialog.dart';
import '../../help_center/views/guest_help_view.dart';

 
class WelcomePreviewView extends StatefulWidget {
  const WelcomePreviewView({super.key});

  /// Owner support line shown on the banner. `wa.me` links work on both
  /// platforms without any extra setup.
  static const String _whatsappNumber = '923001234567';

  @override
  State<WelcomePreviewView> createState() => _WelcomePreviewViewState();
}

class _WelcomePreviewViewState extends State<WelcomePreviewView> {
  /// Shown while the live feed loads and kept as the fallback if it fails —
  /// a first-time visitor must never land on a blank marketing screen.
  static const List<_PreviewProfile> _fallbackProfiles = <_PreviewProfile>[
    _PreviewProfile(
      name: 'Eleanor Rowe',
      about:
          'Creative strategist passionate about design systems and user-centered solutions.',
      verified: true,
      age: 27,
      city: 'San Francisco',
      profession: 'Product Designer',
      family: 'Family Oriented',
    ),
    _PreviewProfile(
      name: 'Marcus Chen',
      about: 'Builder at heart, loves scalable systems and clean code.',
      verified: true,
      age: 30,
      city: 'New York',
      profession: 'Software Engineer',
      family: 'Family Oriented',
    ),
    _PreviewProfile(
      name: 'Isabella Martinez',
      about: 'Empathy-driven, exploring behavioral patterns and user insights.',
      verified: true,
      age: 26,
      city: 'Austin',
      profession: 'UX Researcher',
      family: 'Family Oriented',
    ),
  ];

  List<_PreviewProfile> _profiles = _fallbackProfiles;
  bool _loading = true;
  int _memberCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  /// Guest feed — no token needed. Any failure keeps the sample cards.
  Future<void> _loadFeed() async {
    try {
      final ApiClient client = Get.find<ApiClient>();
      final res = await client.get(ApiEndpoints.publicDiscover);
      final List<dynamic> raw = (res.dataMap['profiles'] as List<dynamic>?) ?? <dynamic>[];
      // Lookup names (religion/sect/education) resolve client-side from the
      // dropdown reference cache — the guest payload carries ids only.
      final List<_PreviewProfile> fetched = raw
          .map((dynamic e) => _PreviewProfile.fromJson(_withLookupNames(e)))
          .whereType<_PreviewProfile>()
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        if (fetched.isNotEmpty) _profiles = fetched;
        _memberCount = (res.dataMap['total_members'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Adds human-readable names for the id-only lookup fields (religion, sect,
  /// education) the guest feed sends, using the bundled dropdown reference.
  /// A failed lookup leaves the field empty — the card simply drops that row.
  Map<String, dynamic> _withLookupNames(dynamic raw) {
    final Map<String, dynamic> map = <String, dynamic>{
      if (raw is Map<String, dynamic>) ...raw,
    };
    try {
      final LookupController lookup = Get.find<LookupController>();
      String? nameOf(String key, dynamic id) {
        final int? i = id is num ? id.toInt() : int.tryParse('$id');
        if (i == null) return null;
        for (final LookupItem item in lookup.itemsOf(key)) {
          if (item.id == i) return item.name;
        }
        return null;
      }

      map['religion'] =
          map['religion'] ?? nameOf(LookupKeys.religions, map['religion_id']);
      map['sect'] = map['sect'] ??
          nameOf(LookupKeys.sectMain, map['sect_main_id']) ??
          nameOf(LookupKeys.schoolOfThought, map['school_of_thought_id']);
      map['education'] = map['education'] ??
          nameOf(LookupKeys.educationLevels, map['education_level_id']) ??
          nameOf(LookupKeys.degrees, map['degree_id']);
    } catch (_) {
      // Lookups unavailable (very first launch) — the card shows what it has.
    }
    return map;
  }

  Future<void> _openWhatsApp() async {
    final Uri url = Uri.parse(
        'https://wa.me/${WelcomePreviewView._whatsappNumber}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _openEntryDialog(BuildContext context) => EntryDialog.show(context);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // The reference's soft pink canvas; content scrolls and the help /
        // WhatsApp buttons float above the bottom-right corner.
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            // Help Centre — neat white circle with the agent glyph, no
            // banner screaming for attention.
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              child: InkWell(
                onTap: GuestHelpView.open,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // WhatsApp — the single floating green button, icon only.
            Material(
              color: const Color(0xFF25D366),
              borderRadius: BorderRadius.circular(999),
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.22),
              child: InkWell(
                onTap: _openWhatsApp,
                customBorder: const CircleBorder(),
                child:   SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.asset( 
                    'assets/icons/whatsapp.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  // Icon(Icons.chat_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFFF9D3E0), // soft rose
                Color(0xFFF6C3D4), // mid rose
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // ---- Brand row (tappable too) -------------------
                        GestureDetector(
                          onTap: () => _openEntryDialog(context),
                          child: Row(
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  'assets/icons/logo.png',
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.favorite_rounded,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'HamQadam',
                                style: AppTextStyles.title.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl + 4),

                        // ---- Headline -----------------------------------
                        Text(
                          'Proposals for you',
                          style: AppTextStyles.display.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.lightTextPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm + 2),
                        Text(
                          _memberCount > 0
                              ? 'Handpicked matches from $_memberCount verified members'
                              : 'Handpicked matches aligned with your preferences',
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 15,
                            height: 1.45,
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl - 4),

                        // ---- Search preview (tappable) ------------------
                        GestureDetector(
                          onTap: () => _openEntryDialog(context),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg + 4),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFFB4487B)
                                      .withValues(alpha: 0.08),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.search_rounded,
                                  color: AppColors.lightTextSecondary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Search by location, profession...',
                                    style: AppTextStyles.bodyStrong.copyWith(
                                      color: AppColors.lightTextSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg + 4),

                        // ---- Match cards (live feed) --------------------
                        if (_loading)
                          ...List<Widget>.filled(
                            3,
                            const Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.lg),
                              child: _SkeletonCard(),
                            ),
                          )
                        else
                          ..._profiles.map(
                            (_PreviewProfile p) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.lg),
                              child: _PreviewCard(
                                profile: p,
                                onTap: () => _openEntryDialog(context),
                              ),
                            ),
                          ),

                        // ---- Bottom action row --------------------------
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openEntryDialog(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryDark,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Log in',
                                  style: AppTextStyles.button.copyWith(
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _openEntryDialog(context),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: AppColors.primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Create Account',
                                  style: AppTextStyles.button.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Clearance so the Log in / Create Account row is
                        // never covered by the floating buttons.
                        const SizedBox(height: 72),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One preview profile card — a taste of the real feed behind login.
/// The guest preview card — the SAME design as the signed-in Discover card:
/// portrait photo left (Verified chip top-left, heart bottom-right), content
/// right (name, age/height/faith chips, location, education+job row, family
/// line). Tapping anywhere opens the Create Account / Login dialog.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.profile, required this.onTap});

  final _PreviewProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String heightLabel = profile.heightLabel ?? '';
    final List<String> metaParts = <String>[
      if (profile.age != null) '${profile.age} Years',
      if (heightLabel.isNotEmpty) heightLabel,
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFB4487B).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ---- PHOTO — Verified chip top-left, heart bottom-right -----
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 96,
                  height: 116,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.lightSurfaceAlt,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (profile.photoUrl?.isNotEmpty ?? false)
                      ? Image.network(
                          profile.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: AppColors.lightTextSecondary,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          color: AppColors.lightTextSecondary,
                          size: 40,
                        ),
                ),
                // Verified chip — white pill with the pink tick.
                if (profile.verified)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.verified_rounded,
                              size: 10, color: AppColors.primary),
                          SizedBox(width: 3),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Favourite heart — same white circular button; a guest tap
                // opens the entry dialog like everything else here.
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 16,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // ---- CONTENT — the Discover card's fact layout ---------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    profile.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),

                  // Chips row — age · height · faith · sect.
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (profile.age != null)
                        _PreviewIconChip(
                            icon: Icons.cake_outlined,
                            label: '${profile.age} Years'),
                      if (heightLabel.isNotEmpty) ...<Widget>[
                        const _PreviewDot(),
                        _PreviewIconChip(
                            icon: Icons.height_rounded, label: heightLabel),
                      ],
                      if (profile.religion != null) ...<Widget>[
                        const _PreviewDot(),
                        _PreviewIconChip(
                            icon: Icons.nightlight_round,
                            label: profile.religion!),
                      ],
                      if (profile.sect != null) ...<Widget>[
                        const _PreviewDot(),
                        _PreviewIconChip(
                            icon: Icons.menu_book_rounded,
                            label: profile.sect!),
                      ],
                    ],
                  ),

                  // Location.
                  if (profile.city != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _PreviewFactCell(
                          icon: Icons.location_on_outlined,
                          label: profile.city!),
                    ),

                  // Education + job — two-column row.
                  if (profile.education != null || profile.profession != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: <Widget>[
                          if (profile.education != null)
                            Expanded(
                              child: _PreviewFactCell(
                                  icon: Icons.school_outlined,
                                  label: profile.education!),
                            ),
                          if (profile.profession != null)
                            Expanded(
                              child: _PreviewFactCell(
                                  icon: Icons.work_outline_rounded,
                                  label: profile.profession!),
                            ),
                        ],
                      ),
                    ),

                  // Family line.
                  if (profile.family != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _PreviewFactCell(
                          icon: Icons.home_outlined, label: profile.family!),
                    ),

                  // Introduction — the about line the old card showed.
                  if (profile.about.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      profile.about,
                      style: AppTextStyles.caption.copyWith(
                        height: 1.4,
                        color: AppColors.lightInputText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Bottom row — the "94% Match"-style pill slot shows the
                  // member count badge for guests, plus the proposal button.
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.favorite_rounded,
                                size: 10, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              metaParts.isEmpty ? 'HamQadam Match' : metaParts.first,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny glyph chip for the guest card's facts row (same recipe as the
/// Discover card's _IconChip).
class _PreviewIconChip extends StatelessWidget {
  const _PreviewIconChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 10, color: AppColors.primary),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }
}

/// Pink glyph + label fact line (same recipe as the Discover card's
/// _FactCell).
class _PreviewFactCell extends StatelessWidget {
  const _PreviewFactCell({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 11, color: AppColors.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Dotted separator between the guest card's chips.
class _PreviewDot extends StatelessWidget {
  const _PreviewDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.lightTextHint,
      ),
    );
  }
}

/// Grey placeholder shown while the live feed loads.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 138,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 96,
            height: 116,
            decoration: BoxDecoration(
              color: AppColors.lightSurfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 140,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.lightSurfaceAlt,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.lightSurfaceAlt,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.lightSurfaceAlt,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A guest-feed card. Built from `GET /public/discover`; malformed rows are
/// skipped instead of crashing the marketing screen.
class _PreviewProfile {
  const _PreviewProfile({
    required this.name,
    required this.about,
    required this.verified,
    this.photoUrl,
    this.age,
    this.heightLabel,
    this.city,
    this.religion,
    this.sect,
    this.education,
    this.profession,
    this.family,
  });

  final String name;
  final String about;
  final bool verified;
  final String? photoUrl;
  final int? age;
  final String? heightLabel;
  final String? city;
  final String? religion;
  final String? sect;
  final String? education;
  final String? profession;
  final String? family;

  static _PreviewProfile? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final String name = (raw['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;

    return _PreviewProfile(
      name: name,
      about: (raw['introduction'] ?? '').toString().trim(),
      verified: raw['verified'] == true,
      photoUrl: (raw['photo'] ?? '').toString().trim().isEmpty
          ? null
          : (raw['photo'] ?? '').toString(),
      // Backend computes age from the birthday; test rows without a real one
      // come through as 0 — hiding those keeps the card line clean.
      age: switch (raw['age']) {
        final num n when n.toInt() > 0 => n.toInt(),
        _ => null,
      },
      heightLabel: _heightFromRaw(raw['height']),
      city: _clean(raw['city']),
      religion: _clean(raw['religion']),
      sect: _clean(raw['sect']),
      education: _clean(raw['education']),
      profession: _clean(raw['profession']),
      family: _clean(raw['family']),
    );
  }

  static String? _clean(dynamic v) {
    final String s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _heightFromRaw(dynamic v) {
    final String s = (v ?? '').toString().trim();
    if (s.isEmpty || s == 'null') return null;
    final double? h = double.tryParse(s);
    if (h == null || h <= 0) return null;
    final int feet = h.floor();
    final int inches = ((h - feet) * 12).round();
    if (inches > 11) return "${feet + 1}' 0\"";
    return "$feet' $inches\"";
  }
}
