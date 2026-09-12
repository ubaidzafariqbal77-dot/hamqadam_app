import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/call_controller.dart';
import '../utils/app_logger.dart';
import 'notification_service.dart';

/// Decides *where* a live call is drawn once the member stops looking at it.
///
/// Before this existed, leaving the call screen by any route ended the call:
/// back popped it, `dispose()` released the Agora engine, and the trailing
/// `hangUp()` in `CallController._openCallScreen` told the server it was over.
/// So "minimise" and "hang up" were the same gesture, which is the reported
/// "back karne se call end ho jati hai".
///
/// A minimised call now goes to one of two places:
///
/// * **video** → an Android picture-in-picture window, floating over whatever
///   the member does next. The call screen route is never popped; the whole
///   Flutter UI is simply drawn at PiP size, so the screen strips itself back
///   to the remote video while [isInPictureInPicture] is true;
/// * **audio** → the task goes to the background and the ongoing-call
///   notification is what brings it back. A PiP window of a still avatar would
///   be nothing but a thumbnail in the way.
///
/// Either way [startOngoingCall] posts the tray entry, and on Android that
/// entry belongs to a foreground service — which is load-bearing rather than
/// decorative: since Android 9 a backgrounded process with no foreground
/// service is handed silence from the microphone instead of audio, so a
/// minimised call without one stays "connected" while the other side hears
/// nothing at all.
class CallWindowService {
  CallWindowService._();
  static final CallWindowService instance = CallWindowService._();

  /// Implemented by `MainActivity.WINDOW_CHANNEL` and `CallForegroundService`.
  static const MethodChannel _channel =
      MethodChannel('com.app.hamqadam/call_window');

  final StreamController<bool> _pipController =
      StreamController<bool>.broadcast();

  /// Emits true when Android has put the app into its floating window, and
  /// false when it comes back out of it.
  Stream<bool> get onPipModeChanged => _pipController.stream;

  bool _inPip = false;
  bool get isInPictureInPicture => _inPip;

  bool _wired = false;
  bool? _pipSupported;

  /// Starts listening for the two things the platform tells *us*: PiP
  /// transitions, and "End call" tapped on the ongoing-call notification.
  void init() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler(_onPlatformCall);
  }

  Future<dynamic> _onPlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'pipModeChanged':
        _inPip = call.arguments == true;
        AppLogger.i('Call window: picture-in-picture = $_inPip');
        _pipController.add(_inPip);
      case 'endCall':
        AppLogger.i('Call window: End tapped on the ongoing-call notification');
        if (Get.isRegistered<CallController>()) {
          await Get.find<CallController>().hangUp();
        }
        await stopOngoingCall();
      default:
        AppLogger.d('Call window: unhandled platform call ${call.method}');
    }
    return null;
  }

  // ── Picture-in-picture ────────────────────────────────────────────────────

  /// Whether this device will actually grant a PiP window. A member can turn
  /// it off per app in Settings, so this is not a constant.
  Future<bool> get isPipSupported async {
    if (!GetPlatform.isAndroid) return false;
    final bool? cached = _pipSupported;
    if (cached != null) return cached;
    try {
      final bool supported =
          await _channel.invokeMethod<bool>('isPipSupported') ?? false;
      _pipSupported = supported;
      return supported;
    } catch (_) {
      _pipSupported = false;
      return false;
    }
  }

  /// Tells the platform whether *leaving* the app should shrink it into a PiP
  /// window — i.e. whether a video call is up. This is what makes the home and
  /// recents buttons behave like back does.
  Future<void> setPipEnabled(bool enabled) async {
    if (!GetPlatform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('setPipEnabled', <String, dynamic>{
        'enabled': enabled,
      });
    } catch (e) {
      AppLogger.d('Could not set the PiP preference: $e');
    }
  }

  /// Shrinks the app into the floating window now. Returns false when the
  /// system refused, so the caller can fall back to [minimizeApp] rather than
  /// leaving a back press doing nothing.
  Future<bool> enterPictureInPicture({int width = 9, int height = 16}) async {
    if (!GetPlatform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('enterPip', <String, dynamic>{
            'width': width,
            'height': height,
          }) ??
          false;
    } catch (e) {
      AppLogger.d('Could not enter picture-in-picture: $e');
      return false;
    }
  }

  /// Sends the app to the background the way the home button would, leaving
  /// the call — and the route it lives on — untouched.
  ///
  /// Android only: iOS gives an app no way to background itself, so there the
  /// call simply stays on screen until the member leaves it themselves.
  Future<bool> minimizeApp() async {
    if (!GetPlatform.isAndroid) return false;
    try {
      await _channel.invokeMethod<bool>('moveToBackground');
      return true;
    } catch (e) {
      AppLogger.d('Could not minimise the app: $e');
      return false;
    }
  }

  // ── Ongoing-call tray entry ──────────────────────────────────────────────

  /// Puts the call in the notification tray for as long as it lasts.
  ///
  /// Raised when the call screen opens rather than when it is minimised: the
  /// service behind it is what keeps the microphone alive, and asking for it
  /// only at the moment the member leaves is exactly when Android 14 is most
  /// likely to refuse to start it.
  Future<void> startOngoingCall({
    required int callId,
    required String peerName,
    required bool isVideo,
    required String status,
  }) async {
    if (GetPlatform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('startCallService', <String, dynamic>{
          'name': peerName,
          'isVideo': isVideo,
          'status': status,
        });
      } catch (e) {
        AppLogger.w('Could not start the ongoing-call service: $e');
      }
      return;
    }
    // iOS has no foreground services; the notification is all we can offer.
    await NotificationService.instance.showOngoingCall(
      callId: callId,
      peerName: peerName,
      isVideo: isVideo,
      status: status,
    );
  }

  /// Rewrites the tray entry as the call moves from ringing to connected.
  Future<void> updateOngoingCall({
    required int callId,
    required String peerName,
    required bool isVideo,
    required String status,
  }) =>
      startOngoingCall(
        callId: callId,
        peerName: peerName,
        isVideo: isVideo,
        status: status,
      );

  /// Takes the tray entry down and lets the microphone go. Safe to call for a
  /// call that never posted one.
  Future<void> stopOngoingCall() async {
    if (GetPlatform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('stopCallService');
      } catch (e) {
        AppLogger.d('Could not stop the ongoing-call service: $e');
      }
      return;
    }
    await NotificationService.instance.cancelOngoingCall();
  }
}
