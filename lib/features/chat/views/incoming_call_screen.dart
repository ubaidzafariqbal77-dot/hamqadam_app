import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import 'video_call_screen.dart';

/// Full-screen incoming call dialog with Accept and Decline actions.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.channelName,
    required this.callerName,
    this.callerPhoto,
    this.isVideoCall = false,
    this.agoraToken,
    this.threadId,
  });

  final String channelName;
  final String callerName;
  final String? callerPhoto;
  final bool isVideoCall;
  final String? agoraToken;
  final int? threadId;

  /// Helper launcher to show the incoming call screen if not already visible.
  static bool isShowing = false;

  /// Helper launcher to show the incoming call screen as a full app overlay dialog.
  static Future<void> show({
    required String channelName,
    required String callerName,
    String? callerPhoto,
    bool isVideoCall = false,
    String? agoraToken,
    int? threadId,
  }) async {
    // Avoid opening duplicate incoming call screens or interrupting active calls
    if (isShowing || Get.currentRoute == '/VideoCallScreen') {
      return;
    }

    isShowing = true;

    await Get.dialog<void>(
      IncomingCallScreen(
        channelName: channelName,
        callerName: callerName,
        callerPhoto: callerPhoto,
        isVideoCall: isVideoCall,
        agoraToken: agoraToken,
        threadId: threadId,
      ),
      barrierDismissible: false,
      useSafeArea: false,
      barrierColor: Colors.black.withValues(alpha: 0.9),
    );

    isShowing = false;
  }

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _ringTimer;
  Timer? _autoTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _startRinging();

    // Auto timeout after 45 seconds if unhandled
    _autoTimeoutTimer = Timer(const Duration(seconds: 45), () {
      _declineCall();
    });
  }

  void _startRinging() {
    _ringTimer?.cancel();
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.vibrate();

    _ringTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.vibrate();
    });
  }

  void _stopRinging() {
    _ringTimer?.cancel();
    _ringTimer = null;
    _autoTimeoutTimer?.cancel();
    _autoTimeoutTimer = null;
  }

  void _acceptCall() {
    _stopRinging();
    IncomingCallScreen.isShowing = false;
    // Dismiss the incoming dialog first
    Get.back<void>();

    // Open the active call screen
    VideoCallScreen.open(
      channelName: widget.channelName,
      userName: widget.callerName,
      userPhoto: widget.callerPhoto,
      isVideoCall: widget.isVideoCall,
      token: widget.agoraToken ?? VideoCallScreen.defaultToken,
    );
  }

  void _declineCall() {
    _stopRinging();
    IncomingCallScreen.isShowing = false;
    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }
  }

  @override
  void dispose() {
    _stopRinging();
    IncomingCallScreen.isShowing = false;
    _animController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final String callTypeLabel =
        widget.isVideoCall ? 'Incoming Video Call' : 'Incoming Voice Call';
    final IconData callTypeIcon =
        widget.isVideoCall ? Icons.videocam_rounded : Icons.call_rounded;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) _declineCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 32),

              // ── Top Pill Badge ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(callTypeIcon, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      callTypeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Pulsating Avatar Waves ─────────────────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (BuildContext context, Widget? child) {
                    final double progress = _animController.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // Outer wave 2
                        Container(
                          width: 140 + (progress * 60),
                          height: 140 + (progress * 60),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(
                                alpha: (1.0 - progress) * 0.3,
                              ),
                              width: 2,
                            ),
                          ),
                        ),
                        // Outer wave 1
                        Container(
                          width: 140 + (progress * 30),
                          height: 140 + (progress * 30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(
                                alpha: (1.0 - progress) * 0.5,
                              ),
                              width: 2.5,
                            ),
                          ),
                        ),
                        // Central Avatar
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 3),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 30,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 65,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                            backgroundImage: widget.callerPhoto != null &&
                                    widget.callerPhoto!.isNotEmpty
                                ? NetworkImage(widget.callerPhoto!)
                                : null,
                            child: widget.callerPhoto == null ||
                                    widget.callerPhoto!.isEmpty
                                ? Text(
                                    widget.callerName.isNotEmpty
                                        ? widget.callerName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 28),

              // ── Caller Name ────────────────────────────────────────────────
              Text(
                widget.callerName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'is calling you…',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white60,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(flex: 3),

              // ── Accept & Decline Buttons ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // Decline Action
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        GestureDetector(
                          onTap: _declineCall,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.error,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.4),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.call_end_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Decline',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Accept Action
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        GestureDetector(
                          onTap: _acceptCall,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AppColors.success.withValues(alpha: 0.45),
                                  blurRadius: 20,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Icon(
                              callTypeIcon,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Accept',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
