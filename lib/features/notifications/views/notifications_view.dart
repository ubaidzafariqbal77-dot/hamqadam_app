import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../constants/app_colors.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/notification_controller.dart';
import '../../../features/chat/views/chat_conversation_view.dart';
import '../../../features/chat/views/chat_inbox_view.dart';
import '../../../models/chat_model.dart';
import '../../../models/notification_model.dart';
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
    switch (type) {
      case 'express_interest':
      case 'accept_interest':
      case 'reject_interest':
        iconData = Icons.favorite_rounded;
        color = AppColors.primary;
        break;
      case 'express_proposal':
      case 'accept_proposal':
      case 'reject_proposal':
      case 'withdraw_proposal':
      case 'cancel_proposal':
        iconData = Icons.mail_rounded;
        color = AppColors.success;
        break;
      case 'new_message':
      case 'chat_message':
      case 'message':
        iconData = Icons.chat_rounded;
        color = Colors.blueAccent;
        break;
      default:
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

    final String type = notif.type;

    // Message notification → navigate to the matching chat thread
    if (type == 'new_message' || type == 'chat_message' || type == 'message') {
      _openChatFromNotif(notif);
      return;
    }

    // All other types: just close the notification screen or do nothing
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          Obx(() {
            if (_controller.unreadCount.value > 0) {
              return TextButton(
                onPressed: _controller.markAllAsRead,
                child: const Text('Mark all read'),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoading.value && _controller.notifications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!_controller.isLoading.value && _controller.notifications.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Notifications',
            message: 'You have no notifications yet.',
          );
        }

        return RefreshIndicator(
          onRefresh: () => _controller.fetchNotifications(refresh: true),
          child: ListView.separated(
            controller: _scrollController,
            itemCount: _controller.notifications.length +
                (_controller.isLoadingMore.value ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == _controller.notifications.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final notif = _controller.notifications[index];
              return Material(
                color: notif.isRead
                    ? Colors.transparent
                    : AppColors.primary.withValues(alpha: 0.05),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: _buildIcon(notif.type),
                  title: Text(
                    notif.title.capitalizeFirst ?? notif.title,
                    style: TextStyle(
                      fontWeight:
                          notif.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 3),
                      Text(notif.message),
                      if (notif.createdAt != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(notif.createdAt!),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                  trailing: notif.isRead
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () => _handleNotificationTap(notif),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
