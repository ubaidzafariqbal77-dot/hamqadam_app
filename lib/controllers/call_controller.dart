import 'dart:async';

import 'package:get/get.dart';

import '../core/services/call_state_service.dart';
import '../core/services/notification_service.dart';
import '../core/storage/current_user_service.dart';
import '../core/utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import '../features/chat/views/incoming_call_screen.dart';
import '../features/chat/views/video_call_screen.dart';
import '../models/call_model.dart';
import '../repositories/call_repository.dart';
import '../widgets/app_snackbar.dart';

/// Drives audio / video calls against the backend's call API — the same one the
/// website uses, so both clients write to the same `calls` rows and the same
/// server logs, and a call placed on one is a real call the other can see.
///
/// The device-to-device media path is still Agora; what changed is that the
/// channel and the RTC token now come from the server per call
/// (`CallService::rtcPayload`) instead of being invented by the app and signed
/// with a temporary token compiled into the binary.
///
/// Signalling flow, mirroring `resources/views/frontend/layouts/app.blade.php`:
///
/// * caller  — `POST /calls` → own `rtc` → open the call screen
/// * receiver — `call-incoming` on `private-App.User.{id}` → incoming screen →
///   `POST /calls/{id}/accept` → own `rtc` → open the call screen
/// * either  — `POST /calls/{id}/{reject|cancel|end}`, and the other side hears
///   `call-rejected` / `call-cancelled` / `call-ended`
class CallController extends GetxController {
  CallController({
    required CallRepository repository,
    required CurrentUserService currentUser,
  })  : _repo = repository,
        _currentUser = currentUser;

  final CallRepository _repo;
  final CurrentUserService _currentUser;

  int get myUserId => _currentUser.user?.id ?? 0;

  /// The call this device is currently part of, ringing or connected.
  final Rxn<CallModel> activeCall = Rxn<CallModel>();

  /// True while a start / accept request is in flight, so the buttons can be
  /// disabled and a double tap cannot create two calls.
  final RxBool busy = false.obs;

  /// Fires when the ring window elapses with nobody answering.
  Timer? _ringTimeout;

  int? get activeCallId => activeCall.value?.id;

  @override
  void onClose() {
    _ringTimeout?.cancel();
    super.onClose();
  }

  // ---- Outgoing -------------------------------------------------------------

  /// Places a call in [threadId]. Returns false when it could not be started;
  /// the reason has already been shown to the user.
  Future<bool> startCall({required int threadId, required bool isVideo}) async {
    if (busy.value) return false;
    if (CallStateService.instance.isInCall) {
      AppSnackbar.info('You are already in a call.');
      return false;
    }

    busy.value = true;
    try {
      final CallSession session = await _repo.start(threadId: threadId, isVideo: isVideo);
      final CallModel call = session.call;
      final RtcCredentials? rtc = session.rtc;

      if (rtc == null) {
        // The server only omits `rtc` when Agora is not configured, and it
        // normally raises 503 for that — so this is the belt-and-braces case.
        AppSnackbar.error('Calling service unavailable.');
        return false;
      }

      activeCall.value = call;
      CallStateService.instance.startOutgoing(
        channelName: rtc.channel,
        threadId: call.threadId,
        isVideo: call.isVideo,
      );
      _armRingTimeout(call);

      await _openCallScreen(
        call: call,
        rtc: rtc,
        peerName: call.peerFor(myUserId)?.displayName ?? 'HamQadam Member',
        peerPhoto: call.peerFor(myUserId)?.photoUrl,
      );
      return true;
    } on AppException catch (e) {
      // `user_busy` (409) is an ordinary outcome, not a failure worth alarming
      // anyone about; the message the server wrote already says it plainly.
      AppSnackbar.error(e.message);
      return false;
    } catch (e) {
      AppLogger.w('Call start failed: $e');
      AppSnackbar.error('Could not start the call.');
      return false;
    } finally {
      busy.value = false;
    }
  }

  // ---- Incoming -------------------------------------------------------------

