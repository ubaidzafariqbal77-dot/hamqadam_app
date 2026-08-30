// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../core/services/call_signaling_service.dart';
import '../core/services/pusher_chat_service.dart';

import '../core/storage/current_user_service.dart';
import '../models/chat_model.dart';
import '../repositories/chat_repository.dart';
import '../widgets/app_snackbar.dart';

/// Full GetX Controller for the Chat feature.
/// Manages both the conversation inbox and active real-time message stream
/// powered by Pusher WebSocket and high-frequency active heartbeat sync.
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
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final Rx<ApiStatus> messagesStatus = ApiStatus.initial.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  int _currentPage = 1;

  final RxBool isOtherTyping = false.obs;
  Timer? _typingResetTimer;
  Timer? _sendTypingDebounce;

  // Realtime Poller / Heartbeat Timers
  Timer? _activeThreadHeartbeat;
  Timer? _inboxHeartbeat;
  bool _isSyncing = false;

  final Rxn<ChatMessage> replyingTo = Rxn<ChatMessage>();
  final RxBool isSending = false.obs;
  final RxList<String> pendingAttachments = <String>[].obs;

  final TextEditingController messageInputController = TextEditingController();

  int get myUserId => _currentUser.user?.id ?? 0;

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    _setupPusherListeners();
    loadThreads();
    _startInboxHeartbeat();
  }

  @override
  void onClose() {
    searchController.dispose();
    messageInputController.dispose();
    _typingResetTimer?.cancel();
    _sendTypingDebounce?.cancel();
    _stopActiveThreadHeartbeat();
    _inboxHeartbeat?.cancel();
    _pusher.disconnect();
    super.onClose();
  }

  // --------------------------------------------------------------------------
  // Pusher Realtime Setup
  // --------------------------------------------------------------------------

  void _setupPusherListeners() {
    _pusher.onUserEvent = (Map<String, dynamic> data) {
      // Inbox / preview update on App.User.{userId}
      loadThreads(silent: true);
    };

    _pusher.onThreadMessage = (Map<String, dynamic> data) {
      // Incoming message on chat-thread.{threadId}
      _handleIncomingMessage(data);
    };

    _pusher.onThreadTyping = (Map<String, dynamic> data) {
      final int? senderId = data['sender_id'] as int? ?? data['user_id'] as int?;
      if (senderId != null && senderId != myUserId) {
        isOtherTyping.value = true;
        _typingResetTimer?.cancel();
        _typingResetTimer = Timer(const Duration(seconds: 3), () {
          isOtherTyping.value = false;
        });
      }
    };

    _pusher.onThreadUpdated = (Map<String, dynamic> data) {
      if (activeThread.value != null && activeThread.value!.id > 0) {
        _syncLatestMessages(activeThread.value!.id);
      }
      loadThreads(silent: true);
    };

    // Subscribe to user channel
    if (myUserId > 0) {
      _pusher.subscribeToUserChannel(myUserId);
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final dynamic rawMsg = data['message'] ?? data;
      if (rawMsg is Map<String, dynamic>) {
        final ChatMessage msg = ChatMessage.fromJson(rawMsg);
        // Always check for call signals, regardless of which thread
        CallSignalingService.instance.handleIncomingSignal(
          message: msg.message,
          senderId: msg.senderId,
          threadId: msg.threadId,
          senderName: msg.senderName,
          senderPhoto: msg.senderPhoto,
        );
        if (activeThread.value != null &&
            (msg.threadId == activeThread.value!.id || activeThread.value!.id == 0)) {
          // Avoid duplicate appends
          if (!messages.any((ChatMessage m) => m.id == msg.id)) {
            messages.insert(0, msg);
          }
        }
        // Also refresh the inbox preview
        loadThreads(silent: true);
      }
    } catch (e) {
      // Log but don't crash — background message handling must be resilient
      debugPrint('ChatController._handleIncomingMessage error: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Heartbeat Polling Engine (Active Realtime Sync)
  // --------------------------------------------------------------------------

  void _startActiveThreadHeartbeat(int threadId) {
    _stopActiveThreadHeartbeat();
    // High-frequency 2.5s polling loop while conversation is open
    _activeThreadHeartbeat = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (activeThread.value != null && activeThread.value!.id > 0) {
        _syncLatestMessages(activeThread.value!.id);
      }
    });
  }

  void _stopActiveThreadHeartbeat() {
    _activeThreadHeartbeat?.cancel();
    _activeThreadHeartbeat = null;
  }

  void _startInboxHeartbeat() {
    _inboxHeartbeat?.cancel();
    // 8-second background inbox refresh
    _inboxHeartbeat = Timer.periodic(const Duration(seconds: 8), (_) {
      if (myUserId > 0 && (activeThread.value == null)) {
        loadThreads(silent: true);
      }
    });
  }

  /// Silently syncs new incoming messages into the active conversation.
  Future<void> _syncLatestMessages(int threadId) async {
    if (_isSyncing || threadId <= 0) return;
    _isSyncing = true;
    try {
      final ChatMessagesPage page = await _repo.fetchMessages(threadId, page: 1, perPage: 20);
      final List<ChatMessage> fetched = page.messages;
      if (fetched.isEmpty) return;

      bool hasNew = false;
      // Invert to insert in chronological order
      for (final ChatMessage msg in fetched.reversed) {
        if (!messages.any((ChatMessage m) => m.id == msg.id)) {
          messages.insert(0, msg);
          hasNew = true;
          CallSignalingService.instance.handleIncomingSignal(
            message: msg.message,
            senderId: msg.senderId,
            threadId: msg.threadId,
            senderName: msg.senderName,
            senderPhoto: msg.senderPhoto,
          );
        }
      }

      if (hasNew) {
        // Refresh inbox previews quietly
        loadThreads(silent: true);
      }
    } catch (_) {
      // Background sync errors are non-fatal
    } finally {
      _isSyncing = false;
    }
  }

  // --------------------------------------------------------------------------
  // Inbox Actions
  // --------------------------------------------------------------------------

  /// Fetches all threads. [silent] = true updates in the background without spinner.
  Future<void> loadThreads({bool silent = false}) async {
    if (!silent) {
      threadsState.value = const ApiState<List<ChatThread>>.loading();
    }
    try {
      final List<ChatThread> list = await _repo.fetchThreads();
      threadsState.value = list.isEmpty
          ? const ApiState<List<ChatThread>>.empty(message: 'No conversations yet.')
          : ApiState<List<ChatThread>>.success(list);

      // Check for incoming call signals in threads with recent messages.
      // We check ALL threads (not just unread) because the call invite might
      // arrive before the unread count is updated by the backend.
      for (final ChatThread thread in list) {
        if (thread.lastMessage != null) {
          CallSignalingService.instance.handleIncomingSignal(
            message: thread.lastMessage!.message,
            senderId: thread.lastMessage!.senderId,
            threadId: thread.id,
            senderName: thread.participant.name,
            senderPhoto: thread.participant.photo,
          );
        }
      }

      // Re-verify user channel subscription
      if (myUserId > 0) {
        _pusher.subscribeToUserChannel(myUserId);
      }
    } catch (e) {
      if (!silent) {
        threadsState.value = ApiState<List<ChatThread>>.serverError(e.toString());
      }
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
    _currentPage = 1;
    hasMore.value = false;

    if (thread.id > 0) {
      // Subscribe to realtime thread stream
      await _pusher.subscribeToThreadChannel(thread.id);

      // Load initial messages
      await loadMessages(thread.id);

      // Start active conversation realtime heartbeat
      _startActiveThreadHeartbeat(thread.id);

      // Reset unread count locally for instant UI feedback
      if (thread.unreadCount > 0) {
        _markThreadReadLocally(thread.id);
      }
    } else {
      // Uncreated placeholder thread: show empty messages stream immediately
      messagesStatus.value = ApiStatus.success;
    }
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
    _stopActiveThreadHeartbeat();
    if (activeThread.value != null && activeThread.value!.id > 0) {
      _pusher.unsubscribeThreadChannel();
    }
    activeThread.value = null;
    messages.clear();
    replyingTo.value = null;
    pendingAttachments.clear();
    messageInputController.clear();
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
      messages.assignAll(page.messages);
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
    if (isLoadingMore.value || !hasMore.value || activeThread.value == null || activeThread.value!.id <= 0) return;
    isLoadingMore.value = true;
    try {
      final int nextPage = _currentPage + 1;
      final ChatMessagesPage page =
          await _repo.fetchMessages(activeThread.value!.id, page: nextPage);
      messages.addAll(page.messages);
      _currentPage = page.currentPage;
      hasMore.value = page.hasMore;
    } catch (_) {} finally {
      isLoadingMore.value = false;
    }
  }

  /// Sends a message (text + optional attachments).
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
    final int recipientUserId = activeThread.value!.participant.id;

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

      // If this was a new thread (id <= 0) and the server returned the created thread_id,
      // update activeThread, start heartbeat and subscribe to the real thread channel
      if (sent.threadId > 0 && (activeThread.value?.id == 0 || activeThread.value?.id != sent.threadId)) {
        activeThread.value = activeThread.value!.copyWith(
          id: sent.threadId,
        );
        _pusher.subscribeToThreadChannel(sent.threadId);
        _startActiveThreadHeartbeat(sent.threadId);
      }

      // Append locally immediately
      if (!messages.any((ChatMessage m) => m.id == sent.id)) {
        messages.insert(0, sent);
      }

      // Clear composer state
      messageInputController.clear();
      pendingAttachments.clear();

      replyingTo.value = null;

      // Update thread preview in inbox
      loadThreads(silent: true);
    } catch (e) {
      AppSnackbar.error('Failed to send message: $e');
    } finally {
      isSending.value = false;
    }
  }

  /// Triggered on text change in the composer to broadcast typing.
  void onTextChanged(String text) {
    if (activeThread.value == null || activeThread.value!.id <= 0) return;
    if (_sendTypingDebounce?.isActive ?? false) return;

    _sendTypingDebounce = Timer(const Duration(milliseconds: 2500), () {});
    _repo.sendTyping(activeThread.value!.id);
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
    if (activeThread.value == null || activeThread.value!.id <= 0) return;
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
    if (activeThread.value == null || activeThread.value!.id <= 0) return;
    final int threadId = activeThread.value!.id;
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
    if (activeThread.value == null || activeThread.value!.id <= 0) return;
    final int threadId = activeThread.value!.id;
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

  void _markThreadReadLocally(int threadId) {
    final List<ChatThread>? current = threadsState.value.data;
    if (current == null) return;
    final List<ChatThread> updated = current.map((ChatThread t) {
      if (t.id == threadId) return t.copyWith(unreadCount: 0);
      return t;
    }).toList();
    threadsState.value = ApiState<List<ChatThread>>.success(updated);
  }
}
