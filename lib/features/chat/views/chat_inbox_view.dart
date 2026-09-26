import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../core/storage/call_log_service.dart';
import '../../../models/chat_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';
import 'call_history_view.dart';
import 'chat_archived_view.dart';
import 'chat_conversation_view.dart';

/// Long-press menu for one conversation, shared by the inbox and the Archived
/// tab so the same chat offers the same actions wherever it is found.
///
/// Archive and mute are both per side — the sheet says so, because "Archive"
/// reads like it hides the chat for the other person too.
Future<void> showChatThreadActions(
  BuildContext context,
  ChatThread thread,
) async {
  final ChatController controller = Get.find<ChatController>();
  final bool archived = thread.isArchived;
  final bool muted = thread.isMuted;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.chatCanvasTop,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
    builder: (BuildContext sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                  backgroundImage: thread.participant.hasPhoto
                      ? NetworkImage(thread.participant.photo!)
                      : null,
                  child: !thread.participant.hasPhoto
                      ? Text(
                          thread.participant.initial,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    thread.participant.name,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 16,
                      color: AppColors.roseTitleInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              color: AppColors.primary,
            ),
            title: Text(archived ? 'Move back to inbox' : 'Archive chat'),
            subtitle: Text(
              archived
                  ? 'This chat returns to your main list.'
                  : 'Hides this chat from your list only.',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(sheet);
              controller.archiveThread(thread, archived: !archived);
            },
          ),
          ListTile(
            leading: Icon(
              muted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: AppColors.primary,
            ),
            title: Text(muted ? 'Unmute notifications' : 'Mute notifications'),
            subtitle: Text(
              muted
                  ? 'Push and tray alerts are silenced right now.'
                  : 'Messages still arrive, just without alerts.',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(sheet);
              controller.toggleMuteThread(thread);
            },
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    ),
  );
}

/// Conversation inbox — the "Chat Conversations" reference screen.
///
/// Drawn on its own blush canvas rather than under the shell's brand-gradient
/// header: the reference's title is a large centred serif line sitting on the
/// pink wash, with the Chats/Calls pills, the search pill and a stack of white
/// conversation cards beneath it. The member's own message data drives every
/// row — name, photo, last-message preview, timestamp and unread count all come
/// from `ChatController.threadsState`, so nothing here is placeholder content.
///
/// [standalone] is for the one place the inbox is pushed as its own route: a
/// chat-notification tap. Without the shell there is no header at all and the
/// member had no visible way back — so standalone mode supplies the same
/// gradient PremiumAppBar every other secondary screen uses, whose back button
/// appears automatically because the route can pop.
class ChatInboxView extends StatelessWidget {
  const ChatInboxView({super.key, this.standalone = false});

  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final Widget content = DefaultTabController(
      length: 2,
      child: DecoratedBox(
        // The reference canvas: white at the top, warming into blush as it
        // falls, so the white cards read as floating sheets.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? <Color>[
                    AppColors.darkBackground,
                    AppColors.darkBackground,
                  ]
                : const <Color>[
                    AppColors.chatCanvasTop,
                    AppColors.chatCanvasBottom,
                  ],
          ),
        ),
        child: Column(
          children: <Widget>[
            if (!standalone) const InboxHeader(),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
              child: InboxTabs(),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Expanded(
              child: TabBarView(
                children: <Widget>[
                  ChatsTab(),
                  CallHistoryView(),
                ],
              ),
            ),
          ],
        ),
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

