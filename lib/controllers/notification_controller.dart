import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/notification_service.dart';
import '../core/services/pusher_chat_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/app_logger.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationController extends GetxController {
  final NotificationRepository _repository;

  NotificationController(this._repository);

  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxInt unreadCount = 0.obs;

  /// Which feed the notifications screen is showing. `false` = All (activity
  /// feed, server-side), `true` = Unread (server-side `unread_only=1`).
  final RxBool showUnreadOnly = false.obs;

  /// Rows already known read on the server in this session. Keeps a mark-read
  /// answer from an Unread feed consistent with the All feed without refetching.
  final Set<int> _readIds = <int>{};

  dynamic _pushTokenRecordId;

  int _currentPage = 1;
  int _lastPage = 1;

  int _unreadPage = 1;
  int _unreadLastPage = 1;

  /// Notification rows already announced in the tray.
  ///
  /// This is persisted. It used to be an in-memory set, which meant every cold
  /// start re-announced every row that was still unread — a member with five
  /// week-old unread notifications got the same five tray entries on every
  /// single launch, for as long as they never opened them. [NotificationService.claim]
  /// could not save us either: its claims live in memory with a TTL and are
  /// gone by the next launch too.
  final Set<int> _seen = <int>{};

  /// Where [_seen] is kept between launches.
  static const String _seenKey = 'notif_tray_seen_ids';

  /// Ids kept on disk. Enough to cover any realistic unread backlog without
  /// letting the list grow without bound; the oldest fall off first.
  static const int _seenCap = 500;

  /// True once [_seen] has been restored, so the first poll cannot run against
  /// an empty set and re-announce the backlog before the disk read lands.
  bool _seenLoaded = false;

  SharedPreferences? get _prefs =>
      Get.isRegistered<SharedPreferences>() ? Get.find<SharedPreferences>() : null;

  Future<void> _loadSeen() async {
    if (_seenLoaded) return;
    try {
      final List<String>? stored = _prefs?.getStringList(_seenKey);
      if (stored != null) {
        _seen.addAll(stored.map(int.tryParse).whereType<int>());
      }
    } catch (e) {
      AppLogger.w('Could not restore announced-notification ids: $e');
    } finally {
      // Even a failed read must flip this: a member is far better served by a
      // missed tray entry than by the same five buzzing at every launch.
      _seenLoaded = true;
    }
  }

  Future<void> _persistSeen() async {
    try {
      final List<int> ids = _seen.toList(growable: false);
      final List<int> capped =
          ids.length <= _seenCap ? ids : ids.sublist(ids.length - _seenCap);
      await _prefs?.setStringList(
        _seenKey,
        capped.map((int id) => '$id').toList(growable: false),
      );
    } catch (e) {
      AppLogger.w('Could not persist announced-notification ids: $e');
    }
  }

  /// Fallback poller for the tray. Slow while realtime is live (it exists only
  /// to keep the badge honest), fast while realtime is down — where it is the
  /// only way an in-app member learns about anything.
  ///
  /// It used to be a flat 15s forever, on top of the chat controller's 2.5s and
  /// 8s timers, so an idle app with the socket working perfectly still made
  /// hundreds of requests an hour.
  Timer? _trayPoller;
  Duration? _pollPeriod;
  StreamSubscription<RealtimeStatus>? _realtimeSub;

  static const Duration _pollWhileLive = Duration(seconds: 90);
  static const Duration _pollWhileDown = Duration(seconds: 15);

  bool get _hasToken =>
      Get.isRegistered<SecureStorageService>() &&
      Get.find<SecureStorageService>().hasToken;

  bool get _realtimeLive =>
      Get.isRegistered<PusherChatService>() &&
      Get.find<PusherChatService>().isConnected;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<PusherChatService>()) {
      _realtimeSub = Get.find<PusherChatService>().statusStream.listen(
        (RealtimeStatus _) => _retunePoller(),
      );
    }
    if (_hasToken) {
      fetchNotifications();
      _retunePoller();
    } else {
      AppLogger.i('NotificationController: no session yet; poller idle.');
    }
  }

  @override
  void onClose() {
    _trayPoller?.cancel();
    _realtimeSub?.cancel();
    super.onClose();
  }

  /// Called when a session appears (login, or a restored session at startup).
  void onSessionStarted() {
    if (!_hasToken) return;
    _retunePoller();
  }

  void reset() {
    notifications.clear();
    unreadCount.value = 0;
    showUnreadOnly.value = false;
    _readIds.clear();
    _currentPage = 1;
    _lastPage = 1;
    _unreadPage = 1;
    _unreadLastPage = 1;
    _pushTokenRecordId = null;
    _seen.clear();
    _seenLoaded = false;
    // A different member must not inherit the previous one's announced ids.
    unawaited(_prefs?.remove(_seenKey) ?? Future<void>.value());
    _trayPoller?.cancel();
    _trayPoller = null;
    _pollPeriod = null;
  }

  /// Sends the FCM push token to the backend API (`POST /notifications/push-tokens`).
  Future<void> syncPushToken(String token) async {
    if (!_hasToken || token.isEmpty) return;
    try {
      final String deviceType = Platform.isIOS ? 'ios' : 'android';
      final dynamic res = await _repository.registerPushToken(
        token: token,
        deviceType: deviceType,
      );
      if (res is Map && res['id'] != null) {
        _pushTokenRecordId = res['id'];
      }
      AppLogger.push('token ACCEPTED by backend (platform: $deviceType, '
          'record: ${_pushTokenRecordId ?? '?'})');
    } catch (e) {
      // Release-visible on purpose: a rejected registration is the difference
      // between a phone that rings when it is closed and one that never does,
      // and it is otherwise completely silent from the member's side.
      AppLogger.push('token REJECTED by backend: $e');
    }
  }

  /// Deletes the FCM push token from backend on logout (`DELETE /notifications/push-tokens/{id}`).
  Future<void> deletePushToken() async {
    if (_pushTokenRecordId == null) return;
    try {
      await _repository.deletePushToken(_pushTokenRecordId);
      _pushTokenRecordId = null;
      AppLogger.i('FCM Push Token deleted from backend successfully');
    } catch (e) {
      AppLogger.w('Failed to delete push token from backend: $e');
    }
  }

  // ── Tray Poller ──────────────────────────────────────────────────────────

  /// Picks the poll interval from whether the socket is delivering events.
  void _retunePoller() {
    if (!_hasToken) {
      _trayPoller?.cancel();
      _trayPoller = null;
      _pollPeriod = null;
      return;
    }

    final Duration wanted = _realtimeLive ? _pollWhileLive : _pollWhileDown;
    if (_pollPeriod == wanted && (_trayPoller?.isActive ?? false)) return;

    _trayPoller?.cancel();
    _pollPeriod = wanted;
    _trayPoller = Timer.periodic(wanted, (_) => _pollAndShowInTray());
    AppLogger.d('Notification poll every ${wanted.inSeconds}s (realtime live=$_realtimeLive)');
  }

  /// Fetches the latest unread notifications and shows each new one in the
  /// device tray as a local notification. Covers messages, interests,
  /// proposals, profile views, coin usage, and all other activity types.
  Future<void> _pollAndShowInTray() async {
    if (!_hasToken) return;
    await _loadSeen();
    try {
      final pageData = await _repository.getNotifications(page: 1);
      final List<NotificationModel> unread = pageData.notifications
          .where((NotificationModel n) => !n.isRead)
          .toList();

      AppLogger.d('Tray poller: ${pageData.notifications.length} total, ${unread.length} unread, ${unreadCount.value} badge');

      bool announced = false;
      for (final NotificationModel notif in unread) {
        if (!_seen.add(notif.id)) continue;
        announced = true;

        final String title = notif.title.isNotEmpty ? notif.title : 'HamQadam';
        final String body = notif.message.isNotEmpty
            ? notif.message
            : _defaultBody(notif.type);

        // Chat messages are not this poller's job. [ChatController] owns them
        // and keys every one on its message id, from whichever path saw it
        // first — socket, push, or its own fallback fetch. A chat notification
        // row carries no message id, so anything raised from here could only be
        // de-duplicated on the text, and this poller can run up to 90s behind
        // the socket — long enough for such a key to have expired and the
        // message to be announced a second time.
        final String lowerType = notif.type.toLowerCase();
        if (lowerType.contains('message') || lowerType.contains('chat')) {
          continue;
        }

        // The socket event and the FCM push for this same activity claim the
        // very same key, so whichever arrived first has already shown it and
        // this is a no-op — which is what stops one interest buzzing three
        // times. The server's pushes carry no notification-row id, so the key
        // is built from the fields they do share.
        if (!NotificationService.instance.claim(
          NotificationService.activityKey(
            type: notif.type,
            notifyBy: notif.notifyBy,
            infoId: notif.infoId,
          ),
        )) {
          continue;
        }

        AppLogger.i('Tray: showing notification #${notif.id} [$title] $body');

        await NotificationService.instance.showNotification(
          id: notif.id,
          title: title,
          body: body,
          // A JSON payload, so a tap routes the same way an FCM tap does. The
          // old code passed `deepLink ?? type` — a bare string the tap handler
          // could not parse, so every notification tap landed on the
          // notifications list instead of the thing it was about.
          payload: jsonEncode(<String, dynamic>{
            ...?notif.payload,
            'type': notif.type,
            'notify_by': notif.notifyBy,
            'info_id': notif.infoId,
            'thread_id': notif.infoId,
            'notification_id': notif.id,
            if (notif.deepLink != null) 'deep_link': notif.deepLink,
          }),
        );
      }

      if (announced) await _persistSeen();

      // Update badge count
      unreadCount.value = pageData.unreadCount;
    } catch (e) {
      AppLogger.w('Tray poller error: $e');
    }
  }

  /// Human-readable default body for notification types without a message.
  String _defaultBody(String type) {
    final String t = type.toLowerCase();
    if (t.contains('message') || t.contains('chat')) return 'You have a new message';
    if (t.contains('interest')) return 'You have a new interest';
    if (t.contains('proposal')) return 'You have a new proposal';
    if (t.contains('profile_view') || t.contains('view')) return 'Someone viewed your profile';
    if (t.contains('coin') || t.contains('payment')) return 'Coin activity on your account';
    if (t.contains('call')) return 'Missed call';
    return 'You have a new notification';
  }

  // ── Fetch / Pagination ──────────────────────────────────────────────────

  /// Switches the notifications screen between the All and Unread feeds.
  /// Each feed keeps its own pagination cursor; switching always refetches
  /// page 1 so a stale mix of the two never shows.
  void setUnreadOnly(bool value) {
    if (showUnreadOnly.value == value) return;
    showUnreadOnly.value = value;
    fetchNotifications(refresh: true);
  }

  /// Whether more pages remain for the feed currently on screen.
  bool get hasMorePages =>
      showUnreadOnly.value ? _unreadPage <= _unreadLastPage : _currentPage <= _lastPage;

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (!_hasToken) return;

    final bool unreadOnly = showUnreadOnly.value;

    if (refresh) {
      if (unreadOnly) {
        _unreadPage = 1;
      } else {
        _currentPage = 1;
      }
      isLoading.value = true;
    } else {
      if (unreadOnly) {
        if (_unreadPage > _unreadLastPage) return;
        isLoadingMore.value = true;
      } else {
        if (_currentPage > _lastPage) return;
        isLoadingMore.value = true;
      }
    }

    try {
      final int page = unreadOnly ? _unreadPage : _currentPage;
      final pageData = await _repository.getNotifications(page: page, unreadOnly: unreadOnly);
      if (refresh) {
        notifications.assignAll(pageData.notifications);
      } else {
        notifications.addAll(pageData.notifications);
      }
      if (pageData.unreadCount > 0 || !unreadOnly) {
        unreadCount.value = pageData.unreadCount;
      }
      if (unreadOnly) {
        _unreadLastPage = pageData.lastPage;
        _unreadPage++;
      } else {
        _lastPage = pageData.lastPage;
        _currentPage++;
      }
    } catch (e) {
      AppLogger.w('Failed to fetch notifications: $e');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  /// Marks everything read on the server, then refreshes whatever feed is on
  /// screen so the list shows the server's truth. The refresh happens even if
  /// the current feed is All — rows the member has already scrolled past keep
  /// their old state otherwise.
  Future<void> markAllAsRead() async {
    try {
      final bool success = await _repository.markAllAsRead();
      if (!success) {
        Get.snackbar('Error', 'Could not mark notifications as read. Please try again.');
        return;
      }
      unreadCount.value = 0;
      final List<int> nowRead = notifications
          .where((NotificationModel n) => !n.isRead)
          .map((NotificationModel n) => n.id)
          .toList();
      _readIds.addAll(nowRead);
      notifications.assignAll(
        notifications
            .map((NotificationModel n) => n.copyWith(readAt: n.readAt ?? DateTime.now()))
            .toList(),
      );
      await fetchNotifications(refresh: true);
    } catch (e) {
      AppLogger.w('markAllAsRead failed: $e');
      Get.snackbar('Error', 'Could not mark notifications as read. Please try again.');
    }
  }

  /// Marks a single notification read on the server. The UI flips immediately
  /// (optimistic) and is corrected by the server's row + unread count when
  /// they arrive.
  Future<void> markAsRead(int id, {bool silent = false}) async {
    final int index = notifications.indexWhere((NotificationModel element) => element.id == id);
    final bool alreadyRead = (index != -1 && notifications[index].isRead) || _readIds.contains(id);
    final NotificationModel? original = index != -1 ? notifications[index] : null;

    if (!alreadyRead) {
      _readIds.add(id);
      if (index != -1) {
        notifications[index] = notifications[index].copyWith(readAt: DateTime.now());
      }
      if (unreadCount.value > 0) unreadCount.value--;
    }

    try {
      final MarkReadResult result = await _repository.markAsRead(id);
      if (result.unreadCount > 0 || (result.notification?.isRead ?? false)) {
        unreadCount.value = result.unreadCount;
      }
      final int fresh = notifications.indexWhere((NotificationModel element) => element.id == id);
      if (fresh != -1 && !notifications[fresh].isRead) {
        notifications[fresh] = notifications[fresh].copyWith(
          readAt: result.notification?.readAt ?? DateTime.now(),
        );
      }
    } catch (e) {
      // Roll the optimistic flip back so the badge and dots stay honest.
      if (!alreadyRead) {
        _readIds.remove(id);
        final int idx = notifications.indexWhere((NotificationModel element) => element.id == id);
        if (idx != -1 && original != null) notifications[idx] = original;
        unreadCount.value++;
      }
      if (!silent) {
        Get.snackbar('Error', 'Could not mark notification as read. Please try again.');
      }
    }
  }
}
