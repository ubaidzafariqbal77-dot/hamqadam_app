import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/interest_controller.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/proposal_controller.dart';
import '../../../features/chat/views/chat_conversation_view.dart';
import '../../../models/chat_model.dart';
import '../../../models/lookup_item_model.dart';
import '../../../models/public_profile_model.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../repositories/profile_repository.dart';
import '../../../widgets/state_widgets.dart';
import '../../proposals/widgets/send_proposal_dialog.dart';
import 'send_interest_dialog.dart';
import 'compatibility_section.dart';

/// The member's full profile, as its own premium page.
///
/// This used to be a modal bottom sheet: the drag handle ate the first photo
/// strip, the fixed action bar squeezed the information list, and long profiles
/// felt like reading through a letterbox. The same data now opens as a pushed
/// page with its own rose-gradient header — every fact the API sends is shown
/// dynamically, and nothing about the handlers changed.
///
/// The class name and [show] entry point are kept so every existing call site
/// (discover, interests, proposals, shortlist, profile views, swipe deck)
/// opens the new page without edits.
class PublicProfileDetailSheet extends StatefulWidget {
  const PublicProfileDetailSheet({
    super.key,
    required this.profileId,
    this.initialName,
    this.initialPhoto,
    this.aiMatchPercentage,
  });

  final int profileId;
  final String? initialName;
  final String? initialPhoto;

  /// The AI matchmaking percentage the listing card showed
  /// (`compatibility_percentage` from `GET /search/profiles` / `GET /matches`).
  ///
  /// "Why this match?" must repeat THIS number — the separate
  /// `/profiles/{id}/compatibility` endpoint can return a different, stored or
  /// re-scored value, and a detail page that contradicts the card the member
  /// just tapped reads as a bug. Passed through to [CompatibilitySection].
  final int? aiMatchPercentage;

  /// Opens the detail as a full-screen route.
  static void open(
    BuildContext context, {
    required int profileId,
    String? name,
    String? photo,
    int? aiMatchPercentage,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: false,
        builder: (BuildContext ctx) => PublicProfileDetailSheet(
          profileId: profileId,
          initialName: name,
          initialPhoto: photo,
          aiMatchPercentage: aiMatchPercentage,
        ),
      ),
    );
  }

  /// Kept for every existing caller: now pushes the full-screen page instead
  /// of showing a modal bottom sheet.
  static void show(
    BuildContext context, {
    required int profileId,
    String? name,
    String? photo,
    SearchProfileModel? searchProfile,
    int? aiMatchPercentage,
  }) {
    open(
      context,
      profileId: profileId,
      name: name ?? searchProfile?.displayName,
      photo: photo ?? searchProfile?.photoUrl,
      aiMatchPercentage: aiMatchPercentage ?? searchProfile?.compatibilityPercentage,
    );
  }

  @override
  State<PublicProfileDetailSheet> createState() => _PublicProfileDetailSheetState();
}

class _PublicProfileDetailSheetState extends State<PublicProfileDetailSheet> {
  final ProfileRepository _repo = Get.find<ProfileRepository>();
  final LookupController _lookup = Get.find<LookupController>();
  late Future<PublicProfileModel> _future;