/// The reference heading: a large centred serif title with the drawer control
/// on its left. The shell hides its own bar on this tab (see HomeView), so the
/// hamburger has to live here or the drawer would be unreachable.
class InboxHeader extends StatelessWidget {
  const InboxHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu_rounded, size: 24),
                color: dark ? AppColors.darkTextPrimary : AppColors.roseTitleInk,
                onPressed: () {
                  final ScaffoldState? shell =
                      Scaffold.maybeOf(context);
                  if (shell != null && shell.hasDrawer) shell.openDrawer();
                },
              ),
            ),
            Expanded(
              child: Text(
                'Chat Conversations',
                textAlign: TextAlign.center,
                // Playfair, like every other reference heading in the app.
                style: AppTextStyles.displaySerif.copyWith(
                  fontSize: 21,
                  color: dark ? AppColors.darkTextPrimary : AppColors.roseTitleInk,
                ),
              ),
            ),
            // Archived chats live behind their own folder rather than a third
            // pill, so the Chats/Calls pair of the reference stays intact.
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: 'Archived chats',
                icon: const Icon(Icons.inventory_2_outlined, size: 22),
                color: dark ? AppColors.darkTextPrimary : AppColors.roseTitleInk,
                onPressed: () => Get.to<void>(() => const ChatArchivedView()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chats / Calls as two free-standing pills on the canvas — the selected one
/// filled rose with its icon, the other plain white. A custom pair rather than
/// a [TabBar]: the reference gives the *unselected* pill a white fill, which an
/// indicator painted behind the tab row cannot produce.
class InboxTabs extends StatefulWidget {
  const InboxTabs({super.key});

  @override
  State<InboxTabs> createState() => _InboxTabsState();
}

class _InboxTabsState extends State<InboxTabs> {
  TabController? _tab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TabController? next = DefaultTabController.maybeOf(context);
    if (next == _tab) return;
    _tab?.removeListener(_onChange);
    _tab = next;
    _tab?.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tab?.removeListener(_onChange);
    super.dispose();
  }

  /// Missed calls the member has not looked at yet. Reads straight off the
  /// local log, so it is right even with no network, and clears when the tab is
  /// opened.
  ///
  /// Built only when that service exists: the count is a GetX observable, and
  /// an [Obx] that reads nothing at all (which is what a missing service means)
  /// is an error in GetX, not an empty badge.
  Widget? _missedCallsBadge() {
    if (!Get.isRegistered<CallLogService>()) return null;
    final CallLogService log = Get.find<CallLogService>();
    return Obx(() {
      final int missed = log.unseenMissedCount;
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final int index = _tab?.index ?? 0;
    return Row(
      children: <Widget>[
        Expanded(
          child: _InboxPill(
            label: 'Chats',
            icon: Icons.chat_bubble_outline_rounded,
            selected: index == 0,
            onTap: () => _tab?.animateTo(0),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _InboxPill(
            label: 'Calls',
            icon: Icons.call_outlined,
            selected: index == 1,
            onTap: () => _tab?.animateTo(1),
            badge: _missedCallsBadge(),
          ),
        ),
      ],
    );
  }
}

class _InboxPill extends StatelessWidget {
  const _InboxPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color idleInk = dark ? AppColors.darkTextSecondary : AppColors.chatPillIdleInk;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 46,
          decoration: BoxDecoration(
            gradient: selected && !dark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.chatPillGradient,
                  )
                : null,
            color: selected
                ? (dark ? AppColors.primary.withValues(alpha: 0.28) : null)
                : (dark ? AppColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (dark ? AppColors.darkBorder : AppColors.chatCardBorder),
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.20),
                      blurRadius: 14,
                      spreadRadius: -3,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 17, color: selected ? AppColors.chatPillInk : idleInk),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.chatPillInk : idleInk,
                ),
              ),
              if (badge != null) badge!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Chats tab content: search pill + conversation cards.
class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatController controller = Get.find<ChatController>();
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    return Column(
      children: <Widget>[
        // Search pill — plain white with the rose magnifier, per the reference.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: dark ? AppColors.darkBorder : AppColors.chatCardBorder,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle: AppTextStyles.body.copyWith(
                  color: dark
                      ? AppColors.darkTextHint
                      : AppColors.chatPillIdleInk,
                  fontSize: 14.5,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.primary, size: 22),
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
                    horizontal: AppSpacing.sm, vertical: 15),
              ),
            ),
          ),
        ),

        // Conversation list
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
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.xxxl + AppSpacing.xl,
                    ),
                    itemCount: list.length,
                    itemBuilder: (BuildContext ctx, int i) {
                      final ChatThread thread = list[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: <Widget>[
                            ChatThreadCard(
                              thread: thread,
                              onTap: () => ChatConversationView.open(thread),
                              onLongPress: () =>
                                  showChatThreadActions(ctx, thread),
                            ),
                            // Dotted hairline between conversations (never
                            // after the last one), exactly as the reference
                            // separates its cards.
                            if (i < list.length - 1)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: ChatDottedDivider(),
                              ),
                          ],
                        ),
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
// Conversation card
// ---------------------------------------------------------------------------

/// One conversation in the inbox.
///
/// Every value is the member's own data: [ChatThread.participant] supplies the
/// photo/name, [ChatThread.previewText] the last-message line (already
/// formatted as "You: …" or "Voice message • 0:12"), [ChatThread.unreadCount]
/// the badge. An unread row gains the rose edge bar and a heavier name; a voice
/// note gains the little waveform that marks the message kind at a glance.
class ChatThreadCard extends StatelessWidget {
  const ChatThreadCard({
    super.key,
    required this.thread,
    required this.onTap,
    this.onLongPress,
  });