  /// Handles one `call-*` broadcast. [event] is the backend's `broadcastAs()`
  /// name with no leading dot.
  void handleCallEvent(String event, Map<String, dynamic> data) {
    final CallSession? session = CallSession.fromJson(data);
    if (session == null) {
      AppLogger.w('Call event $event carried no call payload.');
      return;
    }
    final CallModel call = session.call;

    switch (event) {
      case 'call-incoming':
        _onIncoming(call);
      case 'call-accepted':
        _onAccepted(call);
      case 'call-rejected':
        _onRemoteEnded(call, 'Call declined.');
      case 'call-cancelled':
        _onRemoteEnded(call, 'Call cancelled.');
      case 'call-missed':
        _onRemoteEnded(call, 'Missed call.');
      case 'call-ended':
        _onRemoteEnded(call, null);
      case 'call-busy':
        _onRemoteEnded(call, 'User is busy.');
      default:
        AppLogger.d('Unhandled call event: $event');
    }
  }

  void _onIncoming(CallModel call) {
    // The event goes to the thread channel as well as the receiver's own, so
    // the caller hears its own ring. Ignore anything not addressed to us.
    if (!call.isReceiver(myUserId)) return;
    if (CallStateService.instance.isInCall) return;

    activeCall.value = call;
    final CallParticipant? caller = call.caller;

    NotificationService.instance.showIncomingCall(
      callId: call.id,
      callerName: caller?.displayName ?? 'HamQadam Member',
      isVideo: call.isVideo,
    );

    IncomingCallScreen.show(
      callId: call.id,
      callerName: caller?.displayName ?? 'HamQadam Member',
      callerPhoto: caller?.photoUrl,
      isVideoCall: call.isVideo,
      threadId: call.threadId,
      ringSeconds: call.secondsUntilRingExpiry,
    );
  }

  /// Rings for a call that arrived as an FCM push instead of over the socket —
  /// i.e. the app was backgrounded or killed when it was placed.
  ///
  /// Re-reads the call before ringing: a push can sit in Doze for minutes, and
  /// waking someone for a call the caller already abandoned is worse than
  /// staying quiet.
  Future<void> ringFromPush(int callId) async {
    if (CallStateService.instance.isInCall) return;
    if (activeCallId == callId) return; // the socket already told us
    try {
      final CallSession session = await _repo.show(callId);
      if (!session.call.status.isLive) return;
      _onIncoming(session.call);
    } catch (e) {
      AppLogger.d('Could not load pushed call $callId: $e');
    }
  }

  void _onAccepted(CallModel call) {
    if (call.id != activeCallId) return;
    _ringTimeout?.cancel();
    activeCall.value = call;
    // The caller is already sitting in the Agora channel; the receiver joining
    // is what the call screen reacts to. Nothing else to do here.
  }

  void _onRemoteEnded(CallModel call, String? message) {
    if (call.id != activeCallId) return;
    // Our own action echoing back — the local UI already handled it.
    if (call.endedByUserId == myUserId) {
      _clear();
      return;
    }
    if (message != null) AppSnackbar.info(message);
    _hangUpLocally();
  }

  /// Receiver taps Accept.
  Future<void> acceptIncoming(int callId) async {
    if (busy.value) return;
    busy.value = true;
    try {
      final CallSession session = await _repo.accept(callId);
      final RtcCredentials? rtc = session.rtc;
      if (rtc == null) {
        AppSnackbar.error('Calling service unavailable.');
        _clear();
        return;
      }
      final CallModel call = session.call;
      activeCall.value = call;
      _ringTimeout?.cancel();
      CallStateService.instance.startIncoming(
        channelName: rtc.channel,
        threadId: call.threadId,
        isVideo: call.isVideo,
      );
      NotificationService.instance.cancelIncomingCall(call.id);

      await _openCallScreen(
        call: call,
        rtc: rtc,
        peerName: call.peerFor(myUserId)?.displayName ?? 'HamQadam Member',
        peerPhoto: call.peerFor(myUserId)?.photoUrl,
      );
    } on AppException catch (e) {
      // 422 `call_inactive` means the caller gave up first — say so rather than
      // dropping the user into an empty channel.
      AppSnackbar.info(e.message);
      _clear();
    } catch (e) {
      AppLogger.w('Call accept failed: $e');
      AppSnackbar.error('Could not join the call.');
      _clear();
    } finally {
      busy.value = false;
    }
  }

