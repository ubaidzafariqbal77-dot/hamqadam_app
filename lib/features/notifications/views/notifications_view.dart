import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/notification_controller.dart';
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
  Widget _buildIcon(String type) {
    IconData iconData;
    Color color;
    final String lower = type.toLowerCase();

    if (lower.contains('interest')) {
      iconData = Icons.favorite_rounded;
      color = AppColors.primary;
    } else if (lower.contains('proposal')) {
      iconData = Icons.mail_rounded;
      color = AppColors.success;
    } else if (lower.contains('message') || lower.contains('chat')) {
      iconData = Icons.chat_rounded;
      color = Colors.blueAccent;
    } else if (lower.contains('view')) {
      iconData = Icons.visibility_rounded;
      color = AppColors.info;
    } else if (lower.contains('coin') || lower.contains('bonus') || lower.contains('credit')) {
      iconData = Icons.monetization_on_rounded;
      color = AppColors.gold;
    } else if (lower.contains('payment') || lower.contains('package') || lower.contains('plan')) {
      iconData = Icons.workspace_premium_rounded;
      color = AppColors.primary;
    } else {
      iconData = Icons.notifications_rounded;
      color = AppColors.gold;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 22),
    );
  }

  // ── navigation on tap ─────────────────────────────────────────────────────
  void _handleNotificationTap(NotificationModel notif) {
    if (!notif.isRead) _controller.markAsRead(notif.id);

    final String type = notif.type.toLowerCase();

    // 1. Chat messages
    if (type.contains('message') || type.contains('chat')) {
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


  void _openChatFromNotif(NotificationModel notif) {
    // Try to look up the thread from the already-loaded ChatController state
    if (Get.isRegistered<ChatController>()) {
      final ChatController chatCtrl = Get.find<ChatController>();
      final List<ChatThread> threads =
          chatCtrl.threadsState.value.data ?? <ChatThread>[];

      // Try to match by notify_by (sender's user id) or info_id (thread id)
      final int? notifyBy = notif.notifyBy;
      final int? infoId = notif.infoId;

      ChatThread? thread;

      // First attempt: match by thread id (info_id often is the thread id for message notifs)
      if (infoId != null) {
        thread = threads.cast<ChatThread?>().firstWhere(
          (t) => t?.id == infoId,
          orElse: () => null,
        );
      }

      // Second attempt: match by participant's user id (notify_by)
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

    // Fallback: go to chat inbox
    Get.to(() => const ChatInboxView());
  }

  // ── date formatter ────────────────────────────────────────────────────────
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 6) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
    return 'Just now';
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Notifications',
        subtitle: 'Updates about your activity',
        actions: <Widget>[
          Obx(() {
            if (_controller.unreadCount.value > 0) {
              return TextButton(
                onPressed: _controller.markAllAsRead,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Mark all read'),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoading.value && _controller.notifications.isEmpty) {
          // Skeleton feed while the first page loads.
          return ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, _) => Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Skeleton(height: 44, circle: true),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const <Widget>[
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

        if (!_controller.isLoading.value && _controller.notifications.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Notifications',
            message: 'You are all caught up. Activity about your profile, interests and messages will appear here.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
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
                      color: AppColors.primary,
                    ),
                  ),
                );
              }
              final notif = _controller.notifications[index];
              return _NotificationCard(
                notif: notif,
                icon: _buildIcon(notif.type),
                timeLabel: notif.createdAt != null
                    ? _formatDate(notif.createdAt!)
                    : null,
                onTap: () => _handleNotificationTap(notif),
              );
            },
          ),
        );
      }),
    );
  }
}

/// One notification as a quiet card; unread rows get a brand wash and a dot.
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
    final Color titleColor = Theme.of(context).textTheme.titleLarge?.color ?? AppColors.lightTextPrimary;
    return Material(
      color: notif.isRead
          ? Theme.of(context).cardColor
          : AppColors.primary.withValues(alpha: dark ? 0.10 : 0.05),
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: dark ? AppColors.darkBorder : AppColors.lightBorder),
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
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        height: 1.4,
                      ),
                    ),
                    if (timeLabel != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        timeLabel!,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11.5,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
