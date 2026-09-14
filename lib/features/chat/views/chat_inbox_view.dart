import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../models/chat_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/storage/call_log_service.dart';
import 'call_history_view.dart';
import 'chat_conversation_view.dart';

/// Conversation inbox: search + threads list, with call history a swipe or
/// tab-tap away.
///
/// Embedded into the "Chat" tab of HomeView — the shell already provides the
/// gradient "Chat" header, so this view owns only the segmented Chats/Calls
/// control and the content beneath it (the old duplicate in-body TabBar that
/// stacked a second pink bar under the shell header is gone).
///
/// [standalone] is for the one place the inbox is pushed as its own route:
/// a chat-notification tap. Without the shell there is no header at all and
/// the member had no visible way back — so standalone mode supplies the same
/// gradient PremiumAppBar every other secondary screen uses, whose back
/// button appears automatically because the route can pop.
class ChatInboxView extends StatelessWidget {
  const ChatInboxView({super.key, this.standalone = false});

  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final Widget content = DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          // Segmented Chats/Calls control — hosted here so DefaultTabController
          // and the TabBarView stay in one subtree.
          Container(
            margin: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkBorder
                    : AppColors.lightDivider,
              ),
            ),
            child: const _InboxTabs(),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Expanded(
            child: TabBarView(
              children: <Widget>[
                _ChatsTab(),
                CallHistoryView(),
              ],
            ),
          ),
        ],
      ),
    );

    if (!standalone) return content;
    return Scaffold(
      appBar: const PremiumAppBar(
        title: 'Chat',
        subtitle: 'Conversations',
      ),
      body: content,
    );
  }
}

class _InboxTabs extends StatelessWidget {
  const _InboxTabs();

  @override
  Widget build(BuildContext context) {
    return TabBar(
      indicator: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgAll,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: -2,
          ),
        ],
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.white,
      unselectedLabelColor: Theme.of(context).hintColor,
      labelStyle: AppTextStyles.bodyStrong.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: AppTextStyles.body.copyWith(fontSize: 13.5),
      dividerColor: Colors.transparent,
      splashBorderRadius: AppRadius.lgAll,
      tabs: <Tab>[
        const Tab(
          height: 42,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.chat_bubble_outline_rounded, size: 16),
              SizedBox(width: 6),
              Text('Chats'),
            ],
          ),
        ),
        Tab(
          height: 42,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.call_outlined, size: 16),
              const SizedBox(width: 6),
              const Text('Calls'),
              // Missed calls the member has not looked at yet. Reads straight
              // off the local log, so it is right even with no network, and
              // clears when the tab is opened.
              Obx(() {
                final int missed = Get.isRegistered<CallLogService>()
                    ? Get.find<CallLogService>().unseenMissedCount
                    : 0;
                if (missed == 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    missed > 99 ? '99+' : '$missed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chats tab content: search field + conversation list.
class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
    final ChatController controller = Get.find<ChatController>();
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        // Search field — quiet neutral pill, brand only on the active icon.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? AppColors.darkBorder
                    : AppColors.lightDivider,
              ),
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
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.primary, size: 20),
                suffixIcon: Obx(() {
                  if (controller.searchQuery.value.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: controller.clearSearch,
                  );
                }),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 11),
              ),
            ),
          ),
        ),

        // Thread list
        Expanded(
          child: Obx(() {
            final ApiState<List<ChatThread>> state = controller.threadsState.value;

            switch (state.status) {
              case ApiStatus.initial:
              case ApiStatus.loading:
                return const SkeletonList();
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.search_off_rounded,
                              size: 40, color: theme.hintColor),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'No conversations match "${controller.searchQuery.value}"',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body
                                .copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: controller.loadThreads,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs,
                      AppSpacing.xs,
                      AppSpacing.xs,
                      AppSpacing.xxxl + AppSpacing.xl,
                    ),
                    itemCount: list.length,
                    itemBuilder: (BuildContext ctx, int i) {
                      final ChatThread thread = list[i];
                      return _ThreadTile(
                        thread: thread,
                        // Hairline between rows only (never after the last).
                        showDivider: i < list.length - 1,
                        onTap: () => ChatConversationView.open(thread),
                      );
                    },
                  ),
                );
            }
          }),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thread List Tile
// ---------------------------------------------------------------------------

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.onTap,
    this.showDivider = true,
  });

  final ChatThread thread;
  final VoidCallback onTap;
  final bool showDivider;

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
      return DateFormat('EEEE').format(dt);
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final bool hasUnread = thread.unreadCount > 0;
    final String timeStr =
        _formatTimestamp(thread.lastMessageAt ?? thread.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 10),
              child: Row(
                children: <Widget>[
                  // Avatar with online badge; unread threads get a brand ring.
                  Stack(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: hasUnread
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.14),
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

                  // Name & preview
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
                                  fontWeight:
                                      hasUnread ? FontWeight.w800 : FontWeight.w600,
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
                                  color: hasUnread
                                      ? AppColors.primary
                                      : theme.hintColor,
                                  fontWeight: hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            if (thread.isBlocked) ...<Widget>[
                              const Icon(Icons.block_rounded,
                                  size: 13, color: AppColors.error),
                              const SizedBox(width: 4),
                              const Text(
                                'Blocked • ',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                thread.previewText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: hasUnread
                                      ? (dark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary)
                                      : theme.hintColor.withValues(alpha: 0.8),
                                  fontWeight: hasUnread
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUnread) ...<Widget>[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: AppColors.brandGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(AppRadius.pill)),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                      spreadRadius: -1,
                                    ),
                                  ],
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
            // Theme-aware hairline divider (was hardcoded lightDivider and
            // burned bright white lines across the dark screen).
            if (showDivider)
              Divider(
                height: 1,
                thickness: 0.6,
                indent: 72,
                endIndent: 16,
                color: dark ? AppColors.darkDivider : AppColors.lightDivider,
              ),
          ],
        ),
      ),
    );
  }
}
