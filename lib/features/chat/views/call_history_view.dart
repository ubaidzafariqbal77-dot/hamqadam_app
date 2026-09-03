import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/call_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/api/api_response.dart';
import '../../../core/storage/call_log_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../models/call_log_entry.dart';
import '../../../models/call_model.dart';
import '../../../models/chat_model.dart';
import '../../../repositories/call_repository.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/state_widgets.dart';
import 'chat_conversation_view.dart';

/// WhatsApp-style call history, read from the device's own log.
///
/// This used to be assembled live from the server: one
/// `GET /chat/threads/{id}/calls` per conversation, capped at the first ten
/// threads. So the tab was slow, empty without a network, incomplete for anyone
/// with more than ten conversations, and — worst of all — it lost missed calls,
/// because a call that arrived while the app was closed only showed up if its
/// thread happened to fall inside that cap.
///
/// [CallLogService] now records every call as it happens, so the list is a
/// local read that appears instantly. The server is still consulted, but in the
/// background and only to top up gaps from while the app was closed; whatever
/// it returns is merged onto the same rows by call id.
class CallHistoryView extends StatefulWidget {
  const CallHistoryView({super.key});

  @override
  State<CallHistoryView> createState() => _CallHistoryViewState();
}

class _CallHistoryViewState extends State<CallHistoryView> {
  final CallLogService _log = Get.find<CallLogService>();
  final RxBool _toppingUp = false.obs;

