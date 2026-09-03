import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

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

  dynamic _pushTokenRecordId;

  int _currentPage = 1;
  int _lastPage = 1;

  /// Notifications already seen locally, so the list does not re-announce them
  /// on every poll. The *tray* de-duplication is [NotificationService.claim],
  /// which is shared with the socket and push paths — this set only stops us
  /// re-asking that gate for rows we have already processed.
  final Set<int> _seen = <int>{};

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
    _currentPage = 1;
    _lastPage = 1;
    _pushTokenRecordId = null;
    _seen.clear();
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
      AppLogger.i('FCM Push Token synced to backend successfully (device: $deviceType)');
    } catch (e) {
      AppLogger.w('Failed to sync push token with backend: $e');
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
    try {
      final pageData = await _repository.getNotifications(page: 1);
      final List<NotificationModel> unread = pageData.notifications
          .where((NotificationModel n) => !n.isRead)
          .toList();

      AppLogger.d('Tray poller: ${pageData.notifications.length} total, ${unread.length} unread, ${unreadCount.value} badge');

      for (final NotificationModel notif in unread) {
        if (!_seen.add(notif.id)) continue;

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

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (!_hasToken) return;

    if (refresh) {
      _currentPage = 1;
      isLoading.value = true;
    } else {
      if (_currentPage > _lastPage) return;
      isLoadingMore.value = true;
    }

    try {
      final pageData = await _repository.getNotifications(page: _currentPage);
      if (refresh) {
        notifications.assignAll(pageData.notifications);
      } else {
        notifications.addAll(pageData.notifications);
      }
      unreadCount.value = pageData.unreadCount;
      _lastPage = pageData.lastPage;
      _currentPage++;
    } catch (e) {
      AppLogger.w('Failed to fetch notifications: $e');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final success = await _repository.markAllAsRead();
      if (success) {
        for (var i = 0; i < notifications.length; i++) {
          notifications[i] = NotificationModel(
            id: notifications[i].id,
            type: notifications[i].type,
            title: notifications[i].title,
            message: notifications[i].message,
            deepLink: notifications[i].deepLink,
            notifyBy: notifications[i].notifyBy,
            infoId: notifications[i].infoId,
            payload: notifications[i].payload,
            readAt: DateTime.now(),
            createdAt: notifications[i].createdAt,
          );
        }
        unreadCount.value = 0;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to mark all as read');
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final index = notifications.indexWhere((element) => element.id == id);
      if (index != -1 && !notifications[index].isRead) {
        final success = await _repository.markAsRead(id);
        if (success) {
          notifications[index] = NotificationModel(
            id: notifications[index].id,
            type: notifications[index].type,
            title: notifications[index].title,
            message: notifications[index].message,
            deepLink: notifications[index].deepLink,
            notifyBy: notifications[index].notifyBy,
            infoId: notifications[index].infoId,
            payload: notifications[index].payload,
            readAt: DateTime.now(),
            createdAt: notifications[index].createdAt,
          );
          if (unreadCount.value > 0) {
            unreadCount.value--;
          }
        }
      }
    } catch (e) {
      // Background operation, silently fail
    }
  }
}
