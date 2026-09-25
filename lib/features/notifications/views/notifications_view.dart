import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/notification_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../features/gifts/views/gift_detail_view.dart';
import '../../../features/chat/views/chat_conversation_view.dart';
import '../../../features/chat/views/chat_inbox_view.dart';
import '../../../features/interests/views/interests_view.dart';
import '../../../features/payments/views/coin_usage_view.dart';
import '../../../features/payments/views/membership_plans_view.dart';
import '../../../features/profile_views/views/profile_views_view.dart';
import '../../../features/proposals/views/proposals_view.dart';
import '../../../models/chat_model.dart';
import '../../../models/notification_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final NotificationController _controller = Get.find<NotificationController>();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.fetchNotifications(refresh: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.fetchNotifications();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── icon ──────────────────────────────────────────────────────────────────
  Widget _buildIcon(NotificationModel notif) {
    final String lower = notif.type.toLowerCase();

    IconData iconData = Icons.notifications_rounded;
    Color color = AppColors.regAccent;

    if (notif.isChatMessage) {
      iconData = Icons.chat_bubble_rounded;
      color = AppColors.fieldIconGlyph;
    } else if (lower.contains('interest')) {
      iconData = Icons.favorite_rounded;
      color = AppColors.regAccent;
    } else if (lower.contains('proposal')) {
      iconData = Icons.mail_rounded;
      color = AppColors.success;
    } else if (lower.contains('shortlist')) {
      iconData = Icons.bookmark_rounded;
      color = AppColors.regAccent;
    } else if (lower.contains('view')) {
      iconData = Icons.visibility_rounded;
      color = AppColors.fieldIconGlyph;
    } else if (lower.contains('coin') || lower.contains('bonus') || lower.contains('credit')) {
      iconData = Icons.monetization_on_rounded;
      color = AppColors.warning;
    } else if (lower.contains('payment') || lower.contains('package') || lower.contains('plan')) {
      iconData = Icons.workspace_premium_rounded;
      color = AppColors.regAccent;
    } else if (lower.contains('call')) {
      iconData = Icons.phone_missed_rounded;
      color = AppColors.error;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: notif.isChatMessage
            ? AppColors.fieldIconDisc
            : color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 21),
    );
  }

  // ── navigation on tap ─────────────────────────────────────────────────────
  void _handleNotificationTap(NotificationModel notif) {
    // One tap = the notification is read on the server, whatever it is.
    _controller.markAsRead(notif.id, silent: true);

    final String type = notif.type.toLowerCase();

    // 0. Gift notifications → the gift's detail screen.
    if (type.contains('gift')) {
      final int? txnId = notif.infoId;
      if (txnId != null && txnId > 0) {
        Get.to<void>(() => GiftDetailView(transactionId: txnId));
      } else {
        Get.toNamed<void>(AppRoutes.myGifts);
      }
      return;
    }

    // 1. Chat messages — routed into the conversation thread.
    if (notif.isChatMessage) {
      _openChatFromNotif(notif);
      return;
    }

    // 2. Proposals
    if (type.contains('proposal')) {
      Get.to(() => const ProposalsView());
      return;
    }

    // 3. Interests
    if (type.contains('interest')) {
      Get.to(() => const InterestsView());
      return;
    }

    // 4. Profile Views
    if (type.contains('profile_view') || type.contains('view_profile') || type.contains('view')) {
      Get.to(() => const ProfileViewsView());
      return;
    }

    // 5. Coins / Free Coins Bonus
    if (type.contains('coin') || type.contains('bonus') || type.contains('credit')) {
      Get.to(() => const CoinUsageView());
      return;
    }

    // 6. Payments / Packages
    if (type.contains('payment') || type.contains('package') || type.contains('plan') || type.contains('subscription')) {
      Get.to(() => const MembershipPlansView());
      return;
    }
  }

  /// Chat notifications carry the thread id in [NotificationModel.infoId] and
  /// the sender's user id in [NotificationModel.notifyBy]. Match either against
  /// the already-loaded threads; failing that, land on the inbox.
  void _openChatFromNotif(NotificationModel notif) {
    if (Get.isRegistered<ChatController>()) {
      final ChatController chatCtrl = Get.find<ChatController>();
      final List<ChatThread> threads = chatCtrl.threadsState.value.data ?? <ChatThread>[];

      ChatThread? thread;
      final int? infoId = notif.infoId;
      final int? notifyBy = notif.notifyBy;

      if (infoId != null) {
        thread = threads.cast<ChatThread?>().firstWhere(
          (t) => t?.id == infoId,
          orElse: () => null,
        );
      }
      if (thread == null && notifyBy != null) {
        thread = threads.cast<ChatThread?>().firstWhere(
          (t) => t?.participant.id == notifyBy,
          orElse: () => null,
        );
      }

      if (thread != null) {
        ChatConversationView.open(thread);
        return;
      }
    }

    Get.to(() => const ChatInboxView());
  }

  // ── date formatter ────────────────────────────────────────────────────────
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 6) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
    if (diff.inHours > 0) return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return diff.inMinutes == 1 ? '1 minute ago' : '${diff.inMinutes} minutes ago';
    return 'Just now';
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.roseCanvas,
      appBar: PremiumAppBar(
        title: 'Notifications',
        subtitle: 'Updates about your activity',
        actions: <Widget>[
          // Always available: on the Unread tab it is the whole point of the
          // screen, and on All it still clears older rows a refresh will show.
          Obx(() {
            final bool busy = _controller.isLoading.value;
            return TextButton(
              onPressed: busy ? null : _controller.markAllAsRead,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Mark all read'),
            );
          }),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildTabs(context),
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value && _controller.notifications.isEmpty) {
                return _buildSkeleton(context);
              }

              if (!_controller.isLoading.value && _controller.notifications.isEmpty) {
                return _controller.showUnreadOnly.value
                    ? const EmptyStateWidget(
                        title: 'All Caught Up',
                        message:
                            'You have no unread notifications. New interests, proposals and activity will show up here.',
                      )
                    : const EmptyStateWidget(
                        title: 'No Notifications',
                        message:
                            'You are all caught up. Activity about your profile, interests and messages will appear here.',
                      );
              }

              return RefreshIndicator(
                color: AppColors.regAccent,
                onRefresh: () => _controller.fetchNotifications(refresh: true),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl,
                  ),
                  itemCount: _controller.notifications.length +
                      (_controller.isLoadingMore.value ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index == _controller.notifications.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.regAccent,
                          ),
                        ),
                      );
                    }
                    final notif = _controller.notifications[index];
                    return _NotificationCard(
                      notif: notif,
                      icon: _buildIcon(notif),
                      timeLabel: notif.createdAt != null
                          ? _formatDate(notif.createdAt!)
                          : null,
                      onTap: () => _handleNotificationTap(notif),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── All | Unread segmented tabs ───────────────────────────────────────────
  Widget _buildTabs(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.roseFieldBorder),
      ),
      child: Obx(() {
        final bool unreadSelected = _controller.showUnreadOnly.value;
        return Row(
          children: <Widget>[
            _buildTab(
              context,
              label: 'All',
              selected: !unreadSelected,
              onTap: () => _controller.setUnreadOnly(false),
            ),
            _buildTab(
              context,
              label: _controller.unreadCount.value > 0
                  ? 'Unread (${_controller.unreadCount.value})'
                  : 'Unread',
              selected: unreadSelected,
              onTap: () => _controller.setUnreadOnly(true),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.regAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.fieldLabelRose,
            ),
          ),
        ),
      ),
    );
  }

  // ── skeleton feed while the first page loads ──────────────────────────────
  Widget _buildSkeleton(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.roseFieldBorder),
        ),
        child: const Row(
          children: <Widget>[
            Skeleton(height: 44, circle: true),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Skeleton(width: 150, height: 13),
                  SizedBox(height: 8),
                  Skeleton(width: double.infinity, height: 11),
                  SizedBox(height: 6),
                  Skeleton(width: 80, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One notification as a quiet white card (rose recipe); unread rows carry a
/// brand wash, a rose dot and a bolder title. Chat rows read as inbox previews.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notif,
    required this.icon,
    required this.onTap,
    this.timeLabel,
  });

  final NotificationModel notif;
  final Widget icon;
  final String? timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = Theme.of(context).textTheme.titleLarge?.color ?? AppColors.roseTitleInk;
    final bool isChat = notif.isChatMessage;

    final Widget card = Material(
      color: notif.isRead
          ? Colors.white
          : AppColors.regAccent.withValues(alpha: dark ? 0.10 : 0.05),
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.roseFieldBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              icon,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notif.title.capitalizeFirst ?? notif.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: titleColor,
                              fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          timeLabel ?? '',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        if (!notif.isRead) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.regAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.message,
                      maxLines: isChat ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        height: 1.4,
                        fontStyle: isChat ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (isChat) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Theme.of(context).hintColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (dark) return card;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x1AB4487B), // #B4487B @ 10%
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: card,
    );
  }
}