  /// The matchmaking model's verdict on this pair. Loaded alongside the
  /// profile so the page can render without a second round of spinners.
  late Future<CompatibilityModel?> _compatFuture;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    _future = _repo.fetchPublicProfile(widget.profileId);
    // A failed score must never take the profile down with it.
    _compatFuture = _repo
        .fetchCompatibility(widget.profileId)
        .then<CompatibilityModel?>((CompatibilityModel c) => c)
        .catchError((Object _) => null);
  }

  void _startChat(PublicProfileModel profile) async {
    final ChatController chatCtrl = Get.find<ChatController>();
    final ChatThread? thread = await chatCtrl.findExistingThreadWithUser(profile.id);
    if (!mounted) return;

    if (thread != null && thread.id > 0) {
      ChatConversationView.open(thread);
    } else {
      SendInterestDialog.show(
        context,
        SearchProfileModel(
          id: profile.id,
          name: profile.name,
          code: profile.code,
          photo: profile.photo,
          age: profile.age,
          gender: profile.gender,
          cityId: profile.cityId,
          stateId: profile.stateId,
          countryId: profile.countryId,
          identityVerified: profile.identityVerified,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roseCanvas,
      body: FutureBuilder<PublicProfileModel>(
        future: _future,
        builder: (BuildContext ctx, AsyncSnapshot<PublicProfileModel> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.regAccent),
            );
          }

          if (snapshot.hasError) {
            return ErrorStateWidget(
              message: 'Failed to load profile details.',
              onRetry: () => setState(_fetch),
            );
          }

          final PublicProfileModel profile = snapshot.data!;
          return _buildContent(context, profile);
        },
      ),
    );
  }

  String? _lookupName(String key, int? id) {
    if (id == null) return null;
    final List<LookupItem> items = _lookup.itemsOf(key);
    for (final LookupItem item in items) {
      if (item.id == id) return item.name;
    }
    return null;
  }

  Widget _buildContent(BuildContext context, PublicProfileModel profile) {
    // Resolve labels
    final String? religion = _lookupName(LookupKeys.religions, profile.religionId);
    final String? caste = _lookupName(LookupKeys.castes, profile.casteId);
    final String? marital = _lookupName(LookupKeys.maritalStatuses, profile.maritalStatusId);
    final String? city = _lookupName(LookupKeys.cities, profile.cityId);
    final String? state = _lookupName(LookupKeys.states, profile.stateId);
    final String? country = _lookupName(LookupKeys.countries, profile.countryId);

    final String location = <String>[
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
      if (country != null && country.isNotEmpty) country,
    ].join(', ');

    return Column(
      children: <Widget>[
        Expanded(
          child: RefreshIndicator(
            color: AppColors.regAccent,
            onRefresh: () async => setState(_fetch),
            child: CustomScrollView(
              slivers: <Widget>[
                // ── Premium photo header ──────────────────────────────────
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: AppColors.regAccent,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _PhotoHeader(profile: profile),
                  ),
                ),

                // ── Body ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // White identity card: name, ID, verified, quick chips
                        _IdentityCard(
                          profile: profile,
                          marital: marital,
                          aiMatchPercentage: widget.aiMatchPercentage,
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Why this score — the AI listing percentage leads;
                        // the endpoint only explains it.
                        CompatibilitySection(
                          future: _compatFuture,
                          overridePercentage: widget.aiMatchPercentage,
                        ),

                        // Package viewer meta info (if available)
                        if (profile.meta != null &&
                            profile.meta!.packageValidity != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.roseFieldBorder),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: const Color(0xFFB4487B).withValues(alpha: 0.10),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.regAccent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.card_membership_rounded,
                                    color: AppColors.regAccent,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Package validity: ${profile.meta!.packageValidity}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.chatPreviewInk,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.lg),
                        _SectionHeading('Profile Information'),
                        const SizedBox(height: AppSpacing.sm),

                        // White facts card: every row the API actually sent.
                        _FactsCard(
                          rows: <_FactRow>[
                            if (religion != null)
                              _FactRow(Icons.mosque_outlined, 'Religion', religion),
                            if (caste != null)
                              _FactRow(Icons.people_outline_rounded, 'Caste / Community', caste),
                            if (marital != null)
                              _FactRow(Icons.favorite_border_rounded, 'Marital Status', marital),
                            if (location.isNotEmpty)
                              _FactRow(Icons.location_on_outlined, 'Location', location),
                            if (profile.gender == '1' || profile.gender == '2')
                              _FactRow(
                                Icons.person_outline_rounded,
                                'Gender',
                                profile.gender == '1' ? 'Male' : 'Female',
                              ),
                            if (profile.height != null && profile.height!.trim().isNotEmpty)
                              _FactRow(Icons.height_rounded, 'Height', '${profile.height} ft'),
                            if (profile.createdAt != null)
                              _FactRow(
                                Icons.calendar_today_outlined,
                                'Member Since',
                                DateFormat('MMMM yyyy').format(profile.createdAt!),
                              ),
                            if (profile.lastActiveAt != null)
                              _FactRow(
                                Icons.access_time_rounded,
                                'Last Active',
                                DateFormat('MMM d, yyyy').format(profile.lastActiveAt!),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Bottom Action Bar: Send Proposal, Chat, Express Interest ──────
        _ActionBar(
          profile: profile,
          onProposal: () => SendProposalDialog.show(context, _searchModel(profile)),
          onChat: () => _startChat(profile),
          onInterest: () => SendInterestDialog.show(context, _searchModel(profile)),
        ),
      ],
    );
  }

  SearchProfileModel _searchModel(PublicProfileModel profile) => SearchProfileModel(
        id: profile.id,
        name: profile.name,
        code: profile.code,
        photo: profile.photo,
        age: profile.age,
        gender: profile.gender,
        maritalStatusId: profile.maritalStatusId,
        religionId: profile.religionId,
        casteId: profile.casteId,
        cityId: profile.cityId,
        stateId: profile.stateId,
        countryId: profile.countryId,
        identityVerified: profile.identityVerified,
      );
}

// ---------------------------------------------------------------------------
// Photo header — full-bleed photo, bottom gradient, back + name + ID overlay.
// ---------------------------------------------------------------------------

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.profile});

  final PublicProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final String name = profile.displayName;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        profile.photoUrl != null
            ? Image.network(
                profile.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
                loadingBuilder: (BuildContext ctx, Widget child, ImageChunkEvent? p) {
                  if (p == null) return child;
                  return _fallback();
                },
              )
            : _fallback(),

        // Readability gradient: soft at top (status bar), strong at bottom.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: <double>[0.0, 0.35, 0.65, 1.0],
              colors: <Color>[
                Colors.black38,
                Colors.transparent,
                Colors.transparent,
                Color(0xE6240A14),
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),

        // Name + ID pinned to the bottom of the header.
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      name,
                      style: AppTextStyles.headline.copyWith(
                        color: Colors.white,
                        fontSize: 26,
                        shadows: <Shadow>[
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (profile.identityVerified) ...<Widget>[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                  ],
                ],
              ),
              if (profile.code != null && profile.code!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  'ID: ${profile.code}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.regPrimaryGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            profile.initial,
            style: const TextStyle(
              fontSize: 84,
              fontWeight: FontWeight.w900,
              color: Colors.white38,
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// White identity card — name row + age/height/marital/verified chips.
// ---------------------------------------------------------------------------

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.profile,
    required this.marital,
    this.aiMatchPercentage,
  });

  final PublicProfileModel profile;
  final String? marital;

  /// The AI listing score the card showed — repeated here so the identity
  /// chip and "Why this match?" agree with what the member tapped from.
  final int? aiMatchPercentage;

  @override
  Widget build(BuildContext context) {
    final int? matchChip = aiMatchPercentage ?? profile.compatibilityPercentage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.roseFieldBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFB4487B).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.regAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Member Profile',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 12.5,
                    letterSpacing: 1.1,
                    color: AppColors.chatTimeInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // The SAME AI percentage the listing card showed — the public
              // profile endpoint's own stored value can differ, and two
              // different numbers on one page read as a bug.
              if (matchChip != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.regAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.regAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.favorite_rounded, size: 12, color: AppColors.regAccent),
                      const SizedBox(width: 4),
                      Text(
                        '$matchChip% match',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.chatPillInk,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (profile.age != null)
                _infoChip(Icons.cake_outlined, '${profile.age} yrs'),
              if (profile.height != null && profile.height!.trim().isNotEmpty)
                _infoChip(Icons.height_rounded, '${profile.height} ft'),
              if (marital != null)
                _infoChip(Icons.wc_rounded, marital!),
              if (profile.identityVerified)
                _infoChip(Icons.verified_user_rounded, 'Verified', color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section heading
// ---------------------------------------------------------------------------

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.title.copyWith(
        fontSize: 19,
        color: AppColors.roseTitleInk,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Facts card — icon rows on one white card, dividers between.
// ---------------------------------------------------------------------------

class _FactRow {
  const _FactRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.rows});

  final List<_FactRow> rows;

  @override
  Widget build(BuildContext context) {
    final List<_FactRow> visible =
        rows.where((_FactRow r) => r.value.trim().isNotEmpty && r.value.trim() != '—').toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.roseFieldBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFB4487B).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < visible.length; i++) ...<Widget>[
            _row(visible[i]),
            if (i != visible.length - 1)
              const Divider(height: 1, color: AppColors.roseFieldBorder),
          ],
        ],
      ),
    );
  }

  Widget _row(_FactRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.regAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(r.icon, size: 18, color: AppColors.regAccent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  r.label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: AppColors.chatTimeInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  r.value,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 14.5,
                    color: AppColors.roseTitleInk,
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

// ---------------------------------------------------------------------------
// Bottom action bar — Proposal on the rose gradient, Chat / Interest pills.
// ---------------------------------------------------------------------------

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.profile,
    required this.onProposal,
    required this.onChat,
    required this.onInterest,
  });

  final PublicProfileModel profile;
  final VoidCallback onProposal;
  final VoidCallback onChat;
  final VoidCallback onInterest;

  @override
  Widget build(BuildContext context) {
    final InterestController? interestCtrl =
        Get.isRegistered<InterestController>() ? Get.find<InterestController>() : null;
    final ProposalController? proposalCtrl =
        Get.isRegistered<ProposalController>() ? Get.find<ProposalController>() : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.roseFieldBorder)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 1. Send Marriage Proposal Button
            Obx(() {
              final bool alreadyProposed =
                  proposalCtrl?.hasSentProposalTo(profile.id) == true;
              if (alreadyProposed) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Already Sent',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return GestureDetector(
                onTap: onProposal,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: AppColors.regPrimaryGradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.regAccent.withValues(alpha: 0.38),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                        spreadRadius: -3,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.mail_outline_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Send Proposal',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: AppSpacing.xs),

            // 2. Chat & Express Interest Buttons
            Row(
              children: <Widget>[
                // Chat Button — white pill, rose hairline
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 17, color: AppColors.regAccent),
                    label: const Text(
                      'Chat',
                      style: TextStyle(
                        color: AppColors.regAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(color: AppColors.roseFieldBorder, width: 1.4),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onChat,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Express Interest Button
                Expanded(
                  child: Obx(() {
                    final bool alreadySent =
                        interestCtrl?.hasSentInterestTo(profile.id) == true;
                    if (alreadySent) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.favorite_rounded, color: AppColors.gold, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Interest Sent',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return OutlinedButton.icon(
                      icon: const Icon(Icons.favorite_rounded, size: 16, color: AppColors.gold),
                      label: const Text(
                        'Interest',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5), width: 1.4),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: onInterest,
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rose info chip
// ---------------------------------------------------------------------------

Widget _infoChip(IconData icon, String text, {Color? color}) {
  final Color c = color ?? AppColors.regAccent;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: c.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: c,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
