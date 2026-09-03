import 'dart:async';

import 'package:get/get.dart';

import '../core/services/call_state_service.dart';
import '../core/services/notification_service.dart';
import '../core/storage/current_user_service.dart';
import '../core/utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import '../features/chat/views/incoming_call_screen.dart';
import '../features/chat/views/video_call_screen.dart';
import '../core/storage/call_log_service.dart';
import '../models/call_log_entry.dart';
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

  /// The ring window to use when the server did not give one.
  static const int _fallbackRingSeconds = 45;

  /// True once the other side is known to have left or hung up.
  ///
  /// Without it the receiver re-reported the call: Agora's `onUserOffline`
  /// closes the call screen about a second after the caller hangs up, the
  /// screen popping resumes [_openCallScreen], and its trailing [hangUp] then
  /// POSTed `end` again — so `calls.ended_by_user_id` recorded whoever *received*
  /// the hang-up rather than whoever performed it, and the call log named the
  /// wrong person.
  bool _endedByPeer = false;

  /// Fires when the ring window elapses with nobody answering.
  Timer? _ringTimeout;

  /// Re-reads the call from the server while this device is on one.
  ///
  /// The call used to end only when the matching `call-*` broadcast arrived, so
  /// a single dropped event left the caller ringing until they gave up
  /// themselves — even though the receiver had already declined. The server is
  /// the authority on whether a call is still live, so this asks it, and the
  /// broadcast becomes the fast path rather than the only path.
  Timer? _watchdog;
  Duration? _watchdogPeriod;
  bool _checkingStatus = false;

  /// How often the server is asked. Frequent while nobody has answered — that
  /// is the window in which a decline has to be noticed — and rarely once the
  /// two are talking, where Agora's own callbacks report a drop.
  static const Duration _watchWhileRinging = Duration(seconds: 3);
  // 5s, not 15s: when Agora's own `onUserOffline` does not fire - a flaky
  // network, or a peer whose process died - this poll is the only thing that
  // ends the call, and fifteen seconds of dead air is what "the other side
  // takes ages to hang up" felt like.
  static const Duration _watchWhileConnected = Duration(seconds: 5);

  int? get activeCallId => activeCall.value?.id;

  @override
  void onClose() {
    _ringTimeout?.cancel();
    _watchdog?.cancel();
    super.onClose();
  }

  // ---- Watchdog -------------------------------------------------------------

  void _retuneWatchdog() {
    final CallModel? call = activeCall.value;
    if (call == null) {
      _watchdog?.cancel();
      _watchdog = null;
      _watchdogPeriod = null;
      return;
    }

    final Duration wanted = call.status == CallStatus.connected
        ? _watchWhileConnected
        : _watchWhileRinging;
    if (_watchdogPeriod == wanted && (_watchdog?.isActive ?? false)) return;

    _watchdog?.cancel();
    _watchdogPeriod = wanted;
    _watchdog = Timer.periodic(wanted, (_) => _checkStillLive());
  }

  /// Asks the server whether the active call is still going, and ends it here
  /// if it is not.
  Future<void> _checkStillLive() async {
    final int? id = activeCallId;
    if (id == null) {
      _retuneWatchdog();
      return;
    }
    if (_checkingStatus) return;
    _checkingStatus = true;
    try {
      final CallSession session = await _repo.show(id);
      if (activeCallId != id) return; // moved on while the request was in flight

      final CallModel fresh = session.call;
      if (fresh.status.isLive) {
        // Keep the local copy in step so the period follows the stage.
        activeCall.value = fresh;
        _retuneWatchdog();
        return;
      }

      AppLogger.i('Watchdog: call $id is ${fresh.status}; ending locally.');
      _log(fresh);
      final String? message = _messageForEndedStatus(fresh.status);
      if (message != null) AppSnackbar.info(message);
      _hangUpLocally();
    } catch (e) {
      // A transient failure is not evidence the call is over; the next tick
      // will ask again.
      AppLogger.d('Watchdog check for call $id failed: $e');
    } finally {
      _checkingStatus = false;
    }
  }

  String? _messageForEndedStatus(CallStatus status) {
    switch (status) {
      case CallStatus.rejected:
        return 'Call declined.';
      case CallStatus.cancelled:
        return 'Call cancelled.';
      case CallStatus.missed:
        return 'No answer.';
      case CallStatus.busy:
        return 'User is busy.';
      case CallStatus.ended:
        return null; // an ordinary hang-up needs no announcement
      default:
        return null;
    }
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
      _retuneWatchdog();
      _log(call, direction: CallLogDirection.outgoing);

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
    _log(call, direction: CallLogDirection.incoming);
    final CallParticipant? caller = call.caller;

    // The tray notification is what rings a locked or backgrounded phone and
    // carries Accept / Decline; the in-app screen below is what a member who is
    // already looking at the app sees. Both are raised: which one actually
    // makes a sound is decided inside the service, from whether the app is in
    // the foreground.
    NotificationService.instance.showIncomingCall(
      callId: call.id,
      callerName: caller?.displayName ?? 'HamQadam Member',
      isVideo: call.isVideo,
      ringSeconds: call.secondsUntilRingExpiry > 0
          ? call.secondsUntilRingExpiry
          : 60,
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
    _log(call, outcome: CallLogOutcome.answered);
    // Answered: the watchdog can drop to its slow period.
    _retuneWatchdog();
    // The caller is already sitting in the Agora channel; the receiver joining
    // is what the call screen reacts to. Nothing else to do here.
  }

  void _onRemoteEnded(CallModel call, String? message) {
    // Logged before the id guard: an end for a call this device is not on any
    // more is still history worth keeping — a missed call that arrived while
    // the app was closed reaches us exactly like this.
    _log(call);
    if (call.id != activeCallId) return;
    _endedByPeer = true;
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
      _retuneWatchdog();
      _log(
        call,
        direction: CallLogDirection.incoming,
        outcome: CallLogOutcome.answered,
      );

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
    final CallModel? call = activeCall.value;
    if (call != null && call.id == callId) {
      _log(
        call,
        direction: CallLogDirection.incoming,
        outcome: CallLogOutcome.declined,
      );
    }
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
    final bool peerEnded = _endedByPeer;
    _hangUpLocally();
    if (call == null) return;
    if (peerEnded) {
      // The other side has already told the server; saying it again would only
      // overwrite who ended it.
      AppLogger.d('Call ${call.id} was ended by the peer; not re-reporting.');
      return;
    }

    // `cancel` is the caller giving up before it was answered; anything else is
    // an `end`. Picking the right one is what keeps the call log honest —
    // `cancel` is also the only action the server accepts from the caller while
    // the call is still ringing.
    final bool neverAnswered =
        call.status == CallStatus.calling || call.status == CallStatus.ringing;
    _log(
      call,
      outcome: neverAnswered
          ? (call.isCaller(myUserId)
              ? CallLogOutcome.cancelled
              : CallLogOutcome.declined)
          : CallLogOutcome.answered,
    );
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

  // ---- Local call history ---------------------------------------------------

  /// Writes the call's current state into the device's own history.
  ///
  /// Called at every point a call's outcome becomes known, because the Calls
  /// tab is a local read now — waiting for the server would mean a missed call
  /// that arrived while the app was closed never showed up at all.
  void _log(
    CallModel call, {
    CallLogDirection? direction,
    CallLogOutcome? outcome,
  }) {
    if (!Get.isRegistered<CallLogService>()) return;
    Get.find<CallLogService>().recordCall(
      call,
      myUserId: myUserId,
      direction: direction,
      outcome: outcome,
    );
  }

  /// Called by the call screen when Agora reports the other party has left the
  /// channel deliberately — which lands about a second before the matching
  /// `call-ended` broadcast, and sometimes instead of it.
  void noteRemoteLeft() {
    if (activeCall.value == null) return;
    _endedByPeer = true;
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
    // A missing or already-past `ring_expires_at` used to mean no timer at all,
    // so an unanswered call rang until the caller gave up. The server's window
    // is 30s; this is the belt-and-braces version of it.
    final int fromServer = call.secondsUntilRingExpiry;
    final int seconds = fromServer > 0 ? fromServer : _fallbackRingSeconds;
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
      _log(call, outcome: CallLogOutcome.missed);
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
    // Clearing the active call is all this has to do: VideoCallScreen watches
    // it and closes itself. This used to try to pop the route too, guarded by
    // `Get.currentRoute.contains('VideoCallScreen')` — a name GetX derives from
    // the builder closure's runtime type, so the guard could not be relied on,
    // and popping on a bad match would have dismissed whatever else was on top.
    _clear();
  }

  void _clear() {
    _endedByPeer = false;
    _ringTimeout?.cancel();
    _ringTimeout = null;
    _watchdog?.cancel();
    _watchdog = null;
    _watchdogPeriod = null;
    // Cancel the tray entry here rather than only in `_hangUpLocally`: a call
    // we ended ourselves came through `_onRemoteEnded` -> `_clear`, which left
    // the ringing notification sitting in the shade for a call that was over.
    final int? id = activeCall.value?.id;
    if (id != null) NotificationService.instance.cancelIncomingCall(id);
    activeCall.value = null;
    CallStateService.instance.endCall();
    IncomingCallScreen.dismissIfShowing();
    NotificationService.instance.stopRingtone();
  }
}
