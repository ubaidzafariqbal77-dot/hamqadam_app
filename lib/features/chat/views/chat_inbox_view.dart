import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/chat_model.dart';
import '../../../widgets/state_widgets.dart';
import 'chat_conversation_view.dart';

/// Conversation inbox view embedded directly into the "Chat" tab of HomeView.
class ChatInboxView extends StatelessWidget {
  const ChatInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatController controller = Get.find<ChatController>();
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: <Widget>[
          // Top Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightDivider),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: controller.searchController,
                onChanged: controller.onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search conversations…',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: theme.hintColor.withValues(alpha: 0.7),
                    fontSize: 13.5,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                  suffixIcon: Obx(() {
                    if (controller.searchQuery.value.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: controller.clearSearch,
                    );
                  }),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 11),
                ),
              ),
            ),
          ),

          // Thread List
          Expanded(
            child: Obx(() {
              final ApiState<List<ChatThread>> state = controller.threadsState.value;

              switch (state.status) {
                case ApiStatus.initial:
                case ApiStatus.loading:
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                case ApiStatus.noInternet:
                  return NoInternetWidget(onRetry: controller.loadThreads);
                case ApiStatus.unauthorized:
                case ApiStatus.serverError:
                case ApiStatus.validationError:
                  return ErrorStateWidget(
                    message: state.message,
                    onRetry: controller.loadThreads,
                  );
                case ApiStatus.empty:
                  return EmptyStateWidget(
                    title: 'No Conversations Yet',
                    message: state.message ??
                        'When someone accepts your interest or messages you, your conversations will appear here.',
                    onRefresh: controller.loadThreads,
                  );
                case ApiStatus.success:
                  final List<ChatThread> list = controller.filteredThreads;

                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'No conversations match "${controller.searchQuery.value}"',
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: controller.loadThreads,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.xs,
                        AppSpacing.sm,
                        AppSpacing.xxxl + AppSpacing.xl, // clears bottom nav
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 16,
                        color: AppColors.lightDivider,
                      ),
                      itemBuilder: (BuildContext ctx, int i) {
                        final ChatThread thread = list[i];
                        return _ThreadTile(
                          thread: thread,
                          onTap: () => ChatConversationView.open(thread),
                        );
                      },
                    ),
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
// Thread List Tile
// ---------------------------------------------------------------------------

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.onTap});

  final ChatThread thread;
  final VoidCallback onTap;

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) {
      return DateFormat('h:mm a').format(dt);
    } else if (today.difference(msgDate).inDays == 1) {
      return 'Yesterday';
    } else if (now.difference(dt).inDays < 7) {
      return DateFormat('EEEE').format(dt); // e.g. "Monday"
    } else {
      return DateFormat('MMM d').format(dt); // e.g. "Aug 26"
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasUnread = thread.unreadCount > 0;
    final String timeStr = _formatTimestamp(thread.lastMessageAt ?? thread.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
          child: Row(
            children: <Widget>[
              // Avatar with Online Badge
              Stack(
                children: <Widget>[
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                    backgroundImage: thread.participant.hasPhoto
                        ? NetworkImage(thread.participant.photo!)
                        : null,
                    child: !thread.participant.hasPhoto
                        ? Text(
                            thread.participant.initial,
                            style: AppTextStyles.title.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  if (thread.participant.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),

              // Name & Preview text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            thread.participant.name,
                            style: AppTextStyles.bodyStrong.copyWith(
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: hasUnread ? AppColors.primary : theme.hintColor,
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        if (thread.isBlocked) ...<Widget>[
                          const Icon(Icons.block_rounded, size: 13, color: AppColors.error),
                          const SizedBox(width: 4),
                          const Text(
                            'Blocked • ',
                            style: TextStyle(fontSize: 12.5, color: AppColors.error, fontWeight: FontWeight.w600),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            thread.previewText,
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread
                                  ? theme.textTheme.bodyLarge?.color
                                  : theme.hintColor.withValues(alpha: 0.8),
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors.brandGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
                            ),
                            child: Text(
                              '${thread.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
