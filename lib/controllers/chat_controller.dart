// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/api/api_response.dart';
import 'call_controller.dart';
import '../core/services/notification_service.dart';
import '../core/services/pusher_chat_service.dart';
import '../core/utils/app_logger.dart';

import '../core/storage/current_user_service.dart';
import '../features/chat/views/chat_conversation_view.dart';
import '../features/chat/views/chat_inbox_view.dart';
import '../models/chat_model.dart';
import '../repositories/chat_repository.dart';
import '../widgets/app_snackbar.dart';

/// Full GetX Controller for the Chat feature.
///
/// ## How realtime works here now
///
/// The socket is the primary path and the network is only touched when it has
/// something to tell us. What used to happen instead:
///
/// * a 2.5s timer re-fetched the newest 20 messages of the open conversation,
///   forever, whether or not anything had changed;
/// * an 8s timer re-fetched the whole inbox;
/// * and **every** realtime event also called `loadThreads()` — twice, because
///   the user channel and the thread channel both fire for one message.
///
/// So a short burst of messages turned into a burst of full inbox fetches on a
/// connection that was already busy, which is why chat felt *slower* when it
/// was busiest. Now:
///
/// * an incoming message patches the inbox row in memory ([_patchThreadPreview])
///   and only schedules a real fetch when it refers to a conversation we have
///   never seen;
/// * inbox refreshes are coalesced, so ten events in a second cost one request;
/// * polling exists purely as a fallback and its interval is chosen from the
///   socket's actual state ([_retuneFallback]) — seconds while realtime is
///   down, a slow reconcile while it is up, nothing at all in the background,
///   where the OS would throttle the timer anyway and pushes cover us.
class ChatController extends GetxController {
  ChatController({
    required ChatRepository repository,
    required PusherChatService pusher,
    required CurrentUserService currentUser,
  })  : _repo = repository,
        _pusher = pusher,
        _currentUser = currentUser;

  final ChatRepository _repo;
  final PusherChatService _pusher;
  final CurrentUserService _currentUser;

  // --------------------------------------------------------------------------
  // Inbox State
  // --------------------------------------------------------------------------

  /// All conversation threads loaded from `GET /chat/threads`.
  final Rx<ApiState<List<ChatThread>>> threadsState =
      const ApiState<List<ChatThread>>.initial().obs;

  /// Search query filtering the local thread list.
  final RxString searchQuery = ''.obs;
  final TextEditingController searchController = TextEditingController();

  /// Whether events are arriving over the socket right now. The UI can show a
  /// "connecting…" hint from this instead of pretending everything is live.
  final RxBool realtimeLive = false.obs;

  /// Total unread messages across all threads (for badges).
  int get totalUnreadCount {
    final List<ChatThread> list = threadsState.value.data ?? <ChatThread>[];
    return list.fold<int>(0, (int sum, ChatThread t) => sum + t.unreadCount);
  }

  /// Filtered threads list based on search query.
  List<ChatThread> get filteredThreads {
    final List<ChatThread> list = threadsState.value.data ?? <ChatThread>[];
    final String q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where((ChatThread t) =>
            t.participant.name.toLowerCase().contains(q) ||
            t.previewText.toLowerCase().contains(q))
        .toList();
  }

  // --------------------------------------------------------------------------
  // Active Conversation State
  // --------------------------------------------------------------------------

  final Rxn<ChatThread> activeThread = Rxn<ChatThread>();

  /// Newest first — the conversation list is drawn with `reverse: true`.
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final Rx<ApiStatus> messagesStatus = ApiStatus.initial.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  int _currentPage = 1;

  final RxBool isOtherTyping = false.obs;
  Timer? _typingResetTimer;
  Timer? _typingThrottle;

  final Rxn<ChatMessage> replyingTo = Rxn<ChatMessage>();
  final RxBool isSending = false.obs;
  final RxList<String> pendingAttachments = <String>[].obs;

  final TextEditingController messageInputController = TextEditingController();

  int get myUserId => _currentUser.user?.id ?? 0;
  int get activeThreadId => activeThread.value?.id ?? 0;

  // --------------------------------------------------------------------------
  // Realtime plumbing
  // --------------------------------------------------------------------------

  StreamSubscription<RealtimeStatus>? _statusSub;

  /// Coalesces inbox refreshes: many events, one request.
  Timer? _threadRefreshTimer;

  /// The adaptive fallback poller. Its period comes from [_retuneFallback].
  Timer? _fallbackTimer;
  Duration? _fallbackPeriod;

  bool _loadingThreads = false;
  bool _syncingMessages = false;
  bool _foreground = true;
  int _localIdSeed = 0;

  /// Whether the first inbox load has happened. Until it has, the messages
  /// already sitting in the inbox are recorded rather than announced.
  bool _seededPreviews = false;

  /// Message ids already applied, so a broadcast that arrives on both the
  /// thread channel and the user channel is only counted once.
  final Set<int> _ingested = <int>{};
  final Queue<int> _ingestOrder = Queue<int>();
  static const int _ingestWindow = 500;

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    _setupPusherListeners();