  final ChatThread thread;
  final VoidCallback onTap;

  /// Opens archive/mute for this conversation. Optional so the card can still
  /// be dropped into read-only contexts (tests, previews) unchanged.
  final VoidCallback? onLongPress;

  /// Inbox timestamp: the clock for today, "Yesterday", the weekday inside the
  /// last week, then a short date — the reference's own progression.
  static String formatTimestamp(DateTime? dt) {
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
    final bool isVoice = thread.lastMessage?.isVoice ?? false;
    final String timeStr =
        formatTimestamp(thread.lastMessageAt ?? thread.createdAt);

    final Color nameInk = dark ? AppColors.darkTextPrimary : AppColors.roseTitleInk;
    final Color previewInk =
        dark ? AppColors.darkTextSecondary : AppColors.chatPreviewInk;
    final Color timeInk = dark ? AppColors.darkTextHint : AppColors.chatTimeInk;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurface : AppColors.chatCardFill,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: dark ? AppColors.darkBorder : AppColors.chatCardBorder,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: hasUnread ? 0.10 : 0.05),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Rose edge bar — the reference marks an unread conversation
                  // here, so the inbox can be scanned without reading numbers.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 5,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      gradient: dark
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: AppColors.chatAccentBar,
                            ),
                      color: dark
                          ? (hasUnread
                              ? AppColors.primary
                              : AppColors.darkBorder)
                          : (hasUnread ? null : Colors.transparent),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),

                  // Avatar with the online dot.
                  Stack(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 28,
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
                      if (thread.participant.isOnline)
                        Positioned(
                          bottom: 1,
                          right: 1,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: dark
                                    ? AppColors.darkSurface
                                    : AppColors.chatCardFill,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Name, message kind and preview.
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          thread.participant.name,
                          style: AppTextStyles.bodyStrong.copyWith(
                            fontSize: 16.5,
                            fontWeight:
                                hasUnread ? FontWeight.w800 : FontWeight.w700,
                            color: nameInk,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
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
                            // A voice note is marked with a miniature of its own
                            // waveform rather than a generic mic, so the row
                            // still reads as "someone spoke to you".
                            if (isVoice) ...<Widget>[
                              const ChatMiniWaveform(),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                thread.previewText,
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 14,
                                  color: previewInk,
                                  fontWeight: hasUnread
                                      ? FontWeight.w600
                                      : FontWeight.w400,
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
                  const SizedBox(width: 10),

                  // Timestamp over the unread count, as in the reference.
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // A silenced conversation says so in the row itself —
                          // otherwise a member who muted it weeks ago wonders
                          // why nobody ever alerts them again.
                          if (thread.isMuted) ...<Widget>[
                            Icon(
                              Icons.notifications_off_rounded,
                              size: 14,
                              color: timeInk,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            timeStr,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: timeInk,
                            ),
                          ),
                        ],
                      ),
                      if (hasUnread) ...<Widget>[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 26),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.brandGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(AppRadius.pill)),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.32),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Text(
                            '${thread.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ],
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

/// The dotted hairline that separates two conversation cards in the reference.
class ChatDottedDivider extends StatelessWidget {
  const ChatDottedDivider({super.key, this.height = 1});

  final double height;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height + 2,
      width: double.infinity,
      child: CustomPaint(
        painter: _DottedLinePainter(
          color: dark ? AppColors.darkDivider : AppColors.chatDottedLine,
        ),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  const _DottedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const double dot = 2.4;
    const double gap = 5.2;
    final double y = size.height / 2;
    for (double x = dot / 2; x <= size.width; x += dot + gap) {
      canvas.drawCircle(Offset(x, y), dot / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter old) => old.color != color;
}

/// Miniature voice waveform: seven rounded bars of varying height in the brand
/// rose, used to mark a conversation whose last message was spoken.
class ChatMiniWaveform extends StatelessWidget {
  const ChatMiniWaveform({super.key, this.color, this.barCount = 7});

  final Color? color;
  final int barCount;

  static const List<double> _heights = <double>[6, 11, 16, 9, 18, 12, 7];

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? AppColors.roseSelectedBorder;
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List<Widget>.generate(barCount, (int i) {
          return Padding(
            padding: EdgeInsets.only(right: i == barCount - 1 ? 0 : 2),
            child: Container(
              width: 2.4,
              height: _heights[i % _heights.length],
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
