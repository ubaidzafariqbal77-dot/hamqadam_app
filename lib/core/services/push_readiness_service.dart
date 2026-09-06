import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';
import 'notification_service.dart';
import 'permissions_service.dart';

/// What Android currently allows this install to do about a closed app.
class PushReadiness {
  const PushReadiness({
    required this.notificationsBlocked,
    required this.fullScreenBlocked,
    required this.batteryOptimised,
  });

  /// POST_NOTIFICATIONS denied. Total: Android drops every tray entry, so
  /// nothing arrives unless the app is open with the socket connected.
  final bool notificationsBlocked;

  /// Android 14+ has not granted the full-screen-intent. The call push still
  /// arrives and the tray still rings, but it cannot take over a locked screen.
  final bool fullScreenBlocked;

  /// Still battery-optimised, so the OEM cleaner is free to force-stop the app
  /// — and a force-stopped app is delivered no FCM at all.
  final bool batteryOptimised;

  bool get isReady =>
      !notificationsBlocked && !fullScreenBlocked && !batteryOptimised;

  /// Nothing at all can arrive while the app is closed.
  bool get isPushDead => notificationsBlocked;

  @override
  String toString() => 'PushReadiness(notificationsBlocked: '
      '$notificationsBlocked, fullScreenBlocked: $fullScreenBlocked, '
      'batteryOptimised: $batteryOptimised)';
}

/// Reads — and helps the member repair — the device-side grants that decide
/// whether messages and calls arrive while the app is not open.
///
/// ## Why this exists
///
/// Everything about push can be correct on the server, in the payload and in
/// the app, and a given phone can still be silent, because three grants sit
/// between an FCM message and the member. None of them can be forced from
/// code, none of them report themselves in release builds (`AppLogger` is
/// `kDebugMode`-only), and one of them — POST_NOTIFICATIONS — is unaskable a
/// second time once permanently denied.
///
/// That combination is what made this look like a backend bug for weeks: a
/// clean install whose member answered "Don't allow" to the notification prompt
/// behaves *exactly* like a broken server, except in the foreground, where the
/// Pusher socket keeps working and hides it.
///
/// So the app states its own condition instead of guessing: [check] reads the
/// real OS state, and [prompt] offers the member the one or two taps that fix
/// it.
class PushReadinessService {
  PushReadinessService({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const String _lastPromptKey = 'push_readiness_prompted_at_v1';

  /// How long to leave a member alone after showing them the prompt, when the
  /// app still works in the foreground. A dead push path ignores this — see
  /// [shouldPrompt].
  static const Duration _promptInterval = Duration(days: 1);

  Future<PushReadiness> check() async {
    final bool notifications = await PermissionsService.instance.notificationsBlocked;
    final bool fullScreen = !(await NotificationService.instance.canRingFullScreen);
    final bool battery =
        !(await NotificationService.instance.isIgnoringBatteryOptimizations);

    final PushReadiness state = PushReadiness(
      notificationsBlocked: notifications,
      fullScreenBlocked: fullScreen,
      batteryOptimised: battery,
    );
    AppLogger.i('Push readiness: $state');
    return state;
  }

  /// Whether the member should be shown [state] now.
  ///
  /// A blocked notification permission is asked about on every launch, because
  /// until it is fixed the app cannot deliver anything while it is closed and
  /// there is no other way for the member to find out. The softer two are
  /// rate-limited, so a member who has decided to live with them is not nagged.
  bool shouldPrompt(PushReadiness state) {
    if (state.isReady) return false;
    if (state.isPushDead) return true;

    final int? at = _prefs.getInt(_lastPromptKey);
    if (at == null) return true;
    final Duration since =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    return since >= _promptInterval;
  }

  Future<void> markPrompted() =>
      _prefs.setInt(_lastPromptKey, DateTime.now().millisecondsSinceEpoch);

  /// Sends the member to the system notification settings for this app.
  ///
  /// There is no second runtime prompt once POST_NOTIFICATIONS is permanently
  /// denied — the settings page is the only route back.
  Future<void> fixNotifications() => PermissionsService.instance.openSettings();

  /// Opens the Android 14+ "Full screen notifications" page for this app.
  Future<void> fixFullScreenRinging() =>
      NotificationService.instance.requestFullScreenIntentPermission();

  /// Shows the battery-optimisation exemption dialog, ignoring the
  /// "already asked once" record — the member asked for this one.
  Future<void> fixBatteryOptimisation() =>
      PermissionsService.instance.requestCallReliability(alreadyAsked: false);

  static PushReadinessService get instance => Get.find<PushReadinessService>();
}
