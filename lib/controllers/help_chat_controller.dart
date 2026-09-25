// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../core/services/pusher_chat_service.dart';
import '../core/storage/current_user_service.dart';
import '../core/utils/app_logger.dart';
import '../models/chat_model.dart' show MessageDelivery;
import '../models/help_chat_model.dart';
import '../repositories/help_chat_repository.dart';
import '../widgets/app_snackbar.dart';

/// GetX controller for the HamQadam Help Center chat.
///
/// Mirrors [ChatController]'s shape on purpose: optimistic send bubbles,
/// realtime-first delivery with the network only touched when the socket has
/// something to tell us, and a fallback poller whose period follows the
/// socket's actual state.
///
/// One difference matters: there is exactly ONE conversation per member, so
/// there is no inbox to patch — realtime messages either land in the open
/// view or raise a notification, nothing else.
class HelpChatController extends GetxController {
  HelpChatController({
    required HelpChatRepository repository,
    required PusherChatService pusher,
    required CurrentUserService currentUser,
  })  : _repo = repository,
        _pusher = pusher,
        _currentUser = currentUser;

  final HelpChatRepository _repo;
  final PusherChatService _pusher;
  final CurrentUserService _currentUser;

  // ── State ────────────────────────────────────────────────────────────────

  final Rx<ApiState<HelpChatThread>> threadState =
      const ApiState<HelpChatThread>.initial().obs;

  /// Newest first — drawn with `reverse: true` like the member chat.
  final RxList<HelpChatMessage> messages = <HelpChatMessage>[].obs;
  final Rx<ApiStatus> messagesStatus = ApiStatus.initial.obs;
  final RxBool isSending = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  int _currentPage = 1;

  final TextEditingController messageInputController = TextEditingController();
  final RxList<String> pendingAttachments = <String>[].obs;

  int get myUserId => _currentUser.user?.id ?? 0;
  int get threadId => threadState.value.data?.id ?? 0;

  @override
  bool get isClosed => threadState.value.data?.isClosed ?? false;

  /// Unread help replies — the drawer badge reads this.
  final RxInt unreadCount = 0.obs;

  /// Whether the Help conversation is on screen right now. State-based
  /// rather than route-based: GetX names unnamed routes after the widget
  /// class, which is an implementation detail a rename would silently break.
  final RxBool isViewOpen = false.obs;

  // ── Realtime plumbing ────────────────────────────────────────────────────

  StreamSubscription<RealtimeStatus>? _statusSub;
  Timer? _fallbackTimer;
  Duration? _fallbackPeriod;
  bool _foreground = true;
  bool _loadingThread = false;
  int _localIdSeed = 0;

  /// Server message ids already applied, so a broadcast that arrives on both
  /// the help channel and the user channel is counted once.
  final Set<int> _ingested = <int>{};
  final Queue<int> _ingestOrder = Queue<int>();
  static const int _ingestWindow = 500;

  @override
  void onInit() {
    super.onInit();
    _pusher.onHelpChatMessage = _handleRealtimeMessage;
    _statusSub = _pusher.statusStream.listen((_) => _retuneFallback());
  }

