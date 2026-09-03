import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../controllers/call_controller.dart';
import '../../../core/services/notification_service.dart';
import '../widgets/incoming_call_overlay_bar.dart';

/// Full-screen incoming call dialog with Accept and Decline actions.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    this.callerPhoto,
    this.isVideoCall = false,
    this.threadId,
    this.ringSeconds = 0,
  });

  /// The server's `calls.id`. Accept and Decline are `POST /calls/{id}/accept`
  /// and `/reject`, so the Agora channel and token are the server's to hand
  /// out — the screen never needs to know them.
  final int callId;

  final String callerName;
  final String? callerPhoto;
  final bool isVideoCall;
  final int? threadId;

  /// Seconds left on the server's `ring_expires_at`. The dialog closes itself
  /// when they run out, so the local timeout can never outlive the call the
  /// backend has already written off as missed.
  final int ringSeconds;

  /// Helper launcher to show the incoming call screen if not already visible.
  static bool isShowing = false;

  /// Helper launcher to show the incoming call screen as a full app overlay dialog.
  static Future<void> show({
    required int callId,
    required String callerName,
    String? callerPhoto,
    bool isVideoCall = false,
    int? threadId,
    int ringSeconds = 0,
  }) async {
    // Avoid opening duplicate incoming call screens or interrupting active calls
    if (isShowing || Get.currentRoute.contains('VideoCallScreen')) {
      return;
    }

    isShowing = true;

    await Get.dialog<void>(
      IncomingCallScreen(
        callId: callId,
        callerName: callerName,
        callerPhoto: callerPhoto,
        isVideoCall: isVideoCall,
        threadId: threadId,
        ringSeconds: ringSeconds,
      ),
      barrierDismissible: false,
      useSafeArea: false,
      barrierColor: Colors.black.withValues(alpha: 0.9),
    );

    isShowing = false;
  }

  /// Closes the dialog if it is up — used when the caller hangs up before the
  /// member got to either button.
  static void dismissIfShowing() {
    IncomingCallOverlayBar.dismiss();
    if (!isShowing) return;
    isShowing = false;
    if (Get.isDialogOpen ?? false) Get.back<void>();
  }

  /// Tapping the floating overlay bar should expand to full-screen incoming
  /// call dialog. Dismisses the overlay bar first.
  static Future<void> expandFromOverlay({
    required int callId,
    required String callerName,
    String? callerPhoto,
    bool isVideoCall = false,
    int? threadId,
    int ringSeconds = 0,
  }) async {
    IncomingCallOverlayBar.dismiss();
    await show(
      callId: callId,
      callerName: callerName,
      callerPhoto: callerPhoto,
      isVideoCall: isVideoCall,
      threadId: threadId,
      ringSeconds: ringSeconds,
    );
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

    // Close when the server's ring window closes. `CallController` reports the
    // call missed at the same moment, so a local guess here would only put the
    // two out of step; 45s is the fallback for a payload without an expiry.
    final int seconds = widget.ringSeconds > 0 ? widget.ringSeconds : 45;
    _autoTimeoutTimer = Timer(Duration(seconds: seconds), _dismissOnTimeout);
  }

  void _startRinging() {
    _ringTimer?.cancel();
    NotificationService.instance.playRingtone();
  }

  void _stopRinging() {
    _ringTimer?.cancel();
    _ringTimer = null;
    _autoTimeoutTimer?.cancel();
    _autoTimeoutTimer = null;
    NotificationService.instance.stopRingtone();
  }

  /// Accept: the server hands back this member's own Agora credentials and
  /// tells the caller over `call-accepted`. The controller opens the call
  /// screen, so this only has to get out of the way.
  void _acceptCall() {
    _close();
    _calls?.acceptIncoming(widget.callId);
  }

  /// Decline: `POST /calls/{id}/reject`, which is what puts a declined call in
  /// the same log the website writes.
  void _declineCall() {
    _close();
    _calls?.rejectIncoming(widget.callId);
  }

  /// The ring window closed with no answer. The controller reports the call
  /// missed; declining here as well would log the wrong outcome.
  void _dismissOnTimeout() {
    _close();
  }

  CallController? get _calls =>
      Get.isRegistered<CallController>() ? Get.find<CallController>() : null;

  void _close() {
    _stopRinging();
    IncomingCallScreen.isShowing = false;
    IncomingCallOverlayBar.dismiss();
    if (Get.isDialogOpen ?? false) Get.back<void>();
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
