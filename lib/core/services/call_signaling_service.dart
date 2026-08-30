import 'dart:convert';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../features/chat/widgets/incoming_call_overlay_bar.dart';
import '../../repositories/chat_repository.dart';
import '../storage/current_user_service.dart';
import '../utils/app_logger.dart';
import 'call_state_service.dart';
import 'notification_service.dart';


/// Real-time call signaling service to invite, accept, and decline calls across devices.
class CallSignalingService {
  CallSignalingService._();
  static final CallSignalingService instance = CallSignalingService._();

  static const String invitePrefix = '[CALL_INVITE:';
  static const String declinePrefix = '[CALL_DECLINED:';

  /// Generates a clean channel name that won't trigger backend phone number filters.
  static String getChannelName(int threadId) => 'call_thread_$threadId';

  /// Sends a call invitation signal to the recipient.
  Future<void> sendCallInvite({
    required int threadId,
    required int recipientUserId,
    required String channelName,
    required bool isVideoCall,
    required String callerName,
    String? callerPhoto,
  }) async {
    try {
      final String safeChannel = getChannelName(threadId);
      final String encodedPhoto = Uri.encodeComponent(callerPhoto ?? '');
      final String encodedName = Uri.encodeComponent(callerName);
      final String signalMessage =
          '$invitePrefix'
          'ch=$safeChannel&'
          'vid=${isVideoCall ? "1" : "0"}&'
          'name=$encodedName&'
          'photo=$encodedPhoto&'
          'th=$threadId]';

      if (Get.isRegistered<ChatRepository>()) {
        final ChatRepository repo = Get.find<ChatRepository>();
        await repo.sendMessage(
          threadId: threadId,
          message: signalMessage,
          messageType: 'text',
          recipientUserId: recipientUserId,
        );
      }
    } catch (e) {
      AppLogger.w('Failed to send call invite signal: $e');
    }
  }

  /// Sends a call decline signal to the caller.
  Future<void> sendCallDecline({
    required int threadId,
    required int recipientUserId,
  }) async {
    try {
      final String signalMessage = '$declinePrefix th=$threadId]';
      if (Get.isRegistered<ChatRepository>()) {
        final ChatRepository repo = Get.find<ChatRepository>();
        await repo.sendMessage(
          threadId: threadId,
          message: signalMessage,
          messageType: 'text',
          recipientUserId: recipientUserId,
        );
      }
      // Also end local call state
      CallStateService.instance.endCall();
      IncomingCallOverlayBar.dismiss();
    } catch (e) {
      AppLogger.w('Failed to send call decline signal: $e');
    }
  }

  /// Intercepts and parses incoming chat/pusher messages to detect call
  /// invitations AND decline signals.
  bool handleIncomingSignal({
    required String message,
    required int senderId,
    int? threadId,
    String? senderName,
    String? senderPhoto,
  }) {
    final int myUserId = _getMyUserId();

    // ── Handle decline signals ──────────────────────────────────────────────
    if (message.startsWith(declinePrefix)) {
      if (senderId > 0 && senderId == myUserId) return false; // ignore self
      final int resolvedThreadId = threadId ?? 0;
      AppLogger.i('📞 Call decline signal received for thread $resolvedThreadId');
      // Notify the active outgoing call screen to auto-end
      CallStateService.instance.notifyDeclined(resolvedThreadId);
      // Clean up incoming call UI if showing
      IncomingCallOverlayBar.dismiss();
      return true;
    }

    // ── Handle invite signals ───────────────────────────────────────────────
    if (!message.startsWith(invitePrefix)) {
      return false;
    }

    // Do not trigger incoming banner for the caller themselves
    if (senderId > 0 && senderId == myUserId) {
      return false;
    }

    // If already in a call, reject new incoming call
    if (CallStateService.instance.isInCall) {
      AppLogger.i('📞 Incoming call rejected — already in a call');
      return false;
    }

    try {
      final String content = message
          .substring(invitePrefix.length, message.length - (message.endsWith(']') ? 1 : 0));

      final Map<String, String> params = <String, String>{};
      final List<String> pairs = content.split('&');
      for (final String pair in pairs) {
        final List<String> kv = pair.split('=');
        if (kv.length >= 2) {
          params[kv[0]] = kv.sublist(1).join('=');
        }
      }

      final int resolvedThreadId = int.tryParse(params['th'] ?? params['threadId'] ?? '') ?? (threadId ?? 0);

      // Support new short keys ('ch') and legacy ('channel')
      String channelName = params['ch'] ?? params['channel'] ?? '';
      // If server filtered phone digits or channel name is empty, fall back to safe channel name
      if (channelName.isEmpty || channelName.contains('[phone') || channelName.contains('hidden')) {
        channelName = getChannelName(resolvedThreadId);
      }

      final bool isVideoCall = params['vid'] == '1' || params['isVideo'] == 'true';
      final String rawName = params['name'] ?? params['callerName'] ?? '';
      final String callerName = rawName.isNotEmpty
          ? Uri.decodeComponent(rawName)
          : (senderName ?? 'Hamqadam Member');
      final String rawPhoto = params['photo'] ?? params['callerPhoto'] ?? '';
      final String? callerPhoto = rawPhoto.isNotEmpty
          ? Uri.decodeComponent(rawPhoto)
          : senderPhoto;

      AppLogger.i('📞 Incoming Call Signal Detected: $callerName (channel: $channelName, video: $isVideoCall)');

      // Mark incoming call as active in global state
      CallStateService.instance.startIncoming(
        channelName: channelName,
        threadId: resolvedThreadId,
        isVideo: isVideoCall,
      );

      // 1. Show WhatsApp-style floating top banner (less intrusive first)
      IncomingCallOverlayBar.show(
        channelName: channelName,
        callerName: callerName,
        callerPhoto: callerPhoto,
        isVideoCall: isVideoCall,
        threadId: resolvedThreadId,
      );

      // 2. Show notification banner in device tray
      NotificationService.instance.showNotification(
        id: channelName.hashCode,
        title: isVideoCall ? '📹 Incoming Video Call' : '📞 Incoming Voice Call',
        body: '$callerName is calling you on Hamqadam…',
        payload: jsonEncode(<String, dynamic>{
          'type': 'call_invite',
          'channelName': channelName,
          'callerName': callerName,
          'callerPhoto': callerPhoto,
          'isVideoCall': isVideoCall,
          'threadId': resolvedThreadId,
        }),
      );

      return true;
    } catch (e) {
      AppLogger.w('Error parsing call signal: $e');
      return false;
    }
  }

  int _getMyUserId() {
    if (Get.isRegistered<CurrentUserService>()) {
      final int id = Get.find<CurrentUserService>().user?.id ?? 0;
      if (id > 0) return id;
    }
    if (Get.isRegistered<ChatController>()) {
      final int id = Get.find<ChatController>().myUserId;
      if (id > 0) return id;
    }
    if (Get.isRegistered<AuthController>()) {
      final int id = Get.find<AuthController>().user.value?.id ?? 0;
      if (id > 0) return id;
    }
    return 0;
  }
}

