// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/notification_controller.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';
import 'notification_service.dart';

/// Gets the FCM device token and makes sure the backend has it.
///
/// ## Why this is a service and not three lines in `main()`
///
/// It used to be three lines in `main()`, and they lost the race almost every
/// time. `getToken()` was fired before `AppDependencies.init()` had run, so
/// when the future completed `Get.isRegistered<NotificationController>()` was
/// still false and the token was only cached in memory. `AuthController`
/// re-sent it from `_refreshAuthenticatedServices()`, but for an already
/// logged-in member that runs *inside* dependency init — i.e. before the token
/// exists. The net effect on a warm start was a member with a valid session and
/// no device token on the server, which is a phone that can never be pushed:
/// no message notification and no call while the app is closed.
///
/// So: the token is fetched with retries, remembered across restarts, and
/// pushed to the server whenever a session appears, whenever the token rotates,
/// and whenever the app comes back to the foreground.
class PushTokenService {
  PushTokenService({
    required SharedPreferences prefs,
    required SecureStorageService storage,
  })  : _prefs = prefs,
        _storage = storage;

  final SharedPreferences _prefs;
  final SecureStorageService _storage;

  static const String _lastSyncedTokenKey = 'fcm_last_synced_token_v1';

  /// Re-register even an unchanged token this often.
  ///
  /// Deliberately short, because this device is **not the only writer** of the
  /// token the server pushes to. Every sender reads `users.fcm_token`, a single
  /// column, and the website writes it too — `HomeController::updateToken`
  /// stores whatever `fcm_token` the browser posts, with no validation. So a
  /// member who opens the site on a desktop replaces the phone's token with the
  /// browser's, and from then on every push to that member is answered by
  /// Google with
  ///
  ///     400 "The registration token is not a valid FCM registration token"
  ///
  /// which is invisible from the phone: the app still gets everything over the
  /// socket while it is open, and goes completely silent once it is closed.
  ///
  /// Re-asserting on every resume is what wins the column back. It is one small
  /// idempotent POST, so the floor only exists to stop a flapping network from
  /// repeating it. The real fix is server-side — see backend_patches/README.md,
  /// "users.fcm_token is one column".
  static const Duration _resyncInterval = Duration(minutes: 5);
  static const String _lastSyncedAtKey = 'fcm_last_synced_at_v1';

  String? _token;
  bool _listening = false;
  Timer? _retryTimer;
  int _attempt = 0;
  Future<void>? _syncing;

  String? get token => _token;

  /// Fetches the token and starts watching for rotations. Safe to call twice.
  Future<void> start() async {
    if (!_listening) {
      _listening = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((String fresh) {
        if (fresh.isEmpty) return;
        AppLogger.i('FCM token rotated.');
        _token = fresh;
        NotificationService.instance.cachedFcmToken = fresh;
        // A rotated token is a different device row; the old one is dead.
        _prefs.remove(_lastSyncedTokenKey);
        ensureSynced(force: true);
      });
    }
    if (await _acquireToken()) await ensureSynced();
  }

  /// Reads the token from FCM, retrying on its own schedule until it has one.
  ///
  /// Deliberately does **not** send it: acquiring and registering are separate
  /// steps because they used to be one, and the two re-entered each other into
  /// a deadlock. `ensureSynced()` with no token called `_fetchToken()`, which on
  /// success called `ensureSynced()` again — and that returned the still-running
  /// outer future from the `_syncing` guard instead of doing anything. The
  /// outer call then returned as well, so **the token was never POSTed**: the
  /// log showed "FCM token acquired" twice and no sync at all, and a member's
  /// device stayed unreachable while the app was closed.
  Future<bool> _acquireToken() async {
    _retryTimer?.cancel();
    try {
      // iOS hands out an FCM token only once APNs has registered the device,
      // which is a network round trip after launch. Asking too early throws,
      // and the old code treated that as "no push on iOS, never mind".
      if (Platform.isIOS) {
        final String? apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns == null || apns.isEmpty) {
          throw StateError('APNs token not issued yet');
        }
      }

      final String? fresh = await FirebaseMessaging.instance.getToken();
      if (fresh == null || fresh.isEmpty) {
        throw StateError('FCM returned an empty token');
      }

      _attempt = 0;
      _token = fresh;
      NotificationService.instance.cachedFcmToken = fresh;
      AppLogger.i('FCM token acquired (${fresh.substring(0, 12)}…)');
      return true;
    } catch (e) {
      _attempt++;
      if (_attempt > 8) {
        AppLogger.w('Giving up on the FCM token after $_attempt attempts: $e');
        return false;
      }
      // 3s, 6s, 12s, 24s, 48s, 60s… — an APNs registration or a cold network
      // usually lands inside the first couple of these.
      final int seconds = (3 * (1 << (_attempt - 1))).clamp(3, 60);
      AppLogger.i('FCM token not ready ($e); retrying in ${seconds}s.');
      _retryTimer = Timer(Duration(seconds: seconds), () async {
        if (await _acquireToken()) await ensureSynced(force: true);
      });
      return false;
    }
  }

  /// Registers the token with the backend if it is not already registered.
  ///
  /// Called after login, on every resume, and after the token is first read.
  /// Cheap when there is nothing to do: it compares against what was last
  /// accepted and does nothing unless something changed or the re-sync window
  /// has passed.
  Future<void> ensureSynced({bool force = false}) {
    final Future<void>? running = _syncing;
    if (running != null) return running;
    final Future<void> attempt = _sync(force: force);
    _syncing = attempt;
    return attempt.whenComplete(() {
      if (identical(_syncing, attempt)) _syncing = null;
    });
  }

  Future<void> _sync({required bool force}) async {
    // Acquire first if we do not have one yet, then carry straight on to the
    // POST. Returning here instead — which is what it used to do — meant the
    // very first sync of a session never sent anything.
    if (_token == null || _token!.isEmpty) {
      await _acquireToken();
    }

    final String? token = _token;
    if (token == null || token.isEmpty) return; // retry loop will come back
    if (!_storage.hasToken) {
      AppLogger.i('FCM token held back: no session to attach it to yet.');
      return;
    }
    if (!Get.isRegistered<NotificationController>()) return;

    if (!force && _prefs.getString(_lastSyncedTokenKey) == token) {
      final int? at = _prefs.getInt(_lastSyncedAtKey);
      final Duration since = at == null
          ? _resyncInterval
          : DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(at));
      if (since < _resyncInterval) return;
    }

    AppLogger.i('Registering the FCM token with the backend…');
    await Get.find<NotificationController>().syncPushToken(token);
    await _prefs.setString(_lastSyncedTokenKey, token);
    await _prefs.setInt(
      _lastSyncedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Forgets the local record so the next login re-registers from scratch.
  Future<void> forgetSync() async {
    await _prefs.remove(_lastSyncedTokenKey);
    await _prefs.remove(_lastSyncedAtKey);
  }

  void dispose() {
    _retryTimer?.cancel();
  }
}