  @override
  void initState() {
    super.initState();
    // Opening the tab is what clears the missed-call badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _log.markAllSeen();
      _topUpFromServer();
    });
  }

  /// Merges the server's recent calls for the busiest few conversations.
  ///
  /// Bounded on purpose: this is a gap-filler for calls that happened while the
  /// app was closed, not the source of the list. It never blocks the UI, and a
  /// failure leaves the local history exactly as it was.
  Future<void> _topUpFromServer({int threadLimit = 6}) async {
    if (_toppingUp.value) return;
    if (!Get.isRegistered<ChatController>() ||
        !Get.isRegistered<CallRepository>()) {
      return;
    }
    _toppingUp.value = true;
    try {
      final ChatController chat = Get.find<ChatController>();
      final CallRepository repo = Get.find<CallRepository>();
      final int myUserId = chat.myUserId;
      if (myUserId <= 0) return;

      final ApiState<List<ChatThread>> state = chat.threadsState.value;
      final List<ChatThread> threads = (state.data ?? <ChatThread>[])
          .where((ChatThread t) => t.id > 0)
          .take(threadLimit)
          .toList();

      for (final ChatThread thread in threads) {
        try {
          final List<CallModel> calls = await repo.history(thread.id);
          for (final CallModel call in calls) {
            await _log.recordCall(call, myUserId: myUserId);
          }
        } catch (e) {
          AppLogger.d('Call top-up failed for thread ${thread.id}: $e');
        }
      }
      // Rows added by the top-up are history, not news.
      await _log.markAllSeen();
    } finally {
      _toppingUp.value = false;
    }
  }

  // ---- Actions --------------------------------------------------------------

  void _callBack(CallLogEntry entry) {
    if (entry.threadId <= 0) {
      AppSnackbar.info('This conversation is no longer available.');
      return;
    }
    if (!Get.isRegistered<CallController>()) {
      AppSnackbar.error('Calling is unavailable right now.');
      return;
    }
    Get.find<CallController>().startCall(
      threadId: entry.threadId,
      isVideo: entry.isVideo,
    );
  }

  Future<void> _openChat(CallLogEntry entry) async {
    if (!Get.isRegistered<ChatController>()) return;
    final ChatController chat = Get.find<ChatController>();
    final List<ChatThread> threads =
        chat.threadsState.value.data ?? <ChatThread>[];
    for (final ChatThread t in threads) {
      if (t.id == entry.threadId) {
        ChatConversationView.open(t);
        return;
      }
    }
    await chat.openThreadById(entry.threadId, participantId: entry.peerId);
  }

  void _showOptions(CallLogEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Text(entry.peerName, style: AppTextStyles.bodyStrong),
            ),
            ListTile(
              leading: const Icon(Icons.call_rounded, color: AppColors.primary),
              title: const Text('Voice call'),
              onTap: () {
                Navigator.pop(ctx);
                Get.find<CallController>()
                    .startCall(threadId: entry.threadId, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded, color: AppColors.primary),
              title: const Text('Video call'),
              onTap: () {
                Navigator.pop(ctx);
                Get.find<CallController>()
                    .startCall(threadId: entry.threadId, isVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Message'),
              onTap: () {
                Navigator.pop(ctx);
                _openChat(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text(
                'Remove from history',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _log.remove(entry.callId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear call history?'),
        content: const Text(
          'This removes the call list from this device only. It does not delete '
          'anything from your account.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (yes == true) await _log.clear();
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Obx(() {
      final List<CallLogEntry> calls = _log.entries.toList();

      if (calls.isEmpty) {
        return RefreshIndicator(
          onRefresh: _topUpFromServer,
          child: ListView(
            children: <Widget>[
              SizedBox(height: MediaQuery.of(context).size.height * 0.12),
              const EmptyStateWidget(
                title: 'No calls yet',
                message: 'Your voice and video calls will appear here.',
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _topUpFromServer,
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: calls.length + 1,
          separatorBuilder: (BuildContext _, int __) => Divider(
            height: 1,
            indent: 76,
            color: theme.dividerColor.withValues(alpha: 0.4),
          ),
          itemBuilder: (BuildContext ctx, int index) {
            if (index == calls.length) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _confirmClearAll,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Clear call history'),
                    style: TextButton.styleFrom(foregroundColor: theme.hintColor),
                  ),
                ),
              );
            }
            return _CallRow(
              entry: calls[index],
              onTap: () => _callBack(calls[index]),
              onLongPress: () => _showOptions(calls[index]),
            );
          },
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// One row
// ---------------------------------------------------------------------------

class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final CallLogEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// Red for a missed call, so the list is scannable at a glance — the one
  /// thing a member looks for here.
  Color _labelColour(ThemeData theme) =>
      entry.isMissedCall ? AppColors.error : theme.hintColor;

  IconData get _directionIcon {
    if (entry.isMissedCall) return Icons.call_missed_rounded;
    if (entry.outcome == CallLogOutcome.declined) {
      return Icons.call_end_rounded;
    }
    return entry.isIncoming
        ? Icons.call_received_rounded
        : Icons.call_made_rounded;
  }

  String _timeLabel() {
    final DateTime now = DateTime.now();
    final DateTime at = entry.startedAt;
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime thatDay = DateTime(at.year, at.month, at.day);
    final int daysAgo = today.difference(thatDay).inDays;

    if (daysAgo == 0) return DateFormat('h:mm a').format(at);
    if (daysAgo == 1) return 'Yesterday, ${DateFormat('h:mm a').format(at)}';
    if (daysAgo < 7) return DateFormat('EEEE, h:mm a').format(at);
    return DateFormat('d MMM, h:mm a').format(at);
  }

  String _durationLabel() {
    final int s = entry.durationSeconds;
    if (s <= 0) return '';
    if (s < 60) return ' · ${s}s';
    final int m = s ~/ 60;
    final int rem = s % 60;
    if (m < 60) return ' · ${m}m ${rem}s';
    return ' · ${m ~/ 60}h ${m % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? photo = entry.peerPhoto;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        backgroundImage: (photo != null && photo.isNotEmpty)
            ? NetworkImage(photo)
            : null,
        child: (photo == null || photo.isEmpty)
            ? Text(
                entry.peerName.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
      ),
      title: Text(
        entry.peerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyStrong.copyWith(
          color: entry.isMissedCall ? AppColors.error : null,
        ),
      ),
      subtitle: Row(
        children: <Widget>[
          Icon(_directionIcon, size: 15, color: _labelColour(theme)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${entry.label} · ${_timeLabel()}${_durationLabel()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: _labelColour(theme)),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          entry.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
          color: AppColors.primary,
        ),
        tooltip: entry.isVideo ? 'Video call' : 'Voice call',
        onPressed: onTap,
      ),
    );
  }
}
