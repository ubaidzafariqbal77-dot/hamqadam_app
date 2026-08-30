import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/proposal_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/chat_model.dart';
import '../../../models/proposal_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../../../widgets/surface_card.dart';
import '../../chat/views/chat_conversation_view.dart';
import '../../discover/widgets/public_profile_detail_sheet.dart';

/// Full screen displaying member's received and sent marriage proposals.
class ProposalsView extends StatefulWidget {
  const ProposalsView({super.key});

  @override
  State<ProposalsView> createState() => _ProposalsViewState();
}

class _ProposalsViewState extends State<ProposalsView> with SingleTickerProviderStateMixin {
  late final ProposalController _controller;
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ProposalController>();
    _tabController = TabController(length: 2, vsync: this);
    _controller.loadProposals();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Proposals / Rishtay',
        subtitle: 'Formal marriage connections',
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.loadProposals(),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Material(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: theme.hintColor,
              labelStyle: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
              tabs: <Widget>[
                Obx(() {
                  final int count = _controller.receivedProposals.length;
                  return Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.inbox_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Received ($count)'),
                      ],
                    ),
                  );
                }),
                Obx(() {
                  final int count = _controller.sentProposals.length;
                  return Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.outbox_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Sent ($count)'),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              final ApiState<ProposalPage> s = _controller.state.value;

              switch (s.status) {
                case ApiStatus.initial:
                case ApiStatus.loading:
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                case ApiStatus.noInternet:
                  return NoInternetWidget(onRetry: () => _controller.loadProposals());
                case ApiStatus.unauthorized:
                case ApiStatus.serverError:
                case ApiStatus.validationError:
                  return ErrorStateWidget(
                    message: s.message,
                    onRetry: () => _controller.loadProposals(),
                  );
                case ApiStatus.empty:
                case ApiStatus.success:
                  return TabBarView(
                    controller: _tabController,
                    children: <Widget>[
                      _ProposalList(
                        proposals: _controller.receivedProposals,
                        isReceived: true,
                        onRefresh: () => _controller.loadProposals(silent: true),
                      ),
                      _ProposalList(
                        proposals: _controller.sentProposals,
                        isReceived: false,
                        onRefresh: () => _controller.loadProposals(silent: true),
                      ),
                    ],
                  );
              }
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proposal List
// ---------------------------------------------------------------------------
class _ProposalList extends StatelessWidget {
  const _ProposalList({
    required this.proposals,
    required this.isReceived,
    required this.onRefresh,
  });

  final List<ProposalModel> proposals;
  final bool isReceived;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (proposals.isEmpty) {
      return EmptyStateWidget(
        title: isReceived ? 'No received proposals' : 'No sent proposals',
        message: isReceived
            ? 'When other members send you a marriage proposal, they will appear here.'
            : 'You have not sent any marriage proposals yet. Browse profiles and tap "Send Proposal" to connect.',
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: proposals.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          final ProposalModel item = proposals[index];
          return _ProposalCard(
            proposal: item,
            isReceived: isReceived,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proposal Card
// ---------------------------------------------------------------------------
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.isReceived,
  });

  final ProposalModel proposal;
  final bool isReceived;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProposalController controller = Get.find<ProposalController>();
    final ProposalMember? member = isReceived ? proposal.sender : proposal.recipient;
    final DateFormat dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Avatar, Name, Status
          InkWell(
            onTap: () {
              if (member != null && member.id > 0) {
                PublicProfileDetailSheet.show(
                  context,
                  profileId: member.id,
                  name: member.displayName,
                  photo: member.photo,
                );
              }
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Row(
              children: <Widget>[
                // Photo / Avatar
                Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: (member?.hasPhoto ?? false)
                            ? Image.network(
                                member!.photo!,
                                fit: BoxFit.cover,
                                errorBuilder: (BuildContext ctx, Object err, StackTrace? stack) =>
                                    _fallbackAvatar(member.initial),
                              )
                            : _fallbackAvatar(member?.initial ?? 'H'),
                      ),
                    ),
                    if (member?.approved ?? false)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),

                // Name & Code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        member?.displayName ?? 'HamQadam Member',
                        style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (member?.code != null && member!.code!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${member.code}',
                          style: TextStyle(fontSize: 11, color: theme.hintColor),
                        ),
                      ],
                      if (proposal.createdAt != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(proposal.createdAt!),
                          style: TextStyle(fontSize: 10.5, color: theme.hintColor),
                        ),
                      ],
                    ],
                  ),
                ),

                // Status Pill
                StatusPill(
                  label: proposal.statusLabel,
                  color: _statusColor(proposal),
                ),
              ],
            ),
          ),

          // Initial note if provided
          if (proposal.initialNote != null && proposal.initialNote!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.format_quote_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      proposal.initialNote!,
                      style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),

          // Action Buttons according to proposal state
          Obx(() {
            final bool busy = controller.isBusy(proposal.id);

            // 1. Received & Pending -> Accept / Reject buttons
            if (isReceived && proposal.isPending) {
              return Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                      label: const Text('Decline', style: TextStyle(color: AppColors.error, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      ),
                      onPressed: busy ? null : () => _confirmDecline(context, controller),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      icon: busy
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                      label: const Text('Accept Proposal', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      ),
                      onPressed: busy ? null : () => controller.acceptProposal(proposal.id),
                    ),
                  ),
                ],
              );
            }

            // 2. Sent & Pending -> Withdraw / Cancel button
            if (!isReceived && proposal.isPending) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Awaiting response from member',
                    style: TextStyle(fontSize: 11.5, color: theme.hintColor, fontStyle: FontStyle.italic),
                  ),
                  OutlinedButton.icon(
                    icon: busy
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.undo_rounded, size: 14, color: AppColors.error),
                    label: const Text('Withdraw', style: TextStyle(color: AppColors.error, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                    onPressed: busy ? null : () => _confirmWithdraw(context, controller),
                  ),
                ],
              );
            }

            // 3. Accepted -> Chat & View Profile buttons
            if (proposal.isAccepted) {
              return Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.primary),
                      label: const Text('Profile', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      ),
                      onPressed: () {
                        if (member != null && member.id > 0) {
                          PublicProfileDetailSheet.show(
                            context,
                            profileId: member.id,
                            name: member.displayName,
                            photo: member.photo,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                      label: const Text('Chat', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      ),
                      onPressed: () => _handleChat(context, member),
                    ),
                  ),
                ],
              );
            }

            // 4. Other states (Rejected, Withdrawn, Cancelled)
            return Text(
              'Proposal is ${proposal.statusLabel.toLowerCase()}',
              style: TextStyle(fontSize: 11.5, color: theme.hintColor, fontStyle: FontStyle.italic),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _confirmDecline(BuildContext context, ProposalController controller) async {
    final TextEditingController noteCtrl = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Decline Proposal?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Are you sure you want to decline this proposal?'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                hintText: 'Reason / note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final String note = noteCtrl.text.trim();
      await controller.rejectProposal(proposal.id, note: note.isNotEmpty ? note : null);
    }
  }

  Future<void> _confirmWithdraw(BuildContext context, ProposalController controller) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Withdraw Proposal?'),
        content: const Text('Are you sure you want to withdraw this marriage proposal?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await controller.withdrawProposal(proposal.id);
    }
  }

  Future<void> _handleChat(BuildContext context, ProposalMember? member) async {
    if (member == null || member.id <= 0) return;
    final ChatController chatCtrl = Get.find<ChatController>();
    final ChatThread? thread = await chatCtrl.findExistingThreadWithUser(member.id);
    if (!context.mounted) return;
    if (thread != null && thread.id > 0) {
      ChatConversationView.open(thread);
    } else {
      PublicProfileDetailSheet.show(
        context,
        profileId: member.id,
        name: member.displayName,
        photo: member.photo,
      );
    }
  }

  Color _statusColor(ProposalModel p) {
    switch (p.parsedStatus) {
      case ProposalStatus.pending:
        return Colors.amber.shade800;
      case ProposalStatus.accepted:
        return AppColors.success;
      case ProposalStatus.rejected:
      case ProposalStatus.cancelled:
        return AppColors.error;
      case ProposalStatus.withdrawn:
        return Colors.grey;
      case ProposalStatus.unknown:
        return Colors.grey;
    }
  }

  Widget _fallbackAvatar(String initial) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          initial,
          style: AppTextStyles.subtitle.copyWith(color: AppColors.primary, fontSize: 20),
        ),
      ),
    );
  }
}
