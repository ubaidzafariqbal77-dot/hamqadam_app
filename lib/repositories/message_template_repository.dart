import '../constants/api_endpoints.dart';
import '../constants/message_template_seed.dart';
import '../core/api/api_client.dart';
import '../core/utils/app_logger.dart';
import '../models/message_template_model.dart';

/// Send Interest / Send Proposal message library and the AI Proposal Generator.
///
/// Templates are admin-managed content (spec §6): the server list wins, and the
/// bundled seed is only a fallback when it cannot be reached. Either way,
/// inactive and empty templates are never returned.
class MessageTemplateRepository {
  MessageTemplateRepository(this._client);

  final ApiClient _client;

  final Map<String, List<MessageTemplate>> _cache = <String, List<MessageTemplate>>{};

  /// `GET /message-templates?type=&language=`
  Future<List<MessageTemplate>> fetch(String type, {String language = 'en'}) async {
    final String key = '$type:$language';
    final List<MessageTemplate>? cached = _cache[key];
    if (cached != null) return cached;

    List<MessageTemplate> list = <MessageTemplate>[];
    try {
      final ApiEnvelope res = await _client.get(
        ApiEndpoints.connectionTemplates,
        query: <String, dynamic>{'kind': type, 'language': language},
      );
      final List<dynamic> raw = res.dataList.isNotEmpty
          ? res.dataList
          : (res.dataMap['templates'] as List<dynamic>? ?? <dynamic>[]);
      list = raw
          .whereType<Map<String, dynamic>>()
          .map(MessageTemplate.fromJson)
          .where((MessageTemplate t) => t.isUsable && (t.type.isEmpty || t.type == type))
          .toList()
        ..sort((MessageTemplate a, MessageTemplate b) => a.displayOrder.compareTo(b.displayOrder));
    } catch (e) {
      AppLogger.w('Message templates unavailable, using seed: $e');
    }

    if (list.isEmpty) return MessageTemplateSeed.forType(type);
    _cache[key] = list;
    return list;
  }

  /// `POST /connection-workflow/members/{id}/proposal/generate` — returns draft
  /// text only. The member previews, edits and explicitly confirms before
  /// anything is sent.
  Future<String> generateProposal({
    required int receiverId,
    required String language,
    required bool includeFamilyIntro,
    String? intentions,
    int generation = 1,
  }) async {
    // The server needs at least 10 characters of the sender's own words.
    String intention = (intentions ?? '').trim();
    if (intention.length < 10) {
      intention = includeFamilyIntro
          ? 'I would like to propose marriage and introduce our families respectfully.'
          : 'I would like to propose marriage with sincere and respectful intentions.';
    }
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.connectionAiDraft(receiverId),
      body: <String, dynamic>{
        'language': language == 'ur' ? 'ur' : 'en',
        'intention': intention,
      },
    );
    final Map<String, dynamic> data = res.dataMap;
    return (data['draft'] ?? data['text'] ?? data['proposal'] ?? '').toString().trim();
  }
}
