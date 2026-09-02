import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../controllers/call_controller.dart';
import '../../../core/services/call_state_service.dart';
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

class _VideoCallScreenState extends State<VideoCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isVideoDisabled = false;
  bool _isSpeakerOn = true;
  bool _engineReady = false;
  Timer? _callTimer;
  Timer? _ringTimer;
  int _callDurationSeconds = 0;
  StreamSubscription<int>? _declineSubscription;

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
    _listenForDeclineSignals();
    _initAgora();
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
          _safeSpeaker();
          _startRinging();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('📞 Agora: Remote user $remoteUid joined');
          _stopRinging();
          if (Get.isRegistered<CallController>()) {
            Get.find<CallController>().markConnected();
          }
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
            });
            _startCallTimer();
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
            // Remote user deliberately left → end the call
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
          _stopRinging();
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

  void _startRinging() {
    _ringTimer?.cancel();
    NotificationService.instance.playRingtone();
    _ringTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_remoteUid != null) {
        _stopRinging();
        return;
      }
    });
  }

  void _stopRinging() {
    _ringTimer?.cancel();
    _ringTimer = null;
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
    _stopRinging();
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
    _isEndingCall = true;
    _reconnectTimer?.cancel();
    _callTimer?.cancel();
    _stopRinging();
    _declineSubscription?.cancel();
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

    return Scaffold(
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: _endCall,
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