  /// Receiver taps Decline.
  Future<void> rejectIncoming(int callId) async {
    NotificationService.instance.cancelIncomingCall(callId);
    _clear();
    try {
      await _repo.reject(callId);
    } catch (e) {
      AppLogger.w('Call reject failed: $e');
    }
  }

  // ---- Hang up --------------------------------------------------------------

  /// Ends whatever this device is currently on, choosing the endpoint the
  /// server expects for our role and the call's stage.
  Future<void> hangUp() async {
    final CallModel? call = activeCall.value;
    _hangUpLocally();
    if (call == null) return;

    // `cancel` is the caller giving up before it was answered; anything else is
    // an `end`. Picking the right one is what keeps the call log honest —
    // `cancel` is also the only action the server accepts from the caller while
    // the call is still ringing.
    final bool neverAnswered =
        call.status == CallStatus.calling || call.status == CallStatus.ringing;
    try {
      if (call.isCaller(myUserId) && neverAnswered) {
        await _repo.cancel(call.id);
      } else {
        await _repo.end(call.id);
      }
    } catch (e) {
      AppLogger.w('Call hang-up failed: $e');
    }
  }

  /// Tells the server both sides are in the channel, which is what makes
  /// `duration_seconds` meaningful in the call log.
  Future<void> markConnected() async {
    final int? id = activeCallId;
    if (id == null) return;
    // Remote user joined — call is live; cancel the ring timer so it doesn't
    // fire later and incorrectly mark this connected call as missed.
    _ringTimeout?.cancel();
    try {
      await _repo.connect(id);
    } catch (e) {
      AppLogger.d('Call connect ping failed: $e');
    }
  }

  // ---- Token renewal (called by VideoCallScreen) --------------------------

  /// Mints a fresh Agora RTC token for an active call. The call screen calls
  /// this when `onTokenPrivilegeWillExpire` fires or after a network reconnect.
  Future<RtcCredentials?> renewRtcToken(int callId) async {
    try {
      return await _repo.renewToken(callId);
    } catch (e) {
      AppLogger.w('Token renewal failed: $e');
      return null;
    }
  }

  // ---- Internals ------------------------------------------------------------

  Future<void> _openCallScreen({
    required CallModel call,
    required RtcCredentials rtc,
    required String peerName,
    String? peerPhoto,
  }) async {
    await VideoCallScreen.open(
      callId: call.id,
      channelName: rtc.channel,
      userName: peerName,
      userPhoto: peerPhoto,
      isVideoCall: call.isVideo,
      agoraAppId: rtc.appId,
      token: rtc.token,
      uid: rtc.uid,
    );
    // The screen popped: whichever way it ended, this device is out of the call.
    await hangUp();
  }

  /// Reports the call missed once the server's ring window has passed, so an
  /// unanswered mobile call is logged exactly like an unanswered web one.
  void _armRingTimeout(CallModel call) {
    _ringTimeout?.cancel();
    final int seconds = call.secondsUntilRingExpiry;
    if (seconds <= 0) return;
    _ringTimeout = Timer(Duration(seconds: seconds), () async {
      if (activeCallId != call.id) return;
      // Double-check: if the call has already connected or been accepted,
      // do NOT mark it missed — the Pusher broadcast may simply have
      // arrived after the timer was armed.
      final CallModel? current = activeCall.value;
      if (current != null && (current.status == CallStatus.connected ||
          current.status == CallStatus.accepted)) {
        AppLogger.d('Ring timer fired but call already ${current.status}; skipping missed.');
        return;
      }
      try {
        await _repo.missed(call.id);
      } catch (e) {
        AppLogger.d('Marking call missed failed: $e');
      }
      _hangUpLocally();
    });
  }

  void _hangUpLocally() {
    final int? id = activeCallId;
    if (id != null) NotificationService.instance.cancelIncomingCall(id);
    _clear();
    if (Get.currentRoute.contains('VideoCallScreen')) {
      Get.back<void>();
    }
  }

  void _clear() {
    _ringTimeout?.cancel();
    _ringTimeout = null;
    activeCall.value = null;
    CallStateService.instance.endCall();
    IncomingCallScreen.dismissIfShowing();
  }
}