    // Realtime is connected up front, not when the Chat tab opens: a call can
    // arrive on any screen, and the controller that answers it has to already
    // be subscribed.
    _statusSub = _pusher.statusStream.listen(_onRealtimeStatus);
    _initPusher();

    loadThreads();
    _retuneFallback();
  }

  /// Connect Pusher and subscribe to the user channel right away.
  /// Safe to call multiple times — [PusherChatService] is idempotent.
  Future<void> _initPusher() async {
    try {
      if (myUserId > 0) {
        await _pusher.subscribeToUserChannel(myUserId);
      }
    } catch (e) {
      // Non-fatal: the service retries on its own backoff.
      AppLogger.d('Initial realtime subscribe deferred: $e');
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    messageInputController.dispose();
    _typingResetTimer?.cancel();
    _typingThrottle?.cancel();
    _threadRefreshTimer?.cancel();
    _fallbackTimer?.cancel();
    _statusSub?.cancel();
    // IMPORTANT: Do NOT disconnect the socket here.
    // It must stay connected for the whole app lifecycle so call-incoming
    // events, typing indicators and new messages arrive on ANY screen — not
    // only while the Chat tab is open. It is torn down on logout, by
    // AuthController.
    super.onClose();
  }

  // --------------------------------------------------------------------------
  // Realtime handlers
  // --------------------------------------------------------------------------

  void _onRealtimeStatus(RealtimeStatus status) {
    final bool live = _pusher.isConnected;
    if (realtimeLive.value != live) {
      realtimeLive.value = live;
      AppLogger.i('Chat realtime live=$live ($status)');
    }
    // The fallback interval depends on this, so re-tune on every transition.
    _retuneFallback();
  }

  void _setupPusherListeners() {
    // Anything that happened while the socket was down was broadcast to nobody,
    // so a reconnect has to be followed by a fetch of the gap.
    _pusher.onReconnected = catchUp;

    _pusher.onUserEvent = _handleUserEvent;

    _pusher.onThreadMessage = _handleThreadEvent;

    _pusher.onThreadTyping = (Map<String, dynamic> data) {
      // Defensive parse: the backend has sent this key as both an int and a
      // string, and a hard cast in a socket callback takes the stream with it.
      final int senderId = _asInt(data['sender_id'] ?? data['user_id']) ?? 0;
      if (senderId == 0 || senderId == myUserId) return;
      isOtherTyping.value = true;
      _typingResetTimer?.cancel();
      _typingResetTimer = Timer(const Duration(seconds: 4), () {
        isOtherTyping.value = false;
      });
    };

    _pusher.onThreadUpdated = (Map<String, dynamic> data) {
      final int threadId = activeThreadId;
      if (threadId > 0) _syncLatestMessages(threadId);
      _scheduleThreadRefresh();
    };

    // Call signalling is the backend's own `call-*` broadcast, handed straight
    // to the controller that owns the call API. The app used to infer calls
    // from `[CALL_INVITE:…]` text inside chat messages and poll for them every
    // three seconds — invisible to the server, so nothing was logged and a
    // closed app never rang.
    _pusher.onCallEvent = (String event, Map<String, dynamic> data) {
      if (Get.isRegistered<CallController>()) {
        Get.find<CallController>().handleCallEvent(event, data);
      }
    };
  }

  /// `private-App.User.{id}` — messages plus every other kind of activity.
  void _handleUserEvent(Map<String, dynamic> data) {
    final String event = (data['__event'] ?? '').toString();
    final ChatMessage? msg = _messageFrom(data);

    if (msg != null && msg.threadId > 0) {
      // The same message also arrives on the thread channel when that
      // conversation is open; `_ingestMessage` is idempotent, so whichever
      // lands first wins and the second is a no-op.
      _ingestMessage(msg);
      return;
    }

    // Non-chat activity (interest, proposal, profile view, coins). Show it
    // immediately rather than waiting for the notifications poller, but key the
    // claim on the server's own notification id so the poller and the FCM push
    // for the same event collapse into this one entry.
    _notifyActivity(data, event);
    _scheduleThreadRefresh();
  }

  /// `private-chat-thread.{id}` — messages, read receipts, deletions.
  void _handleThreadEvent(Map<String, dynamic> data) {
    final String event = (data['__event'] ?? '').toString();

    if (event.contains('deleted')) {
      final int? id = _asInt(
        (data['message'] is Map ? (data['message'] as Map)['id'] : null) ??
            data['message_id'] ??
            data['id'],
      );
      if (id != null) messages.removeWhere((ChatMessage m) => m.id == id);
      _scheduleThreadRefresh();
      return;
    }

    if (event.contains('read')) {
      // Nothing to draw yet — there are no read ticks in the bubble. Kept as an
      // explicit branch so it does not fall through and get mistaken for a new
      // message, which is what used to append an empty bubble.
      return;
    }

    final ChatMessage? msg = _messageFrom(data);
    if (msg == null) return;
    _ingestMessage(msg);
  }

  /// The one place an incoming message is applied. Everything — thread channel,
  /// user channel, push, poller — funnels through here, so de-duplication and
  /// the notification decision are made once.
  void _ingestMessage(ChatMessage msg) {
    // The backend broadcasts a message on the thread channel AND the recipient's
    // user channel, so this runs twice for one message. Merging is idempotent
    // and the notification has its own claim, but the unread counter is not —
    // patching the preview twice would count every message as two.
    if (!_firstSightOf(msg.id)) return;

    final bool isMine = msg.senderId == myUserId;
    final ChatThread? open = activeThread.value;
    // A placeholder thread (id 0, not created server-side yet) counts as open
    // only for a message from the person it is with. Treating *any* message as
    // belonging to it — which is what the id-0 case used to do — put another
    // conversation's message into this one and suppressed its notification.
    final bool isOpen = open != null &&
        (open.id == msg.threadId ||
            (open.id == 0 && open.participant.id == msg.senderId));

    if (isOpen) {
      _mergeIntoConversation(<ChatMessage>[msg]);
    }

    // Inbox row patched in place: instant, and no request.
    _patchThreadPreview(msg, incrementUnread: !isMine && !isOpen);

    if (isMine) return;
    _notifyIncoming(msg, isOpen: isOpen);
  }

  /// Raises the tray entry for one incoming message, or clears the conversation
  /// if the member is looking at it.
  ///
  /// This controller is the sole owner of chat notifications — the socket, the
  /// FCM push and the fallback fetch all end up here, and every one of them is
  /// keyed on the server's message id, so the same message can never be
  /// announced twice however many paths deliver it.
  void _notifyIncoming(ChatMessage msg, {required bool isOpen}) {
    // On screen and being read — no tray entry, and clear anything left over
    // for this conversation.
    if (isOpen && _foreground) {
      NotificationService.instance.cancelThreadNotifications(msg.threadId);
      return;
    }

    NotificationService.instance.showMessageNotification(
      messageId: msg.id,
      threadId: msg.threadId,
      senderId: msg.senderId,
      senderName: (msg.senderName?.trim().isNotEmpty ?? false)
          ? msg.senderName!.trim()
          : _participantName(msg.threadId) ?? 'New message',
      body: msg.messageType == 'text' || msg.message.trim().isNotEmpty
          ? (msg.message.trim().isNotEmpty ? msg.message.trim() : 'Sent a message')
          : _attachmentLabel(msg),
    );
  }

  /// Announces anything new in a freshly fetched inbox.
  ///
  /// This is the last-resort path: with the socket down AND pushes not
  /// arriving, the fallback fetch is the only thing that knows a message has
  /// landed, and the notifications poller no longer covers chat. The preview is
  /// not patched here — the list that was just assigned is the server's own, so
  /// incrementing unread on top of it would double-count.
  void _noticeThreadPreviews(List<ChatThread> threads) {
    final bool seeding = !_seededPreviews;
    _seededPreviews = true;

    for (final ChatThread t in threads) {
      final ChatMessage? last = t.lastMessage;
      if (last == null || last.id <= 0) continue;

      if (seeding) {
        // First load of the session: record what is already there without
        // announcing it, or every existing conversation would notify at once.
        _firstSightOf(last.id);
        continue;
      }

      if (!_firstSightOf(last.id)) continue; // already handled by another path
      if (last.senderId == myUserId) continue;
      if (t.unreadCount <= 0) continue; // already read elsewhere

      _notifyIncoming(last, isOpen: activeThreadId == t.id);
    }
  }

  String _attachmentLabel(ChatMessage msg) {
    switch (msg.messageType) {
      case 'image':
        return '📷 Photo';
      case 'audio':
        return '🎤 Voice message';
      case 'video':
        return '📹 Video';
      default:
        return '📎 Attachment';
    }
  }

  String? _participantName(int threadId) {
    final List<ChatThread> list = threadsState.value.data ?? <ChatThread>[];
    for (final ChatThread t in list) {
      if (t.id == threadId) return t.participant.name;
    }
    return null;
  }

  /// A tray notification for non-chat activity broadcast on the user channel.
  void _notifyActivity(Map<String, dynamic> data, String event) {
    try {
      final String type = event.isNotEmpty
          ? event
          : (data['type'] ?? '').toString().toLowerCase();
      if (type.startsWith('call-') || type.contains('call')) return; // CallController owns these

      final int? serverId = _asInt(data['notification_id'] ?? data['id']);
      final dynamic senderData = data['sender'] ?? data['user'] ?? data['from'];
      final String senderName = senderData is Map
          ? (senderData['name'] ?? senderData['first_name'] ?? 'Someone').toString()
          : 'Someone';

      String title;
      String body;
      if (type.contains('interest')) {
        title = 'New Interest';
        body = '$senderName is interested in you!';
      } else if (type.contains('proposal')) {
        title = 'New Proposal';
        body = '$senderName sent you a proposal!';
      } else if (type.contains('view')) {
        title = 'Profile View';
        body = '$senderName viewed your profile';
      } else {
        // An unrecognised event is not worth waking somebody for. The
        // notifications list still refreshes, so it is not lost — it just does
        // not buzz with "You have a new notification", which is what the old
        // catch-all did for every unknown payload.
        return;
      }

      // The same key the FCM push and the notifications poller use for this
      // event, so whichever arrives first is the only one that shows.
      final int? notifyBy = _asInt(
        data['notify_by'] ??
            data['sender_id'] ??
            (senderData is Map ? senderData['id'] : null),
      );
      final int? infoId = _asInt(data['info_id'] ?? data['id']);
      final String key = serverId != null
          ? 'notif:$serverId'
          : NotificationService.activityKey(
              type: type,
              notifyBy: notifyBy,
              infoId: infoId,
            );
      if (!NotificationService.instance.claim(key)) return;

      NotificationService.instance.showNotification(
        id: serverId ?? key.hashCode.abs().remainder(90000),
        title: title,
        body: body,
        payload: jsonEncode(<String, dynamic>{
          'type': type,
          'notify_by': notifyBy,
          'info_id': infoId,
        }),
      );
    } catch (e) {
      AppLogger.w('Could not raise the activity notification: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Local state patching — what makes the inbox feel instant
  // --------------------------------------------------------------------------

  /// Moves [msg]'s conversation to the top of the inbox with the new preview,
  /// without a request. Schedules a real fetch only when the conversation is
  /// not in the list yet, which is the one case the local data cannot cover.
  void _patchThreadPreview(ChatMessage msg, {required bool incrementUnread}) {
    final List<ChatThread>? current = threadsState.value.data;
    if (current == null) {
      _scheduleThreadRefresh();
      return;
    }

    final int index = current.indexWhere((ChatThread t) => t.id == msg.threadId);
    if (index < 0) {
      // First message of a brand-new conversation — only the server knows who
      // it is with.
      _scheduleThreadRefresh(delay: const Duration(milliseconds: 250));
      return;
    }

    final ChatThread existing = current[index];
    // Out-of-order delivery: an older message must not overwrite a newer
    // preview (it happens on reconnect, when the catch-up fetch and a live
    // broadcast race).
    final DateTime? seenAt = existing.lastMessageAt ?? existing.lastMessage?.createdAt;
    if (seenAt != null && msg.createdAt.isBefore(seenAt)) return;

    final ChatThread patched = existing.copyWith(
      lastMessage: msg,
      lastMessageAt: msg.createdAt,
      unreadCount: incrementUnread ? existing.unreadCount + 1 : existing.unreadCount,
    );

    final List<ChatThread> updated = List<ChatThread>.from(current)
      ..removeAt(index)
      ..insert(0, patched);
    threadsState.value = ApiState<List<ChatThread>>.success(updated);
  }

  /// Merges [incoming] into the open conversation, newest first, dropping
  /// anything already there. Returns true when something was actually added.
  bool _mergeIntoConversation(Iterable<ChatMessage> incoming) {
    final Set<int> known = messages
        .where((ChatMessage m) => m.id > 0)
        .map((ChatMessage m) => m.id)
        .toSet();

    final List<ChatMessage> fresh = <ChatMessage>[];
    for (final ChatMessage m in incoming) {
      if (m.id > 0 && known.contains(m.id)) continue;
      known.add(m.id);
      fresh.add(m);
    }
    if (fresh.isEmpty) return false;

    // An echo of a message this device just sent replaces its optimistic
    // bubble instead of appearing next to it.
    for (final ChatMessage m in fresh) {
      if (m.senderId != myUserId) continue;
      final int pendingIndex = messages.indexWhere(
        (ChatMessage p) => p.isPending && p.message == m.message,
      );
      if (pendingIndex >= 0) messages.removeAt(pendingIndex);
    }

    messages.addAll(fresh);
    _sortConversation();
    return true;
  }

  void _sortConversation() {
    messages.sort((ChatMessage a, ChatMessage b) {
      final int byTime = b.createdAt.compareTo(a.createdAt);
      if (byTime != 0) return byTime;
      return b.id.compareTo(a.id);
    });
    messages.refresh();
  }

  // --------------------------------------------------------------------------
  // Coalesced refresh + adaptive fallback polling
  // --------------------------------------------------------------------------

  /// Requests one inbox refresh soon. Repeated calls inside the window collapse
  /// into a single fetch.
  void _scheduleThreadRefresh({Duration delay = const Duration(milliseconds: 700)}) {
    if (_threadRefreshTimer?.isActive ?? false) return;
    _threadRefreshTimer = Timer(delay, () {
      _threadRefreshTimer = null;
      loadThreads(silent: true);
    });
  }

  /// Chooses the fallback poll interval from what the socket is actually doing.
  ///
  /// Realtime up: a slow reconcile, purely so a broadcast dropped by the
  /// network cannot strand a message indefinitely. Realtime down: fast enough
  /// to feel live. Backgrounded: nothing — the OS throttles timers there anyway
  /// and FCM is what reaches a backgrounded app.
  void _retuneFallback() {
    final Duration? wanted = _wantedFallbackPeriod();

    if (wanted == null) {
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
      _fallbackPeriod = null;
      return;
    }
    if (_fallbackPeriod == wanted && (_fallbackTimer?.isActive ?? false)) return;

    _fallbackTimer?.cancel();
    _fallbackPeriod = wanted;
    _fallbackTimer = Timer.periodic(wanted, (_) => _fallbackTick());
    AppLogger.d('Chat fallback poll every ${wanted.inSeconds}s');
  }

  Duration? _wantedFallbackPeriod() {
    if (!_foreground) return null;
    if (myUserId <= 0) return null;

    final bool live = realtimeLive.value;
    final bool inThread = activeThreadId > 0;

    if (live) {
      return inThread ? const Duration(seconds: 25) : const Duration(seconds: 60);
    }
    return inThread ? const Duration(seconds: 3) : const Duration(seconds: 8);
  }

  void _fallbackTick() {
    final int threadId = activeThreadId;
    if (threadId > 0) {
      _syncLatestMessages(threadId);
    } else {
      loadThreads(silent: true);
    }
  }

  /// Fetches whatever happened while we were not listening.
  ///
  /// Called on reconnect and on resume. Both are moments when the app knows it
  /// has a gap and nothing will be broadcast to fill it.
  Future<void> catchUp() async {
    if (myUserId <= 0) return;
    await loadThreads(silent: true);
    final int threadId = activeThreadId;
    if (threadId > 0) await _syncLatestMessages(threadId);
  }

  /// Called by [AppLifecycleService] when the app comes back to the front.
  void onAppResumed() {
    _foreground = true;
    _retuneFallback();
    catchUp();
    final int threadId = activeThreadId;
    if (threadId > 0) {
      // Whatever piled up in the tray for the conversation on screen has
      // already been read.
      NotificationService.instance.cancelThreadNotifications(threadId);
    }
  }

  /// Called by [AppLifecycleService] when the app leaves the foreground.
  void onAppBackgrounded() {
    _foreground = false;
    _retuneFallback();
  }

  /// Entry point for an FCM push that says something changed.
  void syncFromPush({int? threadId}) {
    _scheduleThreadRefresh(delay: const Duration(milliseconds: 200));
    if (threadId != null && threadId > 0 && threadId == activeThreadId) {
      _syncLatestMessages(threadId);
    }
  }

  /// Silently syncs new incoming messages into the active conversation.
  Future<void> _syncLatestMessages(int threadId) async {
    if (_syncingMessages || threadId <= 0) return;
    _syncingMessages = true;
    try {
      final ChatMessagesPage page =
          await _repo.fetchMessages(threadId, page: 1, perPage: 20);
      if (activeThreadId != threadId) return; // the member moved on mid-flight
      if (page.messages.isEmpty) return;

      if (_mergeIntoConversation(page.messages)) {
        // Only touch the inbox when the sync actually found something.
        final ChatMessage newest = page.messages.reduce(
          (ChatMessage a, ChatMessage b) =>
              a.createdAt.isAfter(b.createdAt) ? a : b,
        );
        _patchThreadPreview(newest, incrementUnread: false);
      }
    } catch (e) {
      AppLogger.d('Background message sync failed: $e');
    } finally {
      _syncingMessages = false;
    }
  }

  // --------------------------------------------------------------------------
  // Inbox Actions
  // --------------------------------------------------------------------------

  /// Fetches all threads. [silent] = true updates in the background without spinner.
  Future<void> loadThreads({bool silent = false}) async {
    // No session: `GET /chat/threads` would 401, and the API client's 401
    // handler routes to login — so a signed-out cold start used to bounce off
    // the splash screen because this controller is constructed eagerly.
    if (myUserId <= 0) {
      if (!silent) {
        threadsState.value =
            const ApiState<List<ChatThread>>.empty(message: 'No conversations yet.');
      }
      return;
    }
    if (_loadingThreads) return;
    _loadingThreads = true;
    if (!silent && (threadsState.value.data?.isEmpty ?? true)) {
      threadsState.value = const ApiState<List<ChatThread>>.loading();
    }
    try {
      final List<ChatThread> list = await _repo.fetchThreads();
      threadsState.value = list.isEmpty
          ? const ApiState<List<ChatThread>>.empty(message: 'No conversations yet.')
          : ApiState<List<ChatThread>>.success(list);

      // Announce anything the socket and the pushes did not deliver.
      _noticeThreadPreviews(list);

      // Re-assert the user-channel subscription. Cheap when it is already live,
      // and it is the thing that has to survive a re-login.
      if (myUserId > 0) {
        _pusher.subscribeToUserChannel(myUserId);
      }
    } catch (e) {
      if (!silent) {
        threadsState.value = ApiState<List<ChatThread>>.serverError(e.toString());
      }
    } finally {
      _loadingThreads = false;
    }
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  // --------------------------------------------------------------------------
  // Active Conversation Actions
  // --------------------------------------------------------------------------

  /// Opens a conversation thread.
  Future<void> openThread(ChatThread thread) async {
    activeThread.value = thread;
    messages.clear();
    replyingTo.value = null;
    pendingAttachments.clear();
    messageInputController.clear();
    isOtherTyping.value = false;
    _currentPage = 1;
    hasMore.value = false;

    if (thread.id > 0) {
      // Reading the conversation means the tray entries for it are stale.
      NotificationService.instance.cancelThreadNotifications(thread.id);

      // Subscribe first so a message that lands during the initial fetch is
      // not missed in the gap between them.
      _pusher.subscribeToThreadChannel(thread.id);

      await loadMessages(thread.id);

      // Reset unread count locally for instant UI feedback
      if (thread.unreadCount > 0) {
        _markThreadReadLocally(thread.id);
      }
    } else {
      // Uncreated placeholder thread: show empty messages stream immediately
      messagesStatus.value = ApiStatus.success;
    }

    _retuneFallback();
  }

  /// Opens a conversation known only by its id — the path a notification tap
  /// takes for a first message from somebody new, whose thread is not in the
  /// cached inbox yet.
  Future<void> openThreadById(int threadId, {int? participantId}) async {
    if (threadId <= 0) return;
    await loadThreads(silent: true);
    final List<ChatThread> list = threadsState.value.data ?? <ChatThread>[];
    for (final ChatThread t in list) {
      if (t.id == threadId ||
          (participantId != null && t.participant.id == participantId)) {
        ChatConversationView.open(t);
        return;
      }
    }
    Get.to(() => const ChatInboxView());
  }

  /// Returns the active thread with [userId] if already created on server, else null.
  Future<ChatThread?> findExistingThreadWithUser(int userId) async {
    List<ChatThread> threads = <ChatThread>[];
    try {
      threads = await _repo.fetchThreads();
      threadsState.value = threads.isEmpty
          ? const ApiState<List<ChatThread>>.empty(message: 'No conversations yet.')
          : ApiState<List<ChatThread>>.success(threads);
    } catch (_) {
      threads = threadsState.value.data ?? <ChatThread>[];
    }

    for (final ChatThread t in threads) {
      if (t.participant.id == userId && t.id > 0) {
        return t;
      }
    }
    return null;
  }

  /// Starts or opens a conversation with a specific user by [userId].
  Future<ChatThread> startChatWithUser({
    required int userId,
    required String name,
    String? photo,
  }) async {
    final ChatThread? existing = await findExistingThreadWithUser(userId);
    if (existing != null) {
      return existing;
    }

    // No existing thread found on server: return placeholder with id = 0
    return ChatThread(
      id: 0,
      participant: ChatParticipant(
        id: userId,
        name: name,
        photo: photo,
      ),
      unreadCount: 0,
      isBlocked: false,
      createdAt: DateTime.now(),
    );
  }

  void closeThread() {
    final int threadId = activeThreadId;
    if (threadId > 0) {
      _pusher.unsubscribeThreadChannel();
    }
    activeThread.value = null;
    messages.clear();
    replyingTo.value = null;
    pendingAttachments.clear();
    messageInputController.clear();
    isOtherTyping.value = false;
    _retuneFallback();
  }

  /// Loads messages for [threadId].
  Future<void> loadMessages(int threadId, {bool silent = false}) async {
    if (threadId <= 0) {
      messagesStatus.value = ApiStatus.success;
      return;
    }
    if (!silent) {
      messagesStatus.value = ApiStatus.loading;
    }
    try {
      final ChatMessagesPage page = await _repo.fetchMessages(threadId, page: 1);
      if (activeThreadId != threadId) return;
      // Assign rather than merge: this is the authoritative first page. Any
      // optimistic bubble still in flight is preserved by re-adding it.
      final List<ChatMessage> pending =
          messages.where((ChatMessage m) => m.isPending || m.isFailed).toList();
      messages.assignAll(<ChatMessage>[...page.messages, ...pending]);
      _sortConversation();
      _currentPage = page.currentPage;
      hasMore.value = page.hasMore;
      messagesStatus.value = ApiStatus.success;
    } catch (e) {
      final String errStr = e.toString().toLowerCase();
      // If 404 Not Found (e.g. newly created thread not indexed yet), don't block user
      if (errStr.contains('404') || errStr.contains('not found')) {
        messages.clear();
        messagesStatus.value = ApiStatus.success;
      } else {
        if (!silent) {
          messagesStatus.value = ApiStatus.serverError;
        }
      }
    }
  }

  /// Loads the next page of older messages (infinite scroll up).
  Future<void> loadMoreMessages() async {
    if (isLoadingMore.value || !hasMore.value || activeThreadId <= 0) return;
    isLoadingMore.value = true;
    final int threadId = activeThreadId;
    try {
      final int nextPage = _currentPage + 1;
      final ChatMessagesPage page =
          await _repo.fetchMessages(threadId, page: nextPage);
      if (activeThreadId != threadId) return;
      _mergeIntoConversation(page.messages);
      _currentPage = page.currentPage;
      hasMore.value = page.hasMore;
    } catch (_) {} finally {
      isLoadingMore.value = false;
    }
  }

  /// Sends a message (text + optional attachments).
  ///
  /// The bubble is drawn before the request goes out and reconciled when it
  /// returns, so the conversation reacts at tap speed on any connection.
  Future<void> sendMessage() async {
    final String text = messageInputController.text.trim();
    final List<String> attachments = List<String>.from(pendingAttachments);

    if (text.isEmpty && attachments.isEmpty) return;
    if (activeThread.value == null || isSending.value) return;

    if (activeThread.value!.id <= 0) {
      AppSnackbar.info(
        'Chat is not available yet. Please send an Express Interest first to connect.',
      );
      return;
    }

    final int targetId = activeThread.value!.id;
    final int? replyId = replyingTo.value?.id;
    final ChatMessage? replySource = replyingTo.value;
    final int recipientUserId = activeThread.value!.participant.id;

    // ── Optimistic bubble ──────────────────────────────────────────────────
    final String localId = 'local-${DateTime.now().microsecondsSinceEpoch}-${_localIdSeed++}';
    final ChatMessage optimistic = ChatMessage(
      id: 0,
      threadId: targetId,
      senderId: myUserId,
      message: text,
      messageType: 'text',
      createdAt: DateTime.now(),
      replyToChatId: replyId,
      replyToMessage: replySource,
      delivery: MessageDelivery.sending,
      localId: localId,
      localAttachmentPaths: attachments,
    );
    messages.insert(0, optimistic);

    // Clear the composer straight away — this is the part that made the app
    // feel slow, because it used to wait for the round trip.
    messageInputController.clear();
    pendingAttachments.clear();
    replyingTo.value = null;

    isSending.value = true;
    try {
      final ChatMessage sent = await _repo.sendMessage(
        threadId: targetId,
        message: text,
        messageType: 'text', // Backend expects 'text' for all standard chat messages even with attachments
        replyToChatId: replyId,
        recipientUserId: recipientUserId,
        attachmentPaths: attachments,
      );

      _replaceLocal(localId, sent);

      // If this was a new thread and the server returned the created thread_id,
      // adopt it and move the realtime subscription across.
      if (sent.threadId > 0 && activeThread.value?.id != sent.threadId) {
        activeThread.value = activeThread.value!.copyWith(id: sent.threadId);
        _pusher.subscribeToThreadChannel(sent.threadId);
        _retuneFallback();
      }

      _patchThreadPreview(sent, incrementUnread: false);
    } catch (e) {
      _markLocalFailed(localId);
      AppSnackbar.error('Message not sent. Tap to retry.');
      AppLogger.w('Send failed for $localId: $e');
    } finally {
      isSending.value = false;
    }
  }

  void _replaceLocal(String localId, ChatMessage confirmed) {
    final int index = messages.indexWhere((ChatMessage m) => m.localId == localId);
    if (index < 0) {
      _mergeIntoConversation(<ChatMessage>[confirmed]);
      return;
    }
    // A broadcast may have delivered the server copy first.
    if (confirmed.id > 0 &&
        messages.any((ChatMessage m) => m.id == confirmed.id && m.localId == null)) {
      messages.removeAt(index);
      return;
    }
    messages[index] = confirmed;
    _sortConversation();
  }

  void _markLocalFailed(String localId) {
    final int index = messages.indexWhere((ChatMessage m) => m.localId == localId);
    if (index < 0) return;
    messages[index] = messages[index].copyWith(delivery: MessageDelivery.failed);
    messages.refresh();
  }

  /// Re-sends a message whose POST failed, keeping its place in the thread.
  Future<void> retryMessage(ChatMessage failed) async {
    if (!failed.isFailed || activeThreadId <= 0) return;
    messages.removeWhere((ChatMessage m) => m.localId == failed.localId);
    messageInputController.text = failed.message;
    pendingAttachments.assignAll(failed.localAttachmentPaths);
    await sendMessage();
  }

  /// Triggered on text change in the composer to broadcast typing.
  ///
  /// Throttled rather than debounced: the other side should see the indicator
  /// on the first keystroke, not 2.5s after the last one.
  void onTextChanged(String text) {
    if (activeThreadId <= 0) return;
    if (_typingThrottle?.isActive ?? false) return;
    _typingThrottle = Timer(const Duration(milliseconds: 2500), () {});
    _repo.sendTyping(activeThreadId);
  }

  void setReplyTo(ChatMessage message) {
    replyingTo.value = message;
  }

  void cancelReply() {
    replyingTo.value = null;
  }

  void addAttachment(String path) {
    if (!pendingAttachments.contains(path)) {
      pendingAttachments.add(path);
    }
  }

  void removeAttachment(String path) {
    pendingAttachments.remove(path);
  }

  // --------------------------------------------------------------------------
  // Thread Moderation Actions
  // --------------------------------------------------------------------------

  Future<void> toggleBlock() async {
    if (activeThread.value == null || activeThreadId <= 0) return;
    final ChatThread t = activeThread.value!;
    try {
      if (t.isBlocked) {
        await _repo.unblockThread(t.id);
        activeThread.value = t.copyWith(isBlocked: false);
        AppSnackbar.success('Chat unblocked.');
      } else {
        await _repo.blockThread(t.id);
        activeThread.value = t.copyWith(isBlocked: true);
        AppSnackbar.info('Chat blocked.');
      }
      loadThreads(silent: true);
    } catch (e) {
      AppSnackbar.error('Action failed: $e');
    }
  }

  Future<void> clearHistory() async {
    if (activeThread.value == null || activeThreadId <= 0) return;
    final int threadId = activeThreadId;
    try {
      await _repo.clearThread(threadId);
      messages.clear();
      AppSnackbar.success('Chat history cleared.');
      loadThreads(silent: true);
    } catch (e) {
      AppSnackbar.error('Failed to clear chat: $e');
    }
  }

  Future<void> reportChat(String reason) async {
    if (activeThread.value == null || activeThreadId <= 0) return;
    final int threadId = activeThreadId;
    try {
      await _repo.reportThread(threadId, reason: reason);
      activeThread.value = activeThread.value!.copyWith(isBlocked: true);
      AppSnackbar.success('Report submitted. Thread has been blocked.');
      loadThreads(silent: true);
    } catch (e) {
      AppSnackbar.error('Failed to submit report: $e');
    }
  }

  Future<void> deleteMessageForMe(int messageId) async {
    try {
      await _repo.deleteMessage(messageId);
      messages.removeWhere((ChatMessage m) => m.id == messageId);
      AppSnackbar.info('Message deleted.');
    } catch (e) {
      AppSnackbar.error('Could not delete message: $e');
    }
  }

  /// Clears this member's session state — called on logout so the next member
  /// does not inherit the previous one's inbox.
  void reset() {
    _ingested.clear();
    _ingestOrder.clear();
    _seededPreviews = false;
    _threadRefreshTimer?.cancel();
    _threadRefreshTimer = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _fallbackPeriod = null;
    threadsState.value = const ApiState<List<ChatThread>>.initial();
    activeThread.value = null;
    messages.clear();
    pendingAttachments.clear();
    replyingTo.value = null;
    messageInputController.clear();
    searchQuery.value = '';
    realtimeLive.value = false;
  }

  void _markThreadReadLocally(int threadId) {
    final List<ChatThread>? current = threadsState.value.data;
    if (current == null) return;
    final List<ChatThread> updated = current.map((ChatThread t) {
      if (t.id == threadId) return t.copyWith(unreadCount: 0);
      return t;
    }).toList();
    threadsState.value = ApiState<List<ChatThread>>.success(updated);
  }

  // --------------------------------------------------------------------------
  // Payload helpers
  // --------------------------------------------------------------------------

  /// Pulls a [ChatMessage] out of a realtime payload, whichever shape it takes.
  ///
  /// The backend wraps it under `message` on the thread channel and sometimes
  /// sends the row bare on the user channel; a payload with neither an id nor a
  /// thread id is some other kind of event and must not be turned into a bubble.
  ChatMessage? _messageFrom(Map<String, dynamic> data) {
    final dynamic raw = data['message'] ?? data['chat'] ?? data;
    if (raw is! Map<String, dynamic>) return null;
    final int? id = _asInt(raw['id']);
    final int? threadId = _asInt(raw['thread_id'] ?? raw['threadId'] ?? raw['chat_thread_id']);
    if (id == null || id <= 0 || threadId == null || threadId <= 0) return null;
    try {
      final ChatMessage parsed = ChatMessage.fromJson(<String, dynamic>{
        ...raw,
        'thread_id': threadId,
      });
      return parsed;
    } catch (e) {
      AppLogger.w('Unparseable realtime message payload: $e');
      return null;
    }
  }

  /// True the first time [messageId] is seen. Bounded so a long session cannot
  /// grow this without limit; the window only has to outlive the gap between
  /// the two channels delivering the same broadcast, which is milliseconds.
  bool _firstSightOf(int messageId) {
    if (messageId <= 0) return true; // no server id to key on
    if (!_ingested.add(messageId)) return false;
    _ingestOrder.add(messageId);
    while (_ingestOrder.length > _ingestWindow) {
      _ingested.remove(_ingestOrder.removeFirst());
    }
    return true;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
