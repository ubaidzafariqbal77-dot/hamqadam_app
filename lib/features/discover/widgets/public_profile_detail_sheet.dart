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



/// Bottom modal sheet displaying complete details of a selected member profile
/// loaded dynamically from `GET /api/v1/profiles/{id}`.
class PublicProfileDetailSheet extends StatefulWidget {
  const PublicProfileDetailSheet({
    super.key,
    required this.profileId,
    this.initialName,
    this.initialPhoto,
  });

  final int profileId;
  final String? initialName;
  final String? initialPhoto;

  static void show(
    BuildContext context, {
    required int profileId,
    String? name,
    String? photo,
    SearchProfileModel? searchProfile,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => PublicProfileDetailSheet(
        profileId: profileId,
        initialName: name ?? searchProfile?.displayName,
        initialPhoto: photo ?? searchProfile?.photoUrl,
      ),
    );
  }

  @override
  State<PublicProfileDetailSheet> createState() => _PublicProfileDetailSheetState();
}

class _PublicProfileDetailSheetState extends State<PublicProfileDetailSheet> {
  final ProfileRepository _repo = Get.find<ProfileRepository>();
  final LookupController _lookup = Get.find<LookupController>();
  late Future<PublicProfileModel> _future;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    _future = _repo.fetchPublicProfile(widget.profileId);
  }

  void _startChat(PublicProfileModel profile) async {
    final ChatController chatCtrl = Get.find<ChatController>();
    final ChatThread? thread = await chatCtrl.findExistingThreadWithUser(profile.id);
    if (!mounted) return;

    if (thread != null && thread.id > 0) {
      Navigator.of(context).pop();
      ChatConversationView.open(thread);
    } else {
      Navigator.of(context).pop();
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final InterestController? interestCtrl = Get.isRegistered<InterestController>()
        ? Get.find<InterestController>()
        : null;
    final ProposalController? proposalCtrl = Get.isRegistered<ProposalController>()
        ? Get.find<ProposalController>()
        : null;


    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.hintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),

            Expanded(
              child: FutureBuilder<PublicProfileModel>(
                future: _future,
                builder: (BuildContext ctx, AsyncSnapshot<PublicProfileModel> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (snapshot.hasError) {
                    return ErrorStateWidget(
                      message: 'Failed to load profile details.',
                      onRetry: () => setState(_fetch),
                    );
                  }

                  final PublicProfileModel profile = snapshot.data!;
                  return _buildContent(context, profile, isDark, interestCtrl, proposalCtrl);
                },
              ),
            ),
          ],
        ),
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

  Widget _buildContent(
    BuildContext context,
    PublicProfileModel profile,
    bool isDark,
    InterestController? interestCtrl,
    ProposalController? proposalCtrl,
  ) {

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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header Image Banner
                Stack(
                  children: <Widget>[
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.brandGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: profile.photoUrl != null
                          ? Image.network(
                              profile.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(),
                            )
                          : Center(
                              child: Text(
                                profile.initial,
                                style: const TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                    ),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Header Details Overlaid
                    Positioned(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      bottom: AppSpacing.md,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  profile.displayName,
                                  style: AppTextStyles.headline.copyWith(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile.identityVerified) ...<Widget>[
                                const SizedBox(width: 8),
                                const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                              ],
                            ],
                          ),
                          if (profile.code != null && profile.code!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${profile.code}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Quick Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (profile.age != null)
                            _infoChip(Icons.cake_outlined, '${profile.age} yrs'),
                          if (profile.height != null && profile.height!.isNotEmpty)
                            _infoChip(Icons.height_rounded, '${profile.height} ft'),
                          if (marital != null)
                            _infoChip(Icons.wc_rounded, marital),
                          if (profile.compatibilityPercentage != null)
                            _infoChip(
                              Icons.auto_awesome_rounded,
                              '${profile.compatibilityPercentage}% Match',
                              color: AppColors.gold,
                            ),
                          if (profile.identityVerified)
                            _infoChip(
                              Icons.verified_user_rounded,
                              'Verified Profile',
                              color: AppColors.success,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Package viewer meta info (if available)
                      if (profile.meta != null && profile.meta!.packageValidity != null) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.card_membership_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Package validity: ${profile.meta!.packageValidity}',
                                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      Text('Profile Information', style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.xs),
                      const Divider(height: 1, color: AppColors.lightDivider),
                      const SizedBox(height: AppSpacing.xs),

                      // Details List
                      _detailTile('Religion', religion ?? '—', Icons.mosque_outlined),
                      _detailTile('Caste / Community', caste ?? '—', Icons.people_outline_rounded),
                      _detailTile('Marital Status', marital ?? '—', Icons.favorite_border_rounded),
                      _detailTile('Location', location.isNotEmpty ? location : '—', Icons.location_on_outlined),
                      _detailTile('Gender', profile.gender == '1' ? 'Male' : (profile.gender == '2' ? 'Female' : '—'), Icons.person_outline_rounded),
                      if (profile.createdAt != null)
                        _detailTile('Member Since', DateFormat('MMMM yyyy').format(profile.createdAt!), Icons.calendar_today_outlined),
                      if (profile.lastActiveAt != null)
                        _detailTile('Last Active', DateFormat('MMM d, yyyy').format(profile.lastActiveAt!), Icons.access_time_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Action Bar: Send Proposal, Chat, and Express Interest
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBackground,
            border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightDivider)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 1. Send Marriage Proposal Button
              Obx(() {
                final bool alreadyProposed = proposalCtrl?.hasSentProposalTo(profile.id) == true;
                if (alreadyProposed) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
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

                return SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.mail_outline_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Send Proposal',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    onPressed: () {
                      final SearchProfileModel searchModel = SearchProfileModel(
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
                      SendProposalDialog.show(context, searchModel);
                    },
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.xs),

              // 2. Chat & Express Interest Buttons
              Row(
                children: <Widget>[
                  // Chat Button
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17, color: AppColors.primary),
                      label: const Text('Chat', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      ),
                      onPressed: () => _startChat(profile),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Express Interest Button
                  Expanded(
                    child: Obx(() {
                      final bool alreadySent = interestCtrl?.hasSentInterestTo(profile.id) == true;
                      if (alreadySent) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.favorite_rounded, color: AppColors.gold, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Interest Sent',
                                style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ],
                          ),
                        );
                      }
                      return OutlinedButton.icon(
                        icon: const Icon(Icons.favorite_rounded, size: 16, color: AppColors.gold),
                        label: const Text('Interest', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          side: const BorderSide(color: AppColors.gold, width: 1.5),
                          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                        ),
                        onPressed: () {
                          final SearchProfileModel searchModel = SearchProfileModel(
                            id: profile.id,
                            name: profile.name,
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
                          SendInterestDialog.show(context, searchModel);
                        },
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _infoChip(IconData icon, String text, {Color? color}) {
    final Color c = color ?? AppColors.primary;
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value, IconData icon, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.lightTextHint)),
                Text(value, style: AppTextStyles.bodyStrong),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
