import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/call_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../../../core/utils/app_logger.dart';
import '../../../models/call_model.dart';
import '../../../models/chat_model.dart';
import '../../../widgets/state_widgets.dart';
import 'chat_conversation_view.dart';

/// WhatsApp-style call history list.
///
/// Loads call history from all chat threads the user participates in.
/// Each entry shows the peer name, photo, call type icon, direction,
/// timestamp, and duration. Tapping an entry opens the chat (from which
/// a new call can be started) or directly starts a call.
class CallHistoryView extends StatefulWidget {
  const CallHistoryView({super.key});

  @override
  State<CallHistoryView> createState() => _CallHistoryViewState();
}

class _CallHistoryViewState extends State<CallHistoryView> {
  final RxList<_CallEntry> _calls = <_CallEntry>[].obs;
  final RxBool _loading = true.obs;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    _loading.value = true;
    try {
      final ChatController chatCtrl = Get.find<ChatController>();
      final ApiClient client = Get.find<ApiClient>();
      final List<_CallEntry> allCalls = <_CallEntry>[];

      // Get all threads
      final ApiState<List<ChatThread>> threadState = chatCtrl.threadsState.value;
      final List<ChatThread> threads = threadState.data ?? <ChatThread>[];

      // Load call history for each thread (limit to first 10 for performance)
      final int limit = threads.length > 10 ? 10 : threads.length;
      for (int i = 0; i < limit; i++) {
        final ChatThread thread = threads[i];
        try {
          final ApiEnvelope res = await client.get(
            '/chat/threads/${thread.id}/calls',
            query: <String, dynamic>{'per_page': 20},
          );
          final List<dynamic> data =
              res.data is List ? res.data as List : <dynamic>[];
          for (final dynamic item in data) {
            if (item is Map<String, dynamic>) {
              final CallModel? call = CallModel.fromJson(item);
              if (call != null) {
                allCalls.add(_CallEntry(call: call, thread: thread));
              }
            }
          }
        } catch (e) {
          AppLogger.d('Failed to load calls for thread ${thread.id}: $e');
        }
      }

      // Sort by answered_at or ended_at descending (most recent first)
      allCalls.sort((a, b) {
        final DateTime? aTime = b.call.endedAt ?? b.call.answeredAt;
        final DateTime? bTime = a.call.endedAt ?? a.call.answeredAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

      _calls.value = allCalls;
    } catch (e) {
      AppLogger.w('Failed to load call history: $e');
    } finally {
      _loading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: <Widget>[
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
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
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search call history…',
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.primary, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 11),
                ),
              ),
            ),
          ),

          // Call list
          Expanded(
            child: Obx(() {
              if (_loading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (_calls.isEmpty) {
                return EmptyStateWidget(
                  title: 'No Calls Yet',
                  message:
                      'Your call history will appear here.\nStart a call from any chat.',
                  onRefresh: _loadHistory,
                );
              }

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadHistory,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.xxxl + AppSpacing.xl,
                  ),
                  itemCount: _calls.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: AppColors.lightDivider,
                  ),
                  itemBuilder: (BuildContext ctx, int i) {
                    final _CallEntry entry = _calls[i];
                    return _CallTile(entry: entry);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal wrapper
// ---------------------------------------------------------------------------

class _CallEntry {
  const _CallEntry({required this.call, required this.thread});
  final CallModel call;
  final ChatThread thread;
}

// ---------------------------------------------------------------------------
// Call List Tile
// ---------------------------------------------------------------------------

class _CallTile extends StatelessWidget {
  const _CallTile({required this.entry});

  final _CallEntry entry;

  String _formatTime(DateTime? dt) {
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

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m}m ${s}s';
  }

  IconData _callIcon() {
    final CallStatus status = entry.call.status;
    if (status == CallStatus.missed) return Icons.call_missed_rounded;
    // Incoming = caller is NOT me
    final int myUserId = Get.find<CallController>().myUserId;
    if (entry.call.isCaller(myUserId)) {
      return Icons.call_made_rounded; // outgoing
    }
    return Icons.call_received_rounded; // incoming
  }

  Color _callColor(BuildContext context) {
    if (entry.call.status == CallStatus.missed) return AppColors.error;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int myUserId = Get.find<CallController>().myUserId;
    final CallParticipant? peer = entry.call.peerFor(myUserId);
    final String name = peer?.displayName ?? 'HamQadam Member';
    final String? photo = peer?.photoUrl;

    // Prefer ended_at > answered_at for "when did this happen"
    final DateTime? displayTime =
        entry.call.endedAt ?? entry.call.answeredAt;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          // Open the chat conversation (from which user can start a call)
          ChatConversationView.open(entry.thread);
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
          child: Row(
            children: <Widget>[
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                backgroundImage: photo != null && photo.isNotEmpty
                    ? NetworkImage(photo)
                    : null,
                child: (photo == null || photo.isEmpty)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: AppTextStyles.title.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),

              // Name + call info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style:
                          AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Icon(_callIcon(),
                            size: 14, color: _callColor(context)),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.call.isVideo ? "Video" : "Audio"}'
                          '${entry.call.durationSeconds > 0 ? " • ${_formatDuration(entry.call.durationSeconds)}" : ""}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Time + call button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    _formatTime(displayTime),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      // Start a call directly
                      if (entry.thread.id > 0) {
                        Get.find<CallController>().startCall(
                          threadId: entry.thread.id,
                          isVideo: entry.call.isVideo,
                        );
                      }
                    },
                    child: Icon(
                      entry.call.isVideo
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
