import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../exceptions/app_exceptions.dart';
import '../models/call_model.dart';

/// The audio / video calling API — the same endpoints the website uses, so a
/// mobile call creates the same `calls` row, the same Agora channel and the
/// same server-side log entries as a web one.
///
/// The app used to run its own parallel scheme: it invented a channel name,
/// posted a `[CALL_INVITE:…]` chat message and polled the thread every three
/// seconds. Nothing about that reached the backend's call system, which is why
/// mobile calls never appeared in the logs, never rang a device that had the
/// app closed, and could not reach a web user.
class CallRepository {
  CallRepository(this._client);

  final ApiClient _client;

  /// `POST /calls` — creates the call, rings the other member over Pusher and
  /// returns the CALLER's own Agora credentials.
  ///
  /// Throws [AppException] with code `user_busy` (409) when either side is
  /// already on a call, and `agora_config_missing` (503) when the server has no
  /// Agora certificate configured.
  Future<CallSession> start({required int threadId, required bool isVideo}) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.callStart,
      body: <String, dynamic>{
        'chat_thread_id': threadId,
        'call_type': isVideo ? 'video' : 'audio',
      },
    );
    return _session(res);
  }

  /// `POST /calls/{id}/accept` — returns the RECEIVER's own Agora credentials.
  Future<CallSession> accept(int callId) async {
    final ApiEnvelope res = await _client.post(ApiEndpoints.callAccept(callId));
    return _session(res);
  }

  /// `POST /calls/{id}/reject` — receiver declines. No credentials come back.
  Future<void> reject(int callId) => _act(ApiEndpoints.callReject(callId));

  /// `POST /calls/{id}/cancel` — caller hangs up before it was answered.
  Future<void> cancel(int callId) => _act(ApiEndpoints.callCancel(callId));

  /// `POST /calls/{id}/connect` — both sides are in the Agora channel. This is
  /// what makes `duration_seconds` meaningful in the call log.
  Future<void> connect(int callId) => _act(ApiEndpoints.callConnect(callId));

  /// `POST /calls/{id}/end` — normal hang-up.
  Future<void> end(int callId) => _act(ApiEndpoints.callEnd(callId));

  /// `POST /calls/{id}/missed` — nobody picked up before `ring_expires_at`.
  Future<void> missed(int callId) => _act(ApiEndpoints.callMissed(callId));

  /// `GET /calls/{id}` — current state, used to re-check a call the app learned
  /// about from a push while it was closed.
  Future<CallSession> show(int callId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.call(callId));
    return _session(res);
  }

  /// `GET /threads/{thread}/calls` — call history for one conversation.
  Future<List<CallModel>> history(int threadId, {int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.threadCalls(threadId),
      query: <String, dynamic>{'per_page': perPage},
    );
    return res.dataList
        .whereType<Map<String, dynamic>>()
        .map(CallModel.fromJson)
        .toList();
  }

  /// Endpoints whose body the app does not need — only that they succeeded.
  Future<void> _act(String path) async {
    await _client.post(path);
  }

  CallSession _session(ApiEnvelope res) {
    final CallSession? session = CallSession.fromJson(res.dataMap);
    if (session == null) {
      // A success envelope with no `call` node means the contract moved; saying
      // so beats handing the call screen a half-built session.
      throw ApiException(
        res.message.isNotEmpty ? res.message : 'Calling service unavailable.',
        code: 'call_payload_missing',
      );
    }
    return session;
  }
}
