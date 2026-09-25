import 'chat_model.dart';

/// One message inside the Help Center conversation.
///
/// Deliberately reuses [ChatAttachment] from the member chat model — the
/// backend publishes the same attachment shape on both, so one parser serves
/// both chats.
class HelpChatMessage {
  const HelpChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.fromAdmin,
    required this.message,
    required this.messageType,
    required this.createdAt,
    this.senderName,
    this.senderPhoto,
    this.attachments = const <ChatAttachment>[],
    this.delivery = MessageDelivery.sent,
    this.localId,
    this.localAttachmentPaths = const <String>[],
  });

  final int id;
  final int threadId;

  /// The member's own id, or the admin's when support replied.
  final int senderId;

  /// True when the message came from the Help Center (admin panel side).
  final bool fromAdmin;
  final String message;
  final String messageType;
  final DateTime createdAt;
  final String? senderName;
  final String? senderPhoto;
  final List<ChatAttachment> attachments;

  /// Only meaningful for messages this device composed.
  final MessageDelivery delivery;

  /// Client-side identity for a message that has no server id yet.
  final String? localId;
  final List<String> localAttachmentPaths;

  bool get isPending => delivery == MessageDelivery.sending;
  bool get isFailed => delivery == MessageDelivery.failed;
  bool get isAttachmentOnly => message.trim().isEmpty && attachments.isNotEmpty;

  HelpChatMessage copyWith({
    int? id,
    MessageDelivery? delivery,
  }) {
    return HelpChatMessage(
      id: id ?? this.id,
      threadId: threadId,
      senderId: senderId,
      fromAdmin: fromAdmin,
      message: message,
      messageType: messageType,
      createdAt: createdAt,
      senderName: senderName,
      senderPhoto: senderPhoto,
      attachments: attachments,
      delivery: delivery ?? this.delivery,
      localId: localId,
      localAttachmentPaths: localAttachmentPaths,
    );
  }

  factory HelpChatMessage.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawAttachments =
        json['attachments'] as List<dynamic>? ?? <dynamic>[];
    final dynamic rawSender = json['sender'] ?? json['user'];

    final int senderId = json['sender_id'] as int? ??
        (rawSender is Map ? rawSender['id'] as int? : null) ??
        0;

    return HelpChatMessage(
      id: json['id'] as int? ?? 0,
      threadId: json['thread_id'] as int? ?? json['threadId'] as int? ?? 0,
      senderId: senderId,
      fromAdmin: json['from_admin'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      senderName: json['sender_name'] as String? ??
          (rawSender is Map ? rawSender['name'] as String? : null),
      senderPhoto: json['sender_photo'] as String? ??
          (rawSender is Map ? rawSender['photo'] as String? : null),
      attachments: rawAttachments
          .whereType<Map<String, dynamic>>()
          .map(ChatAttachment.fromJson)
          .toList(),
    );
  }
}

/// The member's Help Center conversation.
class HelpChatThread {
  const HelpChatThread({
    required this.id,
    required this.isClosed,
    required this.unreadCount,
    this.lastMessageAt,
  });

  final int id;
  final bool isClosed;
  final int unreadCount;
  final DateTime? lastMessageAt;

  factory HelpChatThread.fromJson(Map<String, dynamic> json) {
    return HelpChatThread(
      id: json['id'] as int? ?? 0,
      isClosed: json['is_closed'] as bool? ?? false,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
    );
  }
}

/// Pagination wrapper for help chat messages.
class HelpChatMessagesPage {
  const HelpChatMessagesPage({
    required this.messages,
    required this.currentPage,
    required this.lastPage,
  });

  final List<HelpChatMessage> messages;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory HelpChatMessagesPage.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final List<dynamic> rawList = rawData is List ? rawData : <dynamic>[];
    final dynamic meta = json['meta'];
    return HelpChatMessagesPage(
      messages: rawList
          .whereType<Map<String, dynamic>>()
          .map(HelpChatMessage.fromJson)
          .toList(),
      currentPage: meta is Map ? (meta['current_page'] as int? ?? 1) : 1,
      lastPage: meta is Map ? (meta['last_page'] as int? ?? 1) : 1,
    );
  }
}
