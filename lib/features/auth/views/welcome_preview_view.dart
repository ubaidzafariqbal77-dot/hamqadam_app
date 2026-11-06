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
  List<_PreviewProfile> _profiles = const <_PreviewProfile>[];
  bool _loading = true;
  bool _loadFailed = false;
  int _memberCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  /// Guest feed — no token needed. Any failure keeps the sample cards and
  /// shows a retry chip so a transient network drop doesn't look like the
  /// whole directory is 3 demo people.
  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final ApiClient client = Get.find<ApiClient>();
      // Ask for the whole directory — the backend caps at 200; without this
      // the preview truncated a 47-member pool to the default 6 cards.
      final res = await client.get(
        ApiEndpoints.publicDiscover,
        query: <String, dynamic>{'per_page': 100},
      );
      final List<dynamic> raw =
          (res.dataMap['profiles'] as List<dynamic>?) ?? <dynamic>[];
      // Lookup names (religion/sect/education) resolve client-side from the
      // dropdown reference cache — the guest payload carries ids only.
      final List<_PreviewProfile> fetched = raw
          .map((dynamic e) => _PreviewProfile.fromJson(_withLookupNames(e)))
          .whereType<_PreviewProfile>()
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _profiles = fetched;
        _memberCount = (res.dataMap['total_members'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
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
      map['sect'] =
          map['sect'] ??
          nameOf(LookupKeys.sectMain, map['sect_main_id']) ??
          nameOf(LookupKeys.schoolOfThought, map['school_of_thought_id']);
      map['education'] =
          map['education'] ??
          nameOf(LookupKeys.educationLevels, map['education_level_id']) ??
          nameOf(LookupKeys.degrees, map['degree_id']);
    } catch (_) {
      // Lookups unavailable (very first launch) — the card shows what it has.
    }
    return map;
  }

  Future<void> _openWhatsApp() async {
    final Uri url = Uri.parse(
      'https://wa.me/${WelcomePreviewView._whatsappNumber}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _openEntryDialog(BuildContext context) => EntryDialog.show(context);

  @override
  Widget build(BuildContext context) {
    final double k = _k(context);
    final MediaQueryData mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.1,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                  child: SizedBox(
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
                      padding: EdgeInsets.fromLTRB(
                        14 * k,
                        AppSpacing.lg,
                        14 * k,
                        AppSpacing.sm,
                      ),
                      // Tablets / wide screens: keep a phone-like column
                      // centred instead of stretching cards edge to edge.
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _kMaxContentWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // ---- Brand: logo disc + serif wordmark + swoosh --
                              GestureDetector(
                                onTap: () => _openEntryDialog(context),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Container(
                                      width: 62 * k,
                                      height: 62 * k,
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: AppColors.primaryInk
                                                .withValues(alpha: 0.14),
                                            blurRadius: 16,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Image.asset(
                                        'assets/icons/logo.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.favorite_rounded,
                                          color: AppColors.primaryDark,
                                          size: 32 * k,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10 * k),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              'HamQadam',
                                              style: AppTextStyles.displaySerif
                                                  .copyWith(
                                                    fontSize: 34 * k,
                                                    height: 1.05,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primaryInk,
                                                  ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(left: 2),
                                              child: Icon(
                                                Icons.auto_awesome_rounded,
                                                size: 18 * k,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Swoosh under the wordmark.
                                        SizedBox(
                                          width: 170 * k,
                                          height: 10 * k,
                                          child: CustomPaint(
                                            painter: _SwooshPainter(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 14 * k),

                              // ---- Headline flanked by hairlines ---------------
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Container(
                                      height: 1.4,
                                      margin: EdgeInsets.only(
                                        right: 12,
                                        left: 8,
                                      ),
                                      color: AppColors.primaryInk.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Proposals for you',
                                    style: AppTextStyles.title.copyWith(
                                      fontSize: 25 * k,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: AppColors.primaryInk,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1.4,
                                      margin: EdgeInsets.only(
                                        left: 12,
                                        right: 8,
                                      ),
                                      color: AppColors.primaryInk.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6 * k),
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  _memberCount > 0
                                      ? '$_memberCount curated matches, all verified  ·  Updated today'
                                      : 'Curated matches, all verified  ·  Updated today',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodyStrong.copyWith(
                                    fontSize: 12.5 * k,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryInk.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16 * k),

                              // ---- Search pill + filter square -----------------
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _openEntryDialog(context),
                                      child: Container(
                                        height: 52 * k,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          boxShadow: <BoxShadow>[
                                            BoxShadow(
                                              color: AppColors.primaryInk
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 14,
                                              offset: Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            Icon(
                                              Icons.search_rounded,
                                              color:
                                                  AppColors.lightTextSecondary,
                                              size: 24 * k,
                                            ),
                                            SizedBox(width: 10 * k),
                                            Expanded(
                                              child: Text(
                                                'Search by location, profession...',
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                      fontSize: 14.5 * k,
                                                      color: AppColors
                                                          .lightTextSecondary,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12 * k),
                                  GestureDetector(
                                    onTap: () => _openEntryDialog(context),
                                    child: Container(
                                      width: 52 * k,
                                      height: 52 * k,
                                      decoration: BoxDecoration(
                                        color: Color(0xFFE5728F),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: Color(
                                              0xFFE5728F,
                                            ).withValues(alpha: 0.35),
                                            blurRadius: 12,
                                            offset: Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.tune_rounded,
                                        color: Colors.white,
                                        size: 26 * k,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16 * k),

                              // ---- Retry banner (only when the live feed
                              // ---- failed and demo fallback is showing) --------
                              if (_loadFailed)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.lg,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: _loadFeed,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Could not load live profiles — tap to retry',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryDark,
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),

                              // ---- Match cards (live feed) --------------------
                              if (_loading)
                                ...List<Widget>.filled(
                                  3,
                                  const Padding(
                                    padding: EdgeInsets.only(
                                      bottom: AppSpacing.lg,
                                    ),
                                    child: _SkeletonCard(),
                                  ),
                                )
                              else
                                ..._profiles.map(
                                  (_PreviewProfile p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
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
                                      onPressed: () =>
                                          _openEntryDialog(context),
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
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: const Color(0xFFE5728F),
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: const Color(
                                              0xFFE5728F,
                                            ).withValues(alpha: 0.30),
                                            blurRadius: 14,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _openEntryDialog(context),
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Create Account',
                                          style: AppTextStyles.button.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
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
                    ),
                  ),
                ],
              ),
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
    final double k = _k(context);
    final String heightLabel = profile.heightLabel ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primaryInk.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // ---- Photo with the Verified chip over its top-left ------
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 116 * k,
                      height: 116 * k,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.lightSurfaceAlt,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (profile.photoUrl?.isNotEmpty ?? false)
                          ? Image.network(
                              profile.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person_rounded,
                                color: AppColors.lightTextSecondary,
                                size: 56 * k,
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              color: AppColors.lightTextSecondary,
                              size: 56 * k,
                            ),
                    ),
                    if (profile.verified)
                      Positioned(
                        top: -8,
                        left: -8,
                        child: Container(
                          padding: EdgeInsets.fromLTRB(7, 5, 10, 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.check_circle_rounded,
                                size: 17 * k,
                                color: Color(0xFFE5728F),
                              ),
                              SizedBox(width: 5 * k),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 12.5 * k,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 14 * k),

                // ---- Facts -------------------------------------------------
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        profile.name,
                        style: AppTextStyles.displaySerif.copyWith(
                          fontSize: 20 * k,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6 * k),
                      if (profile.age != null ||
                          heightLabel.isNotEmpty ||
                          profile.religion != null)
                        _PlainFactsLine(
                          parts: <String?>[
                            if (profile.age != null) '${profile.age} Years',
                            if (heightLabel.isNotEmpty) heightLabel,
                            if (profile.religion != null) profile.religion,
                          ],
                        ),
                      SizedBox(height: 7 * k),
                      if (profile.city != null || profile.profession != null)
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.location_on_outlined,
                              size: 16 * k,
                              color: AppColors.lightTextPrimary,
                            ),
                            SizedBox(width: 5 * k),
                            Expanded(
                              child: Text(
                                <String?>[
                                  profile.city,
                                  profile.profession,
                                ].whereType<String>().join(' · '),
                                style: TextStyle(
                                  fontSize: 13 * k,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.lightTextSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: 7 * k),
                      if (profile.education != null)
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.school_outlined,
                              size: 16 * k,
                              color: AppColors.lightTextPrimary,
                            ),
                            SizedBox(width: 5 * k),
                            Expanded(
                              child: Text(
                                profile.education!,
                                style: TextStyle(
                                  fontSize: 13.5 * k,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.lightTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // ---- Heart circle, vertically centred ----------------------
                Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      width: 44 * k,
                      height: 44 * k,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        size: 22 * k,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ---- Bottom: "age · profession" pill + Send Proposal -----------
            SizedBox(height: 14 * k),
            Row(
              children: <Widget>[
                Flexible(
                  flex: 4,
                  child: Container(
                    height: 40 * k,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _badgeText(profile),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13 * k,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryInk,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12 * k),
                Expanded(
                  flex: 6,
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      height: 46 * k,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: AppColors.regPrimaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(
                              alpha: 0.22,
                            ),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.send_rounded,
                              size: 19 * k,
                              color: AppColors.primaryInk,
                            ),
                            SizedBox(width: 8 * k),
                            Text(
                              'Send Proposal',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 16 * k,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "26 · UIUX Designer": age and profession, degrading to what exists.
  String _badgeText(_PreviewProfile p) {
    final String? job = p.profession?.trim();
    final String short = (job != null && job.isNotEmpty)
        ? job
        : (p.verified ? 'Verified' : 'Profile');
    return p.age != null ? '${p.age} · $short' : short;
  }
}

/// The curved underline beneath the HamQadam wordmark.
class _SwooshPainter extends CustomPainter {
  const _SwooshPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.primaryInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final Path path = Path()
      ..moveTo(size.width * 0.04, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.05,
        size.width * 0.96,
        size.height * 0.55,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// One dark-text fact line with quiet "·" separators — the reference's
/// "26 Years · 5'4\" · Islam" row.
class _PlainFactsLine extends StatelessWidget {
  const _PlainFactsLine({required this.parts});

  final List<String?> parts;

  @override
  Widget build(BuildContext context) {
    final double k = _k(context);
    final List<String> clean = parts
        .whereType<String>()
        .where((String s) => s.trim().isNotEmpty)
        .toList();
    if (clean.isEmpty) return SizedBox.shrink();
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            clean.join('  ·  '),
            style: TextStyle(
              fontSize: 14 * k,
              fontWeight: FontWeight.w700,
              color: AppColors.lightTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

/// Widest the content column grows on tablets.
const double _kMaxContentWidth = 560;

/// Scale factor for this screen: 1.0 on a 402-pt wide phone (iPhone 17 Pro),
/// smaller on compact phones, slightly larger on big ones, capped on tablets.
double _k(BuildContext context) {
  final double w = MediaQuery.sizeOf(
    context,
  ).width.clamp(0, _kMaxContentWidth).toDouble();
  return (w / 402).clamp(0.8, 1.15);
}
