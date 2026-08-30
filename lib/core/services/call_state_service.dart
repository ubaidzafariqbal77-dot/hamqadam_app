import 'dart:async';

import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../storage/current_user_service.dart';
import '../utils/app_logger.dart';

/// Global call state manager.
///
/// Tracks whether a call is currently active (outgoing or incoming) so that:
///   1. Duplicate calls are rejected.
///   2. The caller's screen can listen for decline / busy signals.
///   3. The app knows when to allow or block new call attempts.
class CallStateService extends GetxService {
  CallStateService._();
  static final CallStateService instance = CallStateService._();

  // ── State ────────────────────────────────────────────────────────────────

  /// Whether any call (incoming or outgoing) is currently in progress.
  bool get isInCall => _activeChannel != null;
  bool get isOutgoing => _isOutgoing;
  bool get isVideoCall => _isVideoCall;
  int get activeThreadId => _activeThreadId;

  String? _activeChannel;
  bool _isOutgoing = false;
  bool _isVideoCall = false;
  int _activeThreadId = 0;


  // ── Decline signal stream ────────────────────────────────────────────────

  /// Controller that emits the threadId when a call decline signal is received
  /// for the current active outgoing call.
  final StreamController<int> _declineController = StreamController<int>.broadcast();
  Stream<int> get onCallDeclined => _declineController.stream;

  /// Controller that emits when the remote user is busy (already in a call).
  final StreamController<int> _busyController = StreamController<int>.broadcast();
  Stream<int> get onRemoteBusy => _busyController.stream;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Try to start an outgoing call. Returns `true` if allowed, `false` if
  /// another call is already active.
  bool startOutgoing({
    required String channelName,
    required int threadId,
    required bool isVideo,
  }) {
    if (isInCall) {
      AppLogger.w('CallState: rejected start — already in call on $_activeChannel');
      return false;
    }

    _activeChannel = channelName;
    _isOutgoing = true;
    _isVideoCall = isVideo;
    _activeThreadId = threadId;
    AppLogger.i('CallState: outgoing call started on $channelName (video=$isVideo)');
    return true;
  }

  /// Mark that an incoming call is being handled (shown on screen).
  void startIncoming({
    required String channelName,
    required int threadId,
    required bool isVideo,
  }) {
    if (isInCall) {
      AppLogger.w('CallState: incoming call $channelName ignored — already in call');
      return;
    }
    _activeChannel = channelName;
    _isOutgoing = false;
    _isVideoCall = isVideo;
    _activeThreadId = threadId;
    AppLogger.i('CallState: incoming call accepted on $channelName');
  }

  /// End the current call and reset state.
  void endCall() {
    final String? ch = _activeChannel;
    _activeChannel = null;
    _isOutgoing = false;
    _isVideoCall = false;
    _activeThreadId = 0;
    if (ch != null) {
      AppLogger.i('CallState: call ended on $ch');
    }
  }

  /// Broadcast a decline signal so the caller's VideoCallScreen can react.
  void notifyDeclined(int threadId) {
    _declineController.add(threadId);
    AppLogger.i('CallState: decline broadcast for thread $threadId');
  }

  /// Broadcast that the remote user is busy.
  void notifyBusy(int threadId) {
    _busyController.add(threadId);
    AppLogger.i('CallState: busy broadcast for thread $threadId');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Get the current user's display name for call signaling.
  String get currentUserDisplayName {
    if (Get.isRegistered<CurrentUserService>()) {
      final String name = Get.find<CurrentUserService>().user?.fullName ?? '';
      if (name.isNotEmpty) return name;
    }
    if (Get.isRegistered<AuthController>()) {
      final String name = Get.find<AuthController>().user.value?.fullName ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'Member';
  }

  /// Get the current user's profile photo URL.
  String? get currentUserPhoto {
    if (Get.isRegistered<CurrentUserService>()) {
      final Map<String, dynamic>? raw = Get.find<CurrentUserService>().rawJson;
      if (raw != null) {
        final dynamic member = raw['member'];
        if (member is Map<String, dynamic>) {
          return member['photo'] as String?;
        }
      }
    }
    if (Get.isRegistered<AuthController>()) {
      final Map<String, dynamic> raw =
          Get.find<AuthController>().user.value?.raw ?? <String, dynamic>{};
      final dynamic member = raw['member'];
      if (member is Map<String, dynamic>) {
        return member['photo'] as String?;
      }
    }
    return null;
  }

  @override
  void onClose() {
    _declineController.close();
    _busyController.close();
    super.onClose();
  }
}
