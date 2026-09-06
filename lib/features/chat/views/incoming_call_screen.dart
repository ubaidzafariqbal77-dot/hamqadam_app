import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/call_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../models/call_model.dart';
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
    this.launchedTheApp = false,
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

  /// True when this screen *is* the app's first route, i.e. the process was
  /// started by this call. Decides where to go when the screen closes: there is
  /// no route underneath to pop back to.
  final bool launchedTheApp;

  /// Whether a ringing screen is currently on the navigator.
  static bool isShowing = false;

  /// Arguments for the case where this screen is the app's `initialRoute`.
  ///
  /// `Get.arguments` is only populated by a navigation call, and an initial
  /// route is not one — so `main()` leaves the launch details here instead.
  static Map<String, dynamic>? launchArguments;

  /// Builds the screen from `Get.arguments` — the entry point used when this is
  /// the app's **initial** route, which is how a call that arrived at a killed
  /// app gets straight to Accept/Decline with no splash in the way.
  static Widget fromRouteArguments() {
    final Object? raw = Get.arguments ?? launchArguments;
    final Map<String, dynamic> args =
        raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    return IncomingCallScreen(
      callId: int.tryParse('${args['callId']}') ?? 0,
      callerName: (args['callerName'] ?? 'HamQadam Member').toString(),
      callerPhoto: args['callerPhoto'] as String?,
      isVideoCall: args['isVideoCall'] == true,
      threadId: args['threadId'] as int?,
      ringSeconds: int.tryParse('${args['ringSeconds']}') ?? 0,
      launchedTheApp: args['launchedTheApp'] == true,
    );
  }

  /// Puts the ringing screen up.
  ///
  /// A pushed **route**, not a `Get.dialog`. As a dialog this was destroyed by
  /// any `Get.offAllNamed` — which is exactly what the splash does 1.4 s into a
  /// cold start, so a call that woke the app from dead showed its screen for one
  /// frame and then vanished, leaving the tray ringing next to the Discover
  /// page. A route also lets the same screen be `initialRoute`, so the app can
  /// open *on* the call instead of navigating to it after booting.
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

    await Get.toNamed<dynamic>(
      AppRoutes.incomingCall,
      arguments: <String, dynamic>{
        'callId': callId,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
        'isVideoCall': isVideoCall,
        'threadId': threadId,
        'ringSeconds': ringSeconds,
        'launchedTheApp': false,
      },
    );

    isShowing = false;
  }

  /// Closes the ringing screen if it is up — used when the caller hangs up
  /// before the member got to either button.
  static void dismissIfShowing() {
    IncomingCallOverlayBar.dismiss();
    if (!isShowing) return;
    isShowing = false;
    if (Get.currentRoute == AppRoutes.incomingCall) _leave();
  }

  /// Leaves the ringing screen.
  ///
  /// When the call *was* the app's first screen there is nothing underneath to
  /// pop back to, so the normal startup flow is started instead — otherwise
  /// declining a call from a cold start would drop the member on a blank
  /// navigator.
  static void _leave() {
    if (Get.previousRoute.isEmpty) {
      Get.offAllNamed<dynamic>(AppRoutes.splash);
    } else {
      Get.back<void>();
    }
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
  Worker? _callerWatch;

  /// True once Accept has been pressed. The screen then renders a plain dark
  /// surface and stops navigating, so the call screen can open on top of it
  /// without the member seeing anything in between.
  bool _accepted = false;

  /// The caller's photo, which the *push* cannot supply.
  ///
  /// A call that arrives at a killed app is drawn from the record the FCM
  /// isolate wrote down, and the payload carries only a name — so a cold start
  /// would show the initial letter for the whole ring, where the same call
  /// answered with the app open shows a photo. `CallController.ringFromPush`
  /// fetches the real call a moment later; this picks the photo up from it.
  String? _photo;

  @override
  void initState() {
    super.initState();
    // Claimed here, not only in `show()`, because a cold start builds this
    // screen as the initial route without going through `show()`. Without the
    // flag the recovery pass in `AppLifecycleService` would call `show()` a
    // moment later and stack a second ringing screen on top of this one.
    IncomingCallScreen.isShowing = true;
    _photo = widget.callerPhoto;
    _watchForCallerDetails();

    // Re-assert the lock-screen flags on the activity. The manifest sets them,
    // but they are only read when the activity is created — and a backgrounded
    // app is brought forward by the full-screen intent without a create, which
    // is precisely the case where the ring must appear over the keyguard.
    NotificationService.instance.beginCallScreen();

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
    _stopRinging();
    IncomingCallScreen.isShowing = false;
    IncomingCallOverlayBar.dismiss();
    // Answering over the keyguard is the whole point of the lock-screen ring,
    // so take the lock screen away rather than making the member dismiss it
    // before they can talk.
    NotificationService.instance.dismissKeyguard();

    // No navigation here at all — this screen simply goes dark and the call
    // screen opens on top of it.
    //
    // Popping first is wrong in both directions. `_close()` routes to the
    // splash when this was the launch route, and the splash's own
    // `Get.offAllNamed` lands 1.4 s later, right on top of the call screen and
    // tears it down. Routing to Home instead fixed that but made Home flash up
    // for the moment between Accept and the call connecting — the reported
    // "accept karte to kuch time k lye app a jata phir connection screen".
    //
    // Staying put avoids both: nothing moves, and when the call screen is
    // dismissed the worker below takes this route away.
    setState(() => _accepted = true);
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
    // A cold start opens straight onto this screen, so there may be nothing
    // beneath it — popping would leave an empty navigator.
    if (widget.launchedTheApp || Get.previousRoute.isEmpty) {
      // Home, not the splash: the splash re-runs the whole bootstrap and shows
      // its animation for 1.4 s, which is a long time to look at after hanging
      // up. The splash is only right when there is no session to go home to.
      final bool signedIn = Get.isRegistered<AuthController>() &&
          Get.find<AuthController>().hasToken;
      Get.offAllNamed<dynamic>(signedIn ? AppRoutes.home : AppRoutes.splash);
    } else if (Get.currentRoute == AppRoutes.incomingCall) {
      Get.back<void>();
    }
  }

  /// Picks up the caller's photo as soon as the controller has loaded the call.
  void _watchForCallerDetails() {
    final CallController? calls = _calls;
    if (calls == null) return;
    _callerWatch = ever<CallModel?>(calls.activeCall, (CallModel? call) {
      if (!mounted) return;
      // The call finished while this route was sitting dark underneath the
      // call screen — take it away, or the member is left on a black page.
      if (call == null) {
        if (_accepted) _close();
        return;
      }
      if (call.id != widget.callId) return;
      final String? photo = call.caller?.photoUrl;
      if (photo == null || photo.isEmpty) return;
      setState(() => _photo = photo);
    });
  }

  @override
  void dispose() {
    _stopRinging();
    _callerWatch?.dispose();
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

    // Accepted: render nothing but the call screen's own background colour.
    // The call screen is opening on top of this route, and the member must not
    // see the ringing UI, Home, or a white flash in between.
    if (_accepted) {
      return const Scaffold(backgroundColor: Color(0xFF0D1117));
    }

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
                            backgroundImage: _photo != null &&
                                    _photo!.isNotEmpty
                                ? NetworkImage(_photo!)
                                : null,
                            child: _photo == null || _photo!.isEmpty
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
