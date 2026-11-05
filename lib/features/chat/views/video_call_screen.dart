import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../controllers/call_controller.dart';
import '../../../core/services/call_state_service.dart';
import '../../../core/services/call_window_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../models/call_model.dart';

/// Reusable Audio and Video Call Screen powered by official Agora RTC Engine.
class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    this.callId,
    required this.channelName,
    required this.userName,
    required this.agoraAppId,
    required this.token,
    required this.uid,
    this.userPhoto,
    this.isVideoCall = true,
  });

  /// Server call ID — needed so the screen can request fresh Agora tokens
  /// when the current one is about to expire.
  final int? callId;

  /// The unique channel name for this conversation / call.
  final String channelName;

  /// The name of the remote user being called.
  final String userName;

  /// Remote user's avatar photo URL.
  final String? userPhoto;

  /// `true` for 2-way Video Call, `false` for Audio-only Voice Call.
  final bool isVideoCall;

  /// Agora App ID, from the server's `rtc.app_id` for this call.
  final String agoraAppId;

  /// Per-call Agora RTC token from `rtc.token`.
  ///
  /// This used to default to a temporary token compiled into the app. Agora
  /// temp tokens live at most 24 hours, so that build was always one day away
  /// from every call failing at once. The server now mints one per call with
  /// the app certificate, bound to [uid].
  final String token;

  /// The uid the token was signed for — `rtc.uid`, i.e. the member's user id.
  /// Joining with any other uid makes Agora reject the token.
  final int uid;

  /// Helper static launcher
  static Future<void> open({
    int? callId,
    required String channelName,
    required String userName,
    required String agoraAppId,
    required String token,
    required int uid,
    String? userPhoto,
    bool isVideoCall = true,
  }) async {
    await Get.to<void>(
      () => VideoCallScreen(
        callId: callId,
        channelName: channelName,
        userName: userName,
        userPhoto: userPhoto,
        isVideoCall: isVideoCall,
        agoraAppId: agoraAppId,
        token: token,
        uid: uid,
      ),
      transition: Transition.fadeIn,
    );
  }


  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with WidgetsBindingObserver {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isVideoDisabled = false;

  /// True while the camera is off only because the app is in the
  /// background — distinct from [_isVideoDisabled], which is the
  /// member's own choice and must survive coming back.
  bool _cameraPausedForBackground = false;
  bool _isSpeakerOn = true;
  bool _engineReady = false;
  Timer? _callTimer;
  int _callDurationSeconds = 0;
  StreamSubscription<int>? _declineSubscription;

  /// True while Android is drawing the app in its floating window.
  ///
  /// PiP scales the *whole* Flutter UI down, so nothing hides itself: at that
  /// size the controls, the top bar and the avatar are unreadable smudges over
  /// the video. The screen strips itself back to the remote feed instead —
  /// see [build].
  bool _isPipMode = false;
  StreamSubscription<bool>? _pipSubscription;

  /// The line currently on the ongoing-call notification, so it is only
  /// rewritten when it actually changed.
  String _trayStatusShown = '';

  /// Closes this screen when the controller says the call is over.
  ///
  /// The controller used to pop the screen itself with
  /// `if (Get.currentRoute.contains('VideoCallScreen')) Get.back()`. GetX
  /// derives that name from the *builder closure's* runtime type, so the match
  /// was never dependable — and when it missed, the call ended everywhere
  /// except on screen: the state was cleared, the watchdog stopped, and the
  /// caller was left staring at "Ringing…" until they hung up themselves. That
  /// is exactly the "call keeps going after the receiver declined" report.
  ///
  /// Driving it from the observable instead means the screen closes on its own
  /// terms, whatever the route happens to be called.
  Worker? _callEndedWorker;

  // ── Reconnection / token renewal state ──────────────────────────────────
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  bool _isReconnecting = false;
  bool _isEndingCall = false;
  bool _tokenExpired = false;
  Timer? _reconnectTimer;
  String _currentToken;

  _VideoCallScreenState() : _currentToken = '';

  @override
  void initState() {
    super.initState();
    _currentToken = widget.token;
    _isVideoDisabled = !widget.isVideoCall;
    // Hold the screen on for the duration of the call, and keep the window
    // able to sit over the lock screen — a call answered from the lock screen
    // must not black out mid-sentence. Released in `CallController._clear`.
    NotificationService.instance.beginCallScreen();
    // The call is now a thing the member can leave and come back to, so it
    // needs somewhere to live while they are not looking at it: a
    // picture-in-picture window for video, and the tray entry raised from
    // [_initAgora] — after the microphone has been granted, because Android 14
    // refuses to start a microphone foreground service before that.
    CallWindowService.instance.setPipEnabled(widget.isVideoCall);
    _pipSubscription =
        CallWindowService.instance.onPipModeChanged.listen((bool inPip) {
      if (!mounted) return;
      setState(() => _isPipMode = inPip);
    });
    WidgetsBinding.instance.addObserver(this);
    _listenForDeclineSignals();
    _watchForCallEnd();
    _initAgora();
  }

  // ─── Camera while the app is away ────────────────────────────────────────

  /// The call holds the microphone in the background through
  /// CallForegroundService, but NOT the camera: the service is microphone-typed
  /// only, so the app must let the camera go when it stops being visible.
  /// Android would cut the feed off anyway — doing it deliberately means the
  /// other side sees the picture stop cleanly and get restored on return,
  /// instead of a frozen last frame.
  ///
  /// Picture-in-picture is the exception: the call window is still on screen,
  /// so the camera stays live.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!widget.isVideoCall || _engine == null || !_engineReady) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _resumeCameraAfterBackground();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!_isPipMode) _pauseCameraForBackground();
      case AppLifecycleState.inactive:
        // A transient state (notification shade, incoming system dialog); the
        // window is still up, so the camera stays.
        break;
    }
  }

  Future<void> _pauseCameraForBackground() async {
    // Nothing to pause if the member already turned their video off.
    if (_isVideoDisabled || _cameraPausedForBackground) return;
    _cameraPausedForBackground = true;
    try {
      await _engine!.muteLocalVideoStream(true);
      await _engine!.stopPreview();
    } catch (e) {
      debugPrint('📞 Camera background-pause error: $e');
    }
  }

  Future<void> _resumeCameraAfterBackground() async {
    if (!_cameraPausedForBackground) return;
    _cameraPausedForBackground = false;
    // The member may have turned video off while away; respect that.
    if (_isVideoDisabled) return;
    try {
      await _engine!.startPreview();
      await _engine!.muteLocalVideoStream(false);
    } catch (e) {
      debugPrint('📞 Camera background-resume error: $e');
    }
  }

  // ─── Minimising ──────────────────────────────────────────────────────────

  /// What "back" means on a call now.
  ///
  /// It used to mean hang up — back popped the route, `dispose` released the
  /// Agora engine and `CallController._openCallScreen` reported the call ended
  /// to the server. So there was no way to check a message mid-call without
  /// dropping it.
  ///
  /// The route is never popped here. A video call shrinks into the system's
  /// floating window; an audio call sends the task to the background, where
  /// the foreground service keeps the microphone alive and the tray entry
  /// brings it back. If PiP is refused — the member turned it off for this app,
  /// or the device has no such feature — the video call minimises the same way
  /// the audio one does rather than leaving back doing nothing.
  Future<void> _minimize() async {
    if (_isEndingCall) return;
    final bool videoIsLive = widget.isVideoCall && !_isVideoDisabled;
    if (videoIsLive && await CallWindowService.instance.enterPictureInPicture()) {
      return;
    }
    if (await CallWindowService.instance.minimizeApp()) return;

    // iOS: an app there cannot send itself to the background, so the only
    // honest thing left is to say that leaving will not drop the call.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'The call keeps running if you leave the app.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// The one-line description on the ongoing-call notification.
  String get _trayStatus {
    if (_remoteUid != null) {
      return widget.isVideoCall ? 'Ongoing video call' : 'Ongoing voice call';
    }
    if (_isReconnecting) return 'Reconnecting…';
    if (_localUserJoined) return 'Ringing…';
    return 'Connecting…';
  }

  /// Posts (or rewrites) the tray entry, but only when the line has changed —
  /// on Android every rewrite goes through the foreground service.
  void _publishTrayEntry() {
    final String status = _trayStatus;
    if (status == _trayStatusShown) return;
    _trayStatusShown = status;
    CallWindowService.instance.startOngoingCall(
      callId: widget.callId ?? 0,
      peerName: widget.userName,
      isVideo: widget.isVideoCall,
      status: status,
    );
  }

  /// Hands back everything the minimised call was holding: the PiP preference,
  /// the tray entry, and with it the microphone the service was keeping open.
  void _releaseCallWindow() {
    CallWindowService.instance.setPipEnabled(false);
    CallWindowService.instance.stopOngoingCall();
    // A call that ends while the app is in its floating window must not leave
    // that window sitting over whatever the member moved on to — with the call
    // screen popped it would be showing the chat behind it. Sending the task
    // to the back closes the window and leaves them where they were.
    if (CallWindowService.instance.isInPictureInPicture) {
      CallWindowService.instance.minimizeApp();
    }
  }

  void _watchForCallEnd() {
    if (!Get.isRegistered<CallController>()) return;
    final CallController calls = Get.find<CallController>();
    _callEndedWorker = ever<CallModel?>(calls.activeCall, (CallModel? call) {
      if (call != null) return;
      if (!mounted || _isEndingCall) return;
      _isEndingCall = true;
      debugPrint('📞 Call cleared by the controller; closing the call screen.');
      _releaseCallWindow();
      // `pop`, not `maybePop`: back is now intercepted by the [PopScope] in
      // [build] and turned into a minimise, and `maybePop` would ask it — so
      // the call ending would have shrunk the screen instead of closing it.
      Navigator.of(context).pop();
    });
  }

  /// Listen for call decline signals from the remote user.
  void _listenForDeclineSignals() {
    _declineSubscription = CallStateService.instance.onCallDeclined.listen((int threadId) {
      if (!mounted) return;
      _showDeclinedMessage();
      _endCall();
    });
  }

  void _showDeclinedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Call declined by the other user.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Agora Setup ─────────────────────────────────────────────────────────

  Future<void> _initAgora() async {
    if (!CallStateService.instance.isInCall) {
      CallStateService.instance.startOutgoing(
        channelName: widget.channelName,
        threadId: 0,
        isVideo: widget.isVideoCall,
      );
    }

    await <Permission>[
      Permission.microphone,
      if (widget.isVideoCall) Permission.camera,
    ].request();

    // Deliberately here and not in `initState`: the tray entry is the
    // foreground service that holds the microphone open once the call is
    // minimised, and from Android 14 the system refuses to start a
    // microphone-typed service for an app that has not been granted
    // RECORD_AUDIO yet — which, on the very first call, is the state
    // `initState` runs in.
    _publishTrayEntry();

    final RtcEngine engine = createAgoraRtcEngine();
    _engine = engine;

    await engine.initialize(
      RtcEngineContext(
        appId: widget.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('📞 Agora: Joined channel successfully');
          _reconnectAttempts = 0;
          _isReconnecting = false;
          if (mounted) {
            setState(() {
              _localUserJoined = true;
              _engineReady = true;
            });
          }
          _publishTrayEntry();
          _safeSpeaker();
          // Deliberately no ringtone here. `onJoinChannelSuccess` fires for
          // BOTH sides, so playing it rang the caller with the receiver's
          // incoming-call tone, and rang the receiver a second time after they
          // had already answered. The ringtone belongs to the incoming-call
          // screen alone — see IncomingCallScreen / IncomingCallOverlayBar.
          _silenceAnyRingtone();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('📞 Agora: Remote user $remoteUid joined');
          _silenceAnyRingtone();
          if (Get.isRegistered<CallController>()) {
            Get.find<CallController>().markConnected();
          }
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
            });
            _startCallTimer();
            _publishTrayEntry();
          }
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          debugPrint('📞 Agora: Remote user $remoteUid left (reason: $reason)');
          if (_isEndingCall) return;
          // Network drop — NOT a hang-up. Try reconnecting before ending.
          if (reason == UserOfflineReasonType.userOfflineQuit) {
            // Remote user deliberately left → end the call.
            //
            // Tell the controller first: this fires about a second before the
            // `call-ended` broadcast, and without it the trailing hang-up
            // re-reports the call and overwrites who ended it.
            if (Get.isRegistered<CallController>()) {
              Get.find<CallController>().noteRemoteLeft();
            }
            if (mounted) {
              setState(() { _remoteUid = null; });
              _endCall();
            }
          } else {
            // Network issue — remote user may reconnect. Wait and try rejoining.
            if (mounted) {
              setState(() { _remoteUid = null; });
            }
            _scheduleReconnect();
          }
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('📞 Agora: Left channel');
          _silenceAnyRingtone();
          if (mounted) {
            setState(() {
              _localUserJoined = false;
              _remoteUid = null;
              _engineReady = false;
            });
          }
        },
        onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
        ) {
          debugPrint('📞 Agora: Connection state: $state (reason: $reason)');
          switch (state) {
            case ConnectionStateType.connectionStateConnecting:
            case ConnectionStateType.connectionStateReconnecting:
              if (mounted && !_isReconnecting) {
                setState(() { _isReconnecting = true; });
              }
              break;
            case ConnectionStateType.connectionStateConnected:
              _reconnectAttempts = 0;
              _isReconnecting = false;
              if (mounted) setState(() {});
              break;
            case ConnectionStateType.connectionStateDisconnected:
              if (reason == ConnectionChangedReasonType.connectionChangedTokenExpired ||
                  reason == ConnectionChangedReasonType.connectionChangedInvalidToken) {
                // Token expired or invalid — request a new one and rejoin
                debugPrint('📞 Agora: Disconnected due to token/auth issue');
                _handleTokenExpired();
              } else if (reason == ConnectionChangedReasonType.connectionChangedLost ||
                  reason == ConnectionChangedReasonType.connectionChangedInterrupted) {
                // Network lost — try reconnecting
                debugPrint('📞 Agora: Disconnected due to network change');
                _scheduleReconnect();
              }
              break;
            default:
              break;
          }
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('📞 Agora: Token will expire soon — requesting renewal');
          _renewToken();
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('📞 Agora ERROR: $err — $msg');
          // ERR_TOKEN_EXPIRED = 109, ERR_INVALID_TOKEN = 110
          if (err == ErrorCodeType.errTokenExpired ||
              err == ErrorCodeType.errInvalidToken) {
            _handleTokenExpired();
          }
        },
      ),
    );

    if (widget.isVideoCall) {
      await engine.enableVideo();
      await engine.startPreview();
    } else {
      await engine.enableAudio();
      await engine.disableVideo();
    }

    await _joinChannel();
  }

  /// Joins the Agora channel with the current token.
  Future<void> _joinChannel() async {
    if (_engine == null) return;
    await _engine!.joinChannel(
      token: _currentToken,
      channelId: widget.channelName,
      uid: widget.uid,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishCameraTrack: widget.isVideoCall,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: widget.isVideoCall,
      ),
    );
  }

  // ─── Token Renewal ──────────────────────────────────────────────────────

  /// Request a fresh Agora token from the server when the current one expires.
  Future<void> _renewToken() async {
    final int? callId = widget.callId;
    if (callId == null) {
      debugPrint('📞 Token renewal skipped: no callId');
      return;
    }
    try {
      final CallController? calls =
          Get.isRegistered<CallController>() ? Get.find<CallController>() : null;
      if (calls == null) return;
      final RtcCredentials? fresh = await calls.renewRtcToken(callId);
      if (fresh != null && mounted) {
        _currentToken = fresh.token;
        debugPrint('📞 Token renewed successfully');
        // Update token on the live engine
        await _engine?.renewToken(_currentToken);
      } else {
        debugPrint('📞 Token renewal returned null');
        _handleTokenExpired();
      }
    } catch (e) {
      debugPrint('📞 Token renewal failed: $e');
      _handleTokenExpired();
    }
  }

  void _handleTokenExpired() {
    if (_isEndingCall) return;
    _tokenExpired = true;
    // Try to get a fresh token and rejoin
    _renewToken();
  }

  // ─── Reconnection ───────────────────────────────────────────────────────

  void _scheduleReconnect() {
    if (_isEndingCall || _tokenExpired) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('📞 Max reconnect attempts reached — ending call');
      if (mounted) _endCall();
      return;
    }
    _isReconnecting = true;
    if (mounted) setState(() {});
    _publishTrayEntry();

    // Exponential backoff: 1s, 2s, 4s, 8s, … capped at 16s
    final int delayMs = (Duration(seconds: 1 << _reconnectAttempts).inMilliseconds).clamp(1000, 16000);
    _reconnectAttempts++;

    debugPrint('📞 Reconnecting in ${delayMs}ms (attempt $_reconnectAttempts)');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), _attemptReconnect);
  }

  Future<void> _attemptReconnect() async {
    if (_isEndingCall || !mounted) return;
    try {
      // Leave current channel cleanly first
      await _engine?.leaveChannel();
      // Small pause to let the connection reset
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (_isEndingCall || !mounted) return;
      await _joinChannel();
    } catch (e) {
      debugPrint('📞 Reconnect attempt failed: $e');
      _scheduleReconnect();
    }
  }

  // ─── Speaker (safe wrapper) ──────────────────────────────────────────────

  Future<void> _safeSpeaker() async {
    if (_engine == null) return;
    // Small delay to let the engine fully settle after join
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    try {
      await _engine!.setEnableSpeakerphone(_isSpeakerOn);
    } catch (e) {
      debugPrint('📞 Speaker toggle skipped: $e');
    }
  }

  // ─── Ringing Feedback ────────────────────────────────────────────────────
  // Play a system click sound every 2s to simulate ringing until remote joins.

  /// Stops whatever the incoming-call screen was ringing.
  ///
  /// This screen never starts a ringtone; it only makes sure none is left
  /// playing once the call is under way.
  void _silenceAnyRingtone() {
    NotificationService.instance.stopRingtone();
  }

  // ─── Call Timer ──────────────────────────────────────────────────────────

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDurationSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // ─── Call Controls ───────────────────────────────────────────────────────

  Future<void> _toggleMute() async {
    if (_engine == null || !_engineReady) return;
    setState(() {
      _isMuted = !_isMuted;
    });
    try {
      await _engine!.muteLocalAudioStream(_isMuted);
    } catch (e) {
      debugPrint('📞 Mute error: $e');
    }
  }

  Future<void> _toggleVideo() async {
    if (_engine == null || !_engineReady) return;
    setState(() {
      _isVideoDisabled = !_isVideoDisabled;
    });
    // With the camera off there is nothing worth a floating window, so leaving
    // the app should minimise it the way an audio call does.
    CallWindowService.instance.setPipEnabled(!_isVideoDisabled);
    try {
      if (_isVideoDisabled) {
        await _engine!.disableVideo();
        await _engine!.muteLocalVideoStream(true);
      } else {
        await _engine!.enableVideo();
        await _engine!.muteLocalVideoStream(false);
        await _engine!.startPreview();
      }
    } catch (e) {
      debugPrint('📞 Video toggle error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_engine == null || !_engineReady) return;
    try {
      await _engine!.switchCamera();
    } catch (e) {
      debugPrint('📞 Camera switch error: $e');
    }
  }

  Future<void> _toggleSpeaker() async {
    if (_engine == null || !_engineReady) return;
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    try {
      await _engine!.setEnableSpeakerphone(_isSpeakerOn);
    } catch (e) {
      debugPrint('📞 Speaker error: $e');
    }
  }

  Future<void> _endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;
    _reconnectTimer?.cancel();
    _callTimer?.cancel();
    _silenceAnyRingtone();
    _releaseCallWindow();
    CallStateService.instance.endCall();
    _declineSubscription?.cancel();
    _declineSubscription = null;
    if (_engine != null) {
      try {
        await _engine!.leaveChannel();
        await _engine!.release();
      } catch (_) {}
      _engine = null;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isEndingCall = true;
    _reconnectTimer?.cancel();
    _callTimer?.cancel();
    _silenceAnyRingtone();
    // The screen really is going now — nothing is left to minimise into, so
    // the tray entry and the microphone the service held both go with it.
    _releaseCallWindow();
    _declineSubscription?.cancel();
    _pipSubscription?.cancel();
    _callEndedWorker?.dispose();
    CallStateService.instance.endCall();
    try {
      _engine?.leaveChannel();
      _engine?.release();
    } catch (_) {}
    super.dispose();
  }

  // ─── Call Status Helper ──────────────────────────────────────────────────

  String get _callStatus {
    if (_isReconnecting) {
      return 'Reconnecting… ($_reconnectAttempts/$_maxReconnectAttempts)';
    }
    if (_remoteUid != null) {
      return 'Connected • ${_formatDuration(_callDurationSeconds)}';
    }
    if (_localUserJoined) {
      return 'Ringing…';
    }
    return 'Connecting…';
  }

  IconData get _callStatusIcon {
    if (_remoteUid != null) return Icons.call_rounded;
    if (_localUserJoined) return Icons.ring_volume_rounded;
    return Icons.wifi_calling_3_rounded;
  }

  Color get _callStatusColor {
    if (_remoteUid != null) return AppColors.success;
    if (_localUserJoined) return Colors.orangeAccent;
    return Colors.white54;
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool showVideoLayout = widget.isVideoCall && !_isVideoDisabled;

    if (_isPipMode) return _buildPipLayout(showVideoLayout);

    // `canPop: false` is what stops back from ending the call. The gesture is
    // handed to [_minimize] instead, which shrinks a video call into the
    // floating window and sends an audio call to the background — the route
    // itself, and with it the Agora engine, stays exactly where it is.
    //
    // It does not trap anyone: End is still on the controls, the peer hanging
    // up closes the screen through [_watchForCallEnd], and so does "End call"
    // on the notification.
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void _) {
        if (didPop) return;
        _minimize();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              // ── Main Video / Audio View ──────────────────────────────────
              if (showVideoLayout)
                _buildVideoLayout()
              else
                _buildAudioLayout(),

              // ── Top Bar Overlay ──────────────────────────────────────────
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: _buildTopBar(),
              ),

              // ── Bottom Call Controls ─────────────────────────────────────
              Positioned(
                bottom: 28,
                left: 16,
                right: 16,
                child: _buildBottomControls(showVideoLayout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The call as it has to read inside Android's floating window.
  ///
  /// A PiP window is a few centimetres across and the system scales the whole
  /// Flutter UI into it, so the ordinary layout arrives as a pile of unreadable
  /// smudges over the video. Everything but the picture is dropped: the window
  /// is tapped to come back to the full screen, so it needs no controls of its
  /// own.
  Widget _buildPipLayout(bool showVideoLayout) {
    final bool hasRemoteVideo =
        showVideoLayout && _remoteUid != null && _engine != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: hasRemoteVideo
          ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine!,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    backgroundImage:
                        widget.userPhoto != null && widget.userPhoto!.isNotEmpty
                            ? NetworkImage(widget.userPhoto!)
                            : null,
                    child: widget.userPhoto == null || widget.userPhoto!.isEmpty
                        ? Text(
                            widget.userName.isNotEmpty
                                ? widget.userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _remoteUid != null
                        ? _formatDuration(_callDurationSeconds)
                        : _callStatus,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildVideoLayout() {
    return Stack(
      children: <Widget>[
        // Remote Fullscreen Video
        Center(
          child: _remoteUid != null && _engine != null
              ? AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: RtcConnection(channelId: widget.channelName),
                  ),
                )
              : _buildWaitingView(),
        ),

        // Local Floating PIP Video
        if (_localUserJoined && _engine != null)
          Positioned(
            top: 75,
            right: 16,
            width: 110,
            height: 155,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.white24, width: 1.5),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Colors.black45, blurRadius: 8, spreadRadius: 2),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWaitingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
          backgroundImage: widget.userPhoto != null && widget.userPhoto!.isNotEmpty
              ? NetworkImage(widget.userPhoto!)
              : null,
          child: widget.userPhoto == null || widget.userPhoto!.isEmpty
              ? Text(
                  widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          widget.userName,
          style:
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(_callStatusIcon, color: _callStatusColor, size: 16),
            const SizedBox(width: 6),
            Text(
              _callStatus,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_remoteUid == null)
          const CircularProgressIndicator(color: AppColors.primary),
      ],
    );
  }

  Widget _buildAudioLayout() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Animated ring indicator around avatar
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _remoteUid != null ? AppColors.success : AppColors.primary,
                width: _remoteUid != null ? 3.0 : 2.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: (_remoteUid != null ? AppColors.success : AppColors.primary)
                      .withValues(alpha: 0.25),
                  blurRadius: _remoteUid != null ? 16 : 24,
                  spreadRadius: _remoteUid != null ? 4 : 8,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 58,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              backgroundImage: widget.userPhoto != null && widget.userPhoto!.isNotEmpty
                  ? NetworkImage(widget.userPhoto!)
                  : null,
              child: widget.userPhoto == null || widget.userPhoto!.isEmpty
                  ? Text(
                      widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            widget.userName,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(_callStatusIcon, color: _callStatusColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  _callStatus,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            // Minimise, not hang up. The red End button below is the only
            // control that ends a call now.
            icon: const Icon(Icons.expand_more_rounded, color: Colors.white, size: 22),
            tooltip: 'Minimise',
            onPressed: _minimize,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.userName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _callStatus,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (widget.isVideoCall)
            IconButton(
              icon: Icon(
                _isVideoDisabled ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                color: _isVideoDisabled ? Colors.white54 : AppColors.primary,
                size: 22,
              ),
              tooltip: _isVideoDisabled ? 'Enable Video' : 'Switch to Audio',
              onPressed: _toggleVideo,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(bool showVideo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          // Mute Button
          _controlButton(
            onPressed: _toggleMute,
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            bgColor: _isMuted ? Colors.white : Colors.white24,
            iconColor: _isMuted ? Colors.black : Colors.white,
            label: _isMuted ? 'Unmute' : 'Mute',
          ),

          // Speaker Button
          _controlButton(
            onPressed: _toggleSpeaker,
            icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
            bgColor: _isSpeakerOn ? AppColors.primary : Colors.white24,
            iconColor: Colors.white,
            label: 'Speaker',
          ),

          // Switch Camera (only when video is active)
          if (showVideo)
            _controlButton(
              onPressed: _switchCamera,
              icon: Icons.cameraswitch_rounded,
              bgColor: Colors.white24,
              iconColor: Colors.white,
              label: 'Flip',
            ),

          // End Call Button
          GestureDetector(
            onTap: _endCall,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: AppColors.error,
                  radius: 26,
                  child: Icon(Icons.call_end_rounded, color: Colors.white, size: 26),
                ),
                SizedBox(height: 4),
                Text('End', style: TextStyle(fontSize: 10, color: Colors.white54)),
              ],
            ),

          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String label,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            backgroundColor: bgColor,
            radius: 22,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ],
      ),
    );
  }
}
