import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/services/call_signaling_service.dart';
import '../../../core/services/call_state_service.dart';
import '../views/incoming_call_screen.dart';
import '../views/video_call_screen.dart';

/// WhatsApp-style floating top call banner overlay with quick Accept & Decline.
class IncomingCallOverlayBar {
  static OverlayEntry? _currentEntry;
  static Timer? _ringTimer;
  static Timer? _autoDismissTimer;

  static bool get isShowing => _currentEntry != null;

  /// Shows the top floating incoming call bar.
  static void show({
    required String channelName,
    required String callerName,
    String? callerPhoto,
    bool isVideoCall = false,
    int? threadId,
  }) {
    // Avoid duplicate overlays if already showing or on active call screen
    if (_currentEntry != null ||
        Get.currentRoute == '/VideoCallScreen' ||
        Get.currentRoute == '/IncomingCallScreen') {
      return;
    }

    final OverlayState? overlayState = Get.overlayContext != null
        ? Overlay.of(Get.overlayContext!)
        : null;

    if (overlayState == null) {
      // Fallback directly to full-screen incoming modal
      IncomingCallScreen.show(
        channelName: channelName,
        callerName: callerName,
        callerPhoto: callerPhoto,
        isVideoCall: isVideoCall,
        threadId: threadId,
      );
      return;
    }

    _startRingtoneLoop();

    _currentEntry = OverlayEntry(
      builder: (BuildContext context) => _FloatingCallBannerWidget(
        channelName: channelName,
        callerName: callerName,
        callerPhoto: callerPhoto,
        isVideoCall: isVideoCall,
        threadId: threadId,
        onAccept: () {
          dismiss();
          VideoCallScreen.open(
            channelName: channelName,
            userName: callerName,
            userPhoto: callerPhoto,
            isVideoCall: isVideoCall,
          );
        },
        onDecline: () {
          dismiss();
          _sendDeclineSignal(threadId);
        },
        onTapBanner: () {
          IncomingCallScreen.expandFromOverlay(
            channelName: channelName,
            callerName: callerName,
            callerPhoto: callerPhoto,
            isVideoCall: isVideoCall,
            threadId: threadId,
          );
        },
      ),
    );

    overlayState.insert(_currentEntry!);

    // Auto-dismiss after 40 seconds
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 40), () {
      dismiss();
    });
  }

  static void _startRingtoneLoop() {
    _ringTimer?.cancel();
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.vibrate();

    _ringTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.vibrate();
    });
  }

  /// Dismisses the floating overlay and stops ringtone.
  static void dismiss() {
    _ringTimer?.cancel();
    _ringTimer = null;
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;

    if (_currentEntry != null) {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }

  /// Sends a decline signal back to the caller via chat message.
  static void _sendDeclineSignal(int? threadId) {
    if (threadId == null || threadId <= 0) return;
    CallStateService.instance.endCall();
    // Find the active ChatController to get the thread's participant info
    if (Get.isRegistered<ChatController>()) {
      final ChatController chatCtrl = Get.find<ChatController>();
      final dynamic activeThread = chatCtrl.activeThread.value;
      int recipientId = 0;
      if (activeThread != null && activeThread.id == threadId) {
        recipientId = activeThread.participant.id;
      }
      if (recipientId > 0) {
        CallSignalingService.instance.sendCallDecline(
          threadId: threadId,
          recipientUserId: recipientId,
        );
      }
    }
  }
}

class _FloatingCallBannerWidget extends StatefulWidget {
  const _FloatingCallBannerWidget({
    required this.channelName,
    required this.callerName,
    this.callerPhoto,
    required this.isVideoCall,
    this.threadId,
    required this.onAccept,
    required this.onDecline,
    required this.onTapBanner,
  });

  final String channelName;
  final String callerName;
  final String? callerPhoto;
  final bool isVideoCall;
  final int? threadId;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTapBanner;

  @override
  State<_FloatingCallBannerWidget> createState() =>
      _FloatingCallBannerWidgetState();
}

class _FloatingCallBannerWidgetState extends State<_FloatingCallBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _slideAnim,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onTapBanner,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2630),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  // Caller Avatar
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 24,
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
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Caller Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          widget.callerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Icon(
                              widget.isVideoCall
                                  ? Icons.videocam_rounded
                                  : Icons.call_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.isVideoCall
                                  ? 'Incoming Video Call…'
                                  : 'Incoming Voice Call…',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Decline Button
                  IconButton(
                    onPressed: widget.onDecline,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error,
                      ),
                      child: const Icon(
                        Icons.call_end_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),

                  // Accept Button
                  IconButton(
                    onPressed: widget.onAccept,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                      child: Icon(
                        widget.isVideoCall
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
