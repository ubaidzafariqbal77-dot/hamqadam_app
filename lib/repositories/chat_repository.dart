import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/chat_model.dart';

/// All REST calls for the Chat feature.
///
/// Realtime events are handled separately by [ChatController] / Pusher.
class ChatRepository {
  ChatRepository(this._client);

  final ApiClient _client;

  // --------------------------------------------------------------------------
  // Threads
  // --------------------------------------------------------------------------

  /// `GET /chat/threads` — inbox / conversation list.
  Future<List<ChatThread>> fetchThreads({int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.chatThreads,
      query: <String, dynamic>{'per_page': perPage},
    );
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().map(ChatThread.fromJson).toList();
  }

  // --------------------------------------------------------------------------
  // Messages
  // --------------------------------------------------------------------------

  /// `GET /chat/threads/{thread}/messages` — paginated messages.
  Future<ChatMessagesPage> fetchMessages(int threadId, {int page = 1, int perPage = 30}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.chatMessages(threadId),
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return ChatMessagesPage.fromJson(<String, dynamic>{
      'data': res.dataList.isNotEmpty ? res.dataList : <dynamic>[],
      'meta': res.meta,
    });
  }

  // --------------------------------------------------------------------------
  // Send
  // --------------------------------------------------------------------------

  /// `POST /chat/threads/{thread}/messages` — creates and broadcasts a message.
  Future<ChatMessage> sendMessage({
    required int threadId,
    required String message,
    String messageType = 'text',
    int? replyToChatId,
    int? recipientUserId,
    List<String> attachmentPaths = const <String>[],
    Map<String, dynamic>? metadata,
    int disappearAfter = 0,
  }) async {
    final ApiEnvelope res;
    if (attachmentPaths.isNotEmpty) {
      final Map<String, dynamic> fields = <String, dynamic>{
        'message': message,
        'message_type': messageType,
      };
      if (disappearAfter > 0) {
        fields['disappear_after'] = '$disappearAfter';
      }
      if (replyToChatId != null && replyToChatId > 0) {
        fields['reply_to_chat_id'] = replyToChatId.toString();
        fields['reply_to_id'] = replyToChatId.toString();
      }
      if (recipientUserId != null && recipientUserId > 0) {
        fields['receiver_id'] = recipientUserId.toString();
        fields['recipient_id'] = recipientUserId.toString();
        fields['user_id'] = recipientUserId.toString();
      }
      if (metadata != null) {
        fields['metadata[duration]'] = '${metadata['duration'] ?? ''}';
        final List<int> wave =
            ((metadata['waveform'] as List<dynamic>?) ?? const <dynamic>[]).map((dynamic e) => (e as num).toInt()).toList();
        for (int i = 0; i < wave.length; i++) {
          fields['metadata[waveform][$i]'] = '${wave[i]}';
        }
      }
      res = await _client.multipart(
        ApiEndpoints.chatSend(threadId),
        fields: fields,
        arrayFiles: <String, List<String>>{
          'attachments': attachmentPaths,
        },
      );
    } else {
      final Map<String, dynamic> body = <String, dynamic>{
        'message': message,
        'message_type': messageType,
        'attachments': <dynamic>[],
      };
      if (disappearAfter > 0) {
        body['disappear_after'] = disappearAfter;
      }
      if (replyToChatId != null && replyToChatId > 0) {
        body['reply_to_chat_id'] = replyToChatId;
        body['reply_to_id'] = replyToChatId;
      }
      if (recipientUserId != null && recipientUserId > 0) {
        body['receiver_id'] = recipientUserId;
        body['recipient_id'] = recipientUserId;
        body['user_id'] = recipientUserId;
      }
      if (metadata != null) {
        body['metadata'] = metadata;
      }
      res = await _client.post(
        ApiEndpoints.chatSend(threadId),
        body: body,
      );
    }
    return ChatMessage.fromJson(res.dataMap);
  }

  // --------------------------------------------------------------------------
  // Typing
  // --------------------------------------------------------------------------

  /// `POST /chat/threads/{thread}/typing` — broadcasts typing state.
  Future<void> sendTyping(int threadId) async {
    try {
      await _client.post(ApiEndpoints.chatTyping(threadId));
    } catch (_) {
      // Typing indicator failure is non-fatal
    }
  }

  /// `POST /chat/threads/{thread}/delivered` — acknowledges having the
  /// thread's messages on device, turning the sender's single tick into a
  /// double tick. Non-fatal by design.
  Future<void> markThreadDelivered(int threadId) async {
    try {
      await _client.post(ApiEndpoints.chatDelivered(threadId));
    } catch (_) {
      // A failed delivery ping must never break the conversation; the next
      // open/retry re-asserts it.
    }
  }

  /// `POST /chat/threads/{thread}/disappear` — persists the thread's
  /// disappearing-message TTL (seconds; 0 = off). Returns the stored value.
  Future<int> setDisappearAfter(int threadId, int seconds) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.chatDisappear(threadId),
      body: <String, dynamic>{'disappear_after': seconds.clamp(0, 31536000)},
    );
    final dynamic data = res.dataMap['disappear_after'];
    return data is num ? data.toInt() : seconds;
  }

  // --------------------------------------------------------------------------
  // Thread actions
  // --------------------------------------------------------------------------

  /// `POST /chat/threads/{thread}/block`
  Future<void> blockThread(int threadId) async {
    await _client.post(ApiEndpoints.chatBlock(threadId));
  }

  /// `POST /chat/threads/{thread}/unblock`
  Future<void> unblockThread(int threadId) async {
    await _client.post(ApiEndpoints.chatUnblock(threadId));
  }

  /// `POST /chat/threads/{thread}/clear` — hides history for current user.
  Future<void> clearThread(int threadId) async {
    await _client.post(ApiEndpoints.chatClear(threadId));
  }

  /// `POST /chat/threads/{thread}/report`
  Future<void> reportThread(int threadId, {required String reason}) async {
    await _client.post(
      ApiEndpoints.chatReport(threadId),
      body: <String, dynamic>{'reason': reason},
    );
  }

  // --------------------------------------------------------------------------
  // Message actions
  // --------------------------------------------------------------------------

  /// `DELETE /chat/messages/{message}` — hides from current user's view.
  Future<void> deleteMessage(int messageId) async {
    await _client.delete(ApiEndpoints.chatDeleteMessage(messageId));
  }
}
