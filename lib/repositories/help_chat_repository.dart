import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/help_chat_model.dart';

/// All REST calls for the Help Center chat.
///
/// Realtime events are handled separately by [HelpChatController] / Pusher;
/// these calls are the authoritative read/write path, exactly like the
/// member-to-member chat.
class HelpChatRepository {
  HelpChatRepository(this._client);

  final ApiClient _client;

  /// `GET /help-chat/thread` — the member's conversation, created on first
  /// use. Opening it also clears the unread count server-side.
  Future<HelpChatThread> fetchThread() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.helpChatThread);
    return HelpChatThread.fromJson(res.dataMap);
  }

  /// `GET /help-chat/messages` — paginated messages, newest first.
  Future<HelpChatMessagesPage> fetchMessages({int page = 1, int perPage = 50}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.helpChatMessages,
      query: <String, dynamic>{'page': page, 'per_page': perPage},
    );
    return HelpChatMessagesPage.fromJson(<String, dynamic>{
      'data': res.dataList.isNotEmpty ? res.dataList : <dynamic>[],
      'meta': res.meta,
    });
  }

  /// `POST /help-chat/messages` — sends the member's issue / reply.
  ///
  /// Attachments go up as multipart the same way the member chat does.
  Future<HelpChatMessage> sendMessage({
    required String message,
    List<String> attachmentPaths = const <String>[],
  }) async {
    final ApiEnvelope res;
    if (attachmentPaths.isNotEmpty) {
      res = await _client.multipart(
        ApiEndpoints.helpChatMessages,
        fields: <String, dynamic>{
          if (message.isNotEmpty) 'message': message,
        },
        arrayFiles: <String, List<String>>{
          'attachments': attachmentPaths,
        },
      );
    } else {
      res = await _client.post(
        ApiEndpoints.helpChatMessages,
        body: <String, dynamic>{'message': message},
      );
    }
    return HelpChatMessage.fromJson(res.dataMap);
  }
}
