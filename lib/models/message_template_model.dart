/// Which flow a [MessageTemplate] belongs to.
class MessageTemplateType {
  const MessageTemplateType._();

  static const String interest = 'interest';
  static const String proposal = 'proposal';
}

/// One admin-managed Send Interest / Send Proposal message.
///
/// Opening, body and closing are stored and edited separately in the Admin
/// Dashboard (spec §6), so the app joins them only for preview and sending.
class MessageTemplate {
  const MessageTemplate({
    required this.id,
    required this.type,
    required this.title,
    required this.opening,
    required this.body,
    required this.closing,
    this.language = 'en',
    this.isActive = true,
    this.displayOrder = 0,
  });

  final String id;
  final String type;
  final String title;
  final String opening;
  final String body;
  final String closing;
  final String language;
  final bool isActive;
  final int displayOrder;

  /// A template the admin left empty or switched off is never offered (spec §6).
  bool get isUsable =>
      isActive && (opening.trim().isNotEmpty || body.trim().isNotEmpty || closing.trim().isNotEmpty);

  /// The complete message, as previewed and sent.
  String get fullText => <String>[opening, body, closing]
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .join('\n\n');

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    final dynamic active = json['status'] ?? json['is_active'];
    return MessageTemplate(
      id: (json['id'] ?? json['template_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      opening: (json['opening'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      closing: (json['closing'] ?? '').toString(),
      language: (json['language'] ?? 'en').toString(),
      isActive: active == null ||
          active == true ||
          active == 1 ||
          active.toString() == '1' ||
          active.toString().toLowerCase() == 'active',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}
