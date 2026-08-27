import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_lookups.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/lookup_controller.dart';
import '../../../controllers/shortlist_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/chat_model.dart';
import '../../../models/lookup_item_model.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../models/shortlist_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../../../widgets/surface_card.dart';
import '../../chat/views/chat_conversation_view.dart';
import '../../discover/widgets/public_profile_detail_sheet.dart';
import '../../discover/widgets/send_interest_dialog.dart';

/// Full screen displaying member profiles shortlisted by the current user.
class ShortlistView extends StatefulWidget {
  const ShortlistView({super.key});

  @override
  State<ShortlistView> createState() => _ShortlistViewState();
}

class _ShortlistViewState extends State<ShortlistView> {
  late final ShortlistController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ShortlistController>();
    _controller.loadShortlists();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Shortlisted Profiles',
        subtitle: 'Saved member proposals',
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.loadShortlists(),
          ),
        ],
      ),
      body: Obx(() {
        final ApiState<ShortlistPage> s = _controller.state.value;

        switch (s.status) {
          case ApiStatus.initial:
          case ApiStatus.loading:
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          case ApiStatus.noInternet:
            return NoInternetWidget(onRetry: () => _controller.loadShortlists());
          case ApiStatus.unauthorized:
          case ApiStatus.serverError:
          case ApiStatus.validationError:
            return ErrorStateWidget(
              message: s.message,
              onRetry: () => _controller.loadShortlists(),
            );
          case ApiStatus.empty:
            return EmptyStateWidget(
              title: 'No shortlisted profiles',
              message: s.message?.isNotEmpty == true
                  ? s.message!
                  : 'You have not shortlisted any profiles yet. Browse matches and tap the bookmark icon to save them here.',
              onRefresh: () => _controller.loadShortlists(),
            );
          case ApiStatus.success:
            final List<SearchProfileModel> list = _controller.profiles;
            if (list.isEmpty) {
              return EmptyStateWidget(
                title: 'No shortlisted profiles',
                message: 'You have not shortlisted any profiles yet.',
                onRefresh: () => _controller.loadShortlists(),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _controller.loadShortlists(silent: true),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: list.length + (_controller.isLoadingMore.value ? 1 : 0),
                separatorBuilder: (BuildContext context, int index) => const SizedBox(height: AppSpacing.sm),

                itemBuilder: (BuildContext context, int index) {
                  if (index >= list.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }

                  final SearchProfileModel profile = list[index];
                  return _ShortlistCard(
                    profile: profile,
                    onRemove: () => _confirmRemove(context, profile),
                    onChat: () => _handleChat(context, profile),
                    onInterest: () => SendInterestDialog.show(context, profile),
                    onTap: () => PublicProfileDetailSheet.show(
                      context,
                      profileId: profile.id,
                      name: profile.displayName,
                      photo: profile.photoUrl,
                    ),
                  );
                },
              ),
            );
        }
      }),
    );
  }

  Future<void> _confirmRemove(BuildContext context, SearchProfileModel profile) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Remove from Shortlist?'),
        content: Text('Are you sure you want to remove ${profile.displayName} from your shortlisted profiles?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _controller.removeProfile(profile.id, displayName: profile.displayName);
    }
  }

  Future<void> _handleChat(BuildContext context, SearchProfileModel profile) async {
    final ChatController chatCtrl = Get.find<ChatController>();
    final ChatThread? thread = await chatCtrl.findExistingThreadWithUser(profile.id);
    if (thread != null && thread.id > 0) {
      ChatConversationView.open(thread);
    } else if (context.mounted) {
      SendInterestDialog.show(context, profile);
    }
  }
}

class _ShortlistCard extends StatelessWidget {
  const _ShortlistCard({
    required this.profile,
    required this.onRemove,
    required this.onChat,
    required this.onInterest,
    required this.onTap,
  });

  final SearchProfileModel profile;
  final VoidCallback onRemove;
  final VoidCallback onChat;
  final VoidCallback onInterest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LookupController lookups = Get.find<LookupController>();

    String? lookupName(String key, int? id) {
      if (id == null) return null;
      for (final LookupItem item in lookups.itemsOf(key)) {
        if (item.id == id) return item.name;
      }
      return null;
    }

    final String? religionName = lookupName(LookupKeys.religions, profile.religionId);
    final String? casteName = lookupName(LookupKeys.castes, profile.casteId);
    final String? cityName = lookupName(LookupKeys.cities, profile.cityId);

    final List<String> details = <String>[
      if (profile.ageLabel.isNotEmpty) profile.ageLabel,
      ?profile.heightFormatted,
      ?religionName,
      ?casteName,
      ?cityName,
    ];



    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Photo / Avatar
                Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: profile.hasPhoto
                            ? Image.network(
                                profile.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (BuildContext ctx, Object err, StackTrace? stack) =>
                                    _fallbackAvatar(),
                              )
                            : _fallbackAvatar(),
                      ),
                    ),
                    if (profile.isVerified)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),

                // Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              profile.displayName,
                              style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.bookmark_rounded, size: 11, color: AppColors.gold),
                                SizedBox(width: 2),
                                Text(
                                  'Shortlisted',

                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (profile.code != null && profile.code!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${profile.code}',
                          style: TextStyle(fontSize: 11, color: theme.hintColor),
                        ),
                      ],
                      const SizedBox(height: 4),
                      if (details.isNotEmpty)
                        Text(
                          details.join('  •  '),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (profile.compatibilityPercentage != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${profile.compatibilityPercentage}% Match',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Remove bookmark button
                IconButton(
                  tooltip: 'Remove from Shortlist',
                  icon: const Icon(Icons.bookmark_remove_rounded, color: AppColors.error, size: 22),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),

          // Action Buttons: Send Interest & Chat
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.favorite_outline_rounded, size: 16, color: AppColors.primary),
                  label: const Text('Send Interest', style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                  onPressed: onInterest,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                  label: const Text('Chat', style: TextStyle(fontSize: 12.5, color: Colors.white)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                  onPressed: onChat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          profile.initial,
          style: AppTextStyles.subtitle.copyWith(color: AppColors.primary, fontSize: 24),
        ),
      ),
    );
  }
}