  @override
  void onClose() {
    _statusSub?.cancel();
    _fallbackTimer?.cancel();
    messageInputController.dispose();
    super.onClose();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Loads (or creates) the conversation and its messages, then subscribes.
  /// Called when the Help view opens.
  Future<void> openHelpChat() async {
    if (_loadingThread || myUserId <= 0) return;
    _loadingThread = true;
    if (threadState.value.data == null) {
      threadState.value = const ApiState<HelpChatThread>.loading();
    }
    try {
      final HelpChatThread thread = await _repo.fetchThread();
      threadState.value = ApiState<HelpChatThread>.success(thread);
      unreadCount.value = thread.unreadCount;

      // Subscribe before the message fetch, so a reply landing in the gap
      // between the two is not missed.
      if (thread.id > 0) {
        _pusher.subscribeToHelpChannel(thread.id);
      }
      await loadMessages();
    } catch (e) {
      threadState.value = ApiState<HelpChatThread>.serverError(e.toString());
    } finally {
      _loadingThread = false;
    }
    _retuneFallback();
  }

  /// Leaves the conversation view: unsubscribe, stop polling.
  void closeHelpChat() {
    if (threadId > 0) {
      _pusher.unsubscribeHelpChannel();
    }
    _fallbackTimer?.cancel();
    _fallbackPeriod = null;
  }

  /// Clears this member's state on logout.
  void reset() {
    _ingested.clear();
    _ingestOrder.clear();
    _fallbackTimer?.cancel();
    _fallbackPeriod = null;
    threadState.value = const ApiState<HelpChatThread>.initial();
    messages.clear();
    pendingAttachments.clear();
    messageInputController.clear();
    unreadCount.value = 0;
  }

  // ── Messages ─────────────────────────────────────────────────────────────

  Future<void> loadMessages({bool silent = false}) async {
    if (threadId <= 0) {
      messagesStatus.value = ApiStatus.success;
      return;
    }
    if (!silent) messagesStatus.value = ApiStatus.loading;
    try {
      final HelpChatMessagesPage page = await _repo.fetchMessages(page: 1);
      if (page.messages.isEmpty) {
        messages.clear();
      } else {
        final List<HelpChatMessage> pending =
            messages.where((HelpChatMessage m) => m.isPending || m.isFailed).toList();
        messages.assignAll(<HelpChatMessage>[...page.messages, ...pending]);
        _sortMessages();
      }
      _currentPage = page.currentPage;
      hasMore.value = page.hasMore;
      if (!silent) messagesStatus.value = ApiStatus.success;
    } catch (e) {
      AppLogger.d('Help chat load failed: $e');
      if (!silent) messagesStatus.value = ApiStatus.serverError;
    }
  }

  Future<void> loadMoreMessages() async {
    if (isLoadingMore.value || !hasMore.value || threadId <= 0) return;
    isLoadingMore.value = true;
    try {
      final HelpChatMessagesPage page =
          await _repo.fetchMessages(page: _currentPage + 1);
      _mergeIntoConversation(page.messages);
      _currentPage = page.currentPage;
      hasMore.value = page.hasMore;
    } catch (_) {
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Sends the member's issue / reply with an optimistic bubble.
  Future<void> sendMessage() async {
    final String text = messageInputController.text.trim();
    final List<String> attachments = List<String>.from(pendingAttachments);
    if (text.isEmpty && attachments.isEmpty) return;
    if (isClosed) {
      AppSnackbar.info(
        'This conversation was closed by support. Please start a new one.',
      );
      return;
    }
    if (isSending.value) return;

    final String localId =
        'local-help-${DateTime.now().microsecondsSinceEpoch}-${_localIdSeed++}';
    final HelpChatMessage optimistic = HelpChatMessage(
      id: 0,
      threadId: threadId,
      senderId: myUserId,
      fromAdmin: false,
      message: text,
      messageType: attachments.isNotEmpty ? 'file' : 'text',
      createdAt: DateTime.now(),
      delivery: MessageDelivery.sending,
      localId: localId,
      localAttachmentPaths: attachments,
    );
    messages.insert(0, optimistic);

    messageInputController.clear();
    pendingAttachments.clear();

    isSending.value = true;
    try {
      final HelpChatMessage sent = await _repo.sendMessage(
        message: text,
        attachmentPaths: attachments,
      );
      _replaceLocal(localId, sent);
    } catch (e) {
      _markLocalFailed(localId);
      AppSnackbar.error('Message not sent. Tap to retry.');
      AppLogger.w('Help chat send failed for $localId: $e');
    } finally {
      isSending.value = false;
    }
  }

  /// Re-sends a failed message.
  Future<void> retryMessage(HelpChatMessage failed) async {
    if (!failed.isFailed) return;
    messages.removeWhere((HelpChatMessage m) => m.localId == failed.localId);
    messageInputController.text = failed.message;
    pendingAttachments.assignAll(failed.localAttachmentPaths);
    await sendMessage();
  }

  void addAttachment(String path) {
    if (!pendingAttachments.contains(path)) pendingAttachments.add(path);
  }

  void removeAttachment(String path) {
    pendingAttachments.remove(path);
  }

  // ── Realtime handlers ────────────────────────────────────────────────────

  void _handleRealtimeMessage(Map<String, dynamic> data) {
    final HelpChatMessage? msg = _messageFrom(data);
    if (msg == null) return;

    // Same broadcast on two channels; only the first copy counts.
    if (!_firstSightOf(msg.id)) return;

    if (msg.fromAdmin) {
      unreadCount.value += 1;
    }

    final bool isOpen = isViewOpen.value;
    if (isOpen && _foreground) {
      _mergeIntoConversation(<HelpChatMessage>[msg]);
      unreadCount.value = 0;
      return;
    }

    // Not looking at the conversation: merge silently if already loaded, and
    // let the FCM push / notification path announce it.
    if (threadId == msg.threadId) {
      _mergeIntoConversation(<HelpChatMessage>[msg]);
    }
  }

  /// Entry point for the FCM push (`type: help_chat`) sent by the backend.
  void syncFromPush() {
    _scheduleSync();
  }

  Timer? _syncTimer;
  void _scheduleSync() {
    if (_syncTimer?.isActive ?? false) return;
    _syncTimer = Timer(const Duration(milliseconds: 300), () {
      _syncTimer = null;
      loadMessages(silent: true);
    });
  }

  // ── Local state patching ─────────────────────────────────────────────────

  bool _mergeIntoConversation(Iterable<HelpChatMessage> incoming) {
    final Set<int> known = messages
        .where((HelpChatMessage m) => m.id > 0)
        .map((HelpChatMessage m) => m.id)
        .toSet();

    final List<HelpChatMessage> fresh = <HelpChatMessage>[];
    for (final HelpChatMessage m in incoming) {
      if (m.id > 0 && known.contains(m.id)) continue;
      known.add(m.id);
      fresh.add(m);
    }
    if (fresh.isEmpty) return false;

    // An echo of a message this device just sent replaces the optimistic one.
    for (final HelpChatMessage m in fresh) {
      if (m.fromAdmin || m.senderId != myUserId) continue;
      final int pendingIndex =
          messages.indexWhere((HelpChatMessage p) => p.isPending && p.message == m.message);
      if (pendingIndex >= 0) messages.removeAt(pendingIndex);
    }

    messages.addAll(fresh);
    _sortMessages();
    return true;
  }

  void _sortMessages() {
    messages.sort((HelpChatMessage a, HelpChatMessage b) {
      final int byTime = b.createdAt.compareTo(a.createdAt);
      if (byTime != 0) return byTime;
      return b.id.compareTo(a.id);
    });
    messages.refresh();
  }

  void _replaceLocal(String localId, HelpChatMessage confirmed) {
    final int index = messages.indexWhere((HelpChatMessage m) => m.localId == localId);
    if (index < 0) {
      _mergeIntoConversation(<HelpChatMessage>[confirmed]);
      return;
    }
    if (confirmed.id > 0 &&
        messages.any((HelpChatMessage m) => m.id == confirmed.id && m.localId == null)) {
      messages.removeAt(index);
      return;
    }
    messages[index] = confirmed;
    _sortMessages();
  }

  void _markLocalFailed(String localId) {
    final int index = messages.indexWhere((HelpChatMessage m) => m.localId == localId);
    if (index < 0) return;
    messages[index] = messages[index].copyWith(delivery: MessageDelivery.failed);
    messages.refresh();
  }

  // ── Fallback polling ─────────────────────────────────────────────────────

  /// Adaptive poll: fast while realtime is down (seconds), a slow reconcile
  /// while it is up, nothing in the background.
  void _retuneFallback() {
    if (!_foreground || myUserId <= 0 || threadId <= 0) {
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
      _fallbackPeriod = null;
      return;
    }

    final Duration wanted = _pusher.isConnected
        ? const Duration(seconds: 60)
        : const Duration(seconds: 6);
    if (_fallbackPeriod == wanted && (_fallbackTimer?.isActive ?? false)) return;

    _fallbackTimer?.cancel();
    _fallbackPeriod = wanted;
    _fallbackTimer = Timer.periodic(wanted, (_) => loadMessages(silent: true));
  }

  /// Fetches whatever happened while the socket was down.
  Future<void> catchUp() async {
    if (myUserId <= 0 || threadId <= 0) return;
    await loadMessages(silent: true);
  }

  /// Called by the app lifecycle when the app returns to the foreground.
  void onAppResumed() {
    _foreground = true;
    _retuneFallback();
    catchUp();
  }

  void onAppBackgrounded() {
    _foreground = false;
    _retuneFallback();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  HelpChatMessage? _messageFrom(Map<String, dynamic> data) {
    final dynamic raw = data['message'] ?? data['help_message'] ?? data;
    if (raw is! Map<String, dynamic>) return null;
    final int? id = _asInt(raw['id']);
    final int? msgThreadId = _asInt(raw['thread_id'] ?? raw['threadId']);
    if (id == null || id <= 0) return null;
    try {
      return HelpChatMessage.fromJson(<String, dynamic>{
        ...raw,
        if (msgThreadId != null) 'thread_id': msgThreadId,
        'from_admin': raw['from_admin'] ?? data['from_admin'] ?? false,
      });
    } catch (e) {
      AppLogger.w('Unparseable help chat payload: $e');
      return null;
    }
  }

  bool _firstSightOf(int messageId) {
    if (messageId <= 0) return true;
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
