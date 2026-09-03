/// Attachment metadata returned with each chat message.
class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.name,
    required this.originalName,
    required this.type,
    required this.url,
    required this.downloadUrl,
    this.previewUrl,
    this.size,
  });

  final int id;
  final String name;
  final String originalName;
  final String type; // 'image' | 'file' | 'audio' | 'video'
  final String url;
  final String downloadUrl;
  final String? previewUrl;
  final int? size;

  static const List<String> _imageExts = <String>[
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'svg',
  ];
  static const List<String> _audioExts = <String>['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'];
  static const List<String> _videoExts = <String>['mp4', 'mov', 'avi', 'mkv', 'm4v', 'webm'];

  /// Derive MIME category from a file name or URL.
  static String _detectType(String serverType, String name, String url) {
    if (serverType.isNotEmpty && serverType != 'file') return serverType;
    final String src = (name.isNotEmpty ? name : url).toLowerCase().split('?').first;
    final String ext = src.split('.').last;
    if (_imageExts.contains(ext)) return 'image';
    if (_audioExts.contains(ext)) return 'audio';
    if (_videoExts.contains(ext)) return 'video';
    return 'file';
  }

  bool get isImage {
    if (type == 'image') return true;
    // Also check url/name extension as a fallback
    final String src = (originalName.isNotEmpty ? originalName : url).toLowerCase().split('?').first;
    return _imageExts.contains(src.split('.').last);
  }

  bool get isFile => !isImage && type != 'audio' && type != 'video';
  bool get isAudio => type == 'audio';
  bool get isVideo => type == 'video';

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    final String serverType = json['type'] as String? ?? '';
    final String name = json['name'] as String? ?? '';
    final String originalName = json['original_name'] as String? ?? '';
    final String url = json['url'] as String? ?? '';
    final String resolvedType = _detectType(serverType, originalName.isNotEmpty ? originalName : name, url);

    return ChatAttachment(
      id: json['id'] as int? ?? 0,
      name: name,
      originalName: originalName,
      type: resolvedType,
      url: url,
      downloadUrl: json['download_url'] as String? ?? '',
      previewUrl: json['preview_url'] as String?,
      size: json['size'] as int?,
    );
  }
}

/// A single chat message within a thread.
/// How far one of *our own* messages has got.
///
/// A message used to appear only once the server had answered, so on a slow
/// connection the composer emptied and nothing showed up for a second or two.
/// The bubble is now drawn the moment Send is tapped and carries its state
/// until the server confirms it.
enum MessageDelivery {
  /// Drawn locally, POST still in flight.
  sending,

  /// The server has it — the normal state for everything read back from the API.
  sent,

  /// The POST failed. Kept on screen so the text is not lost and can be retried.
  failed,
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.message,
    required this.messageType,
    required this.createdAt,
    this.replyToChatId,
    this.replyToMessage,
    this.attachments = const <ChatAttachment>[],
    this.deletedForMe = false,
    this.senderName,
    this.senderPhoto,
    this.delivery = MessageDelivery.sent,
    this.localId,
    this.localAttachmentPaths = const <String>[],
  });

  final int id;
  final int threadId;
  final int senderId;
  final String message;
  final String messageType; // 'text' | 'image' | 'file' | 'audio'
  final DateTime createdAt;
  final int? replyToChatId;
  final ChatMessage? replyToMessage;
  final List<ChatAttachment> attachments;
  final bool deletedForMe;
  final String? senderName;
  final String? senderPhoto;

  /// Only meaningful for messages this device composed.
  final MessageDelivery delivery;

  /// Client-side identity for a message that has no server id yet, so the
  /// optimistic bubble can be found and replaced when the POST returns.
  final String? localId;

  /// File paths for an optimistic message whose attachments are still
  /// uploading, so the bubble can preview them before the server has URLs.
  final List<String> localAttachmentPaths;

  bool get isPending => delivery == MessageDelivery.sending;
  bool get isFailed => delivery == MessageDelivery.failed;

  bool isMine(int myUserId) => senderId == myUserId;

  /// True when the message has attachments but no text.
  bool get isAttachmentOnly => message.trim().isEmpty && attachments.isNotEmpty;

  /// Call signaling helpers
  bool get isCallInvite => message.startsWith('[CALL_INVITE:');
  bool get isCallDecline => message.startsWith('[CALL_DECLINED:');
  bool get isCallEvent => isCallInvite || isCallDecline;

  String? get callChannelName {
    if (!isCallInvite) return null;
    // Support both short key 'ch=' (new) and legacy 'channel=' (old)
    final RegExp shortReg = RegExp(r'ch=([^&\]]+)');
    final RegExp longReg = RegExp(r'channel=([^&\]]+)');
    final Match? shortMatch = shortReg.firstMatch(message);
    if (shortMatch != null) return shortMatch.group(1);
    final Match? longMatch = longReg.firstMatch(message);
    return longMatch?.group(1);
  }

  bool get isCallVideo {
    if (!isCallInvite) return false;
    // Support both 'vid=1' (new short) and 'isVideo=true' (legacy)
    return message.contains('vid=1') || message.contains('isVideo=true');
  }

  String get callDisplayName {
    if (isCallInvite) {
      return isCallVideo ? '📹 Video Call (Tap to join)' : '📞 Voice Call (Tap to join)';
    }
    if (isCallDecline) {
      return '📞 Call Declined';
    }
    return message;
  }


  ChatMessage copyWith({
    int? id,
    int? threadId,
    bool? deletedForMe,
    MessageDelivery? delivery,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      senderId: senderId,
      message: message,
      messageType: messageType,
      createdAt: createdAt,
      replyToChatId: replyToChatId,
      replyToMessage: replyToMessage,
      attachments: attachments,
      deletedForMe: deletedForMe ?? this.deletedForMe,
      senderName: senderName,
      senderPhoto: senderPhoto,
      delivery: delivery ?? this.delivery,
      localId: localId,
      localAttachmentPaths: localAttachmentPaths,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawAttachments = json['attachments'] as List<dynamic>? ?? <dynamic>[];
    final dynamic rawReply = json['reply_to_message'] ?? json['reply_to'];
    final dynamic rawSender = json['sender'] ?? json['user'];

    final int senderId = json['sender_id'] as int? ??
        (rawSender is Map ? rawSender['id'] as int? : null) ??
        0;

    final String? senderName = json['sender_name'] as String? ??
        (rawSender is Map ? rawSender['name'] as String? : null);

    final String? senderPhoto = json['sender_photo'] as String? ??
        (rawSender is Map ? (rawSender['photo'] as String? ?? rawSender['avatar'] as String?) : null);

    final int? replyId = json['reply_to_chat_id'] as int? ??
        json['reply_to_id'] as int? ??
        (rawReply is Map ? rawReply['id'] as int? : null);

    return ChatMessage(
      id: json['id'] as int? ?? 0,
      threadId: json['thread_id'] as int? ?? json['threadId'] as int? ?? 0,
      senderId: senderId,
      message: json['message'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      replyToChatId: replyId,
      replyToMessage: rawReply is Map<String, dynamic> ? ChatMessage.fromJson(rawReply) : null,
      attachments: rawAttachments
          .whereType<Map<String, dynamic>>()
          .map(ChatAttachment.fromJson)
          .toList(),
      deletedForMe: json['deleted_for_me'] as bool? ?? false,
      senderName: senderName,
      senderPhoto: senderPhoto,
    );
  }
}

/// The other participant shown in a thread preview.
class ChatParticipant {
  const ChatParticipant({
    required this.id,
    required this.name,
    this.photo,
    this.isOnline = false,
  });

  final int id;
  final String name;
  final String? photo;
  final bool isOnline;

  bool get hasPhoto => photo != null && photo!.isNotEmpty;

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'] as int? ??
          json['user_id'] as int? ??
          json['member_id'] as int? ??
          (json['user'] is Map ? json['user']['id'] as int? : null) ??
          (json['member'] is Map ? json['member']['id'] as int? : null) ??
          0,
      name: json['name'] as String? ??
          (json['user'] is Map ? json['user']['name'] as String? : null) ??
          (json['member'] is Map ? json['member']['name'] as String? : null) ??
          '',
      photo: json['photo'] as String? ??
          json['avatar'] as String? ??
          (json['user'] is Map ? json['user']['photo'] as String? : null) ??
          (json['member'] is Map ? json['member']['photo'] as String? : null),
      isOnline: json['is_online'] as bool? ?? json['online'] as bool? ?? false,
    );
  }
}

/// A conversation thread (inbox row).
class ChatThread {
  const ChatThread({
    required this.id,
    required this.participant,
    required this.unreadCount,
    required this.isBlocked,
    required this.createdAt,
    this.threadCode,
    this.blockedByMe = false,
    this.blockedByOther = false,
    this.canSendMessage = true,
    this.messageRequestStatus,
    this.lastMessage,
    this.lastMessageAt,
  });

  final int id;
  final ChatParticipant participant;
  final int unreadCount;
  final bool isBlocked;
  final DateTime createdAt;
  final dynamic threadCode;
  final bool blockedByMe;
  final bool blockedByOther;
  final bool canSendMessage;
  final String? messageRequestStatus;
  final ChatMessage? lastMessage;
  final DateTime? lastMessageAt;

  String get previewText {
    if (lastMessage == null) return 'No messages yet';
    if (lastMessage!.isAttachmentOnly) return '📎 Attachment';
    return lastMessage!.message;
  }

  ChatThread copyWith({
    int? id,
    ChatParticipant? participant,
    int? unreadCount,
    bool? isBlocked,
    dynamic threadCode,
    bool? blockedByMe,
    bool? blockedByOther,
    bool? canSendMessage,
    String? messageRequestStatus,
    ChatMessage? lastMessage,
    DateTime? lastMessageAt,
  }) {
    return ChatThread(
      id: id ?? this.id,
      participant: participant ?? this.participant,
      unreadCount: unreadCount ?? this.unreadCount,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt,
      threadCode: threadCode ?? this.threadCode,
      blockedByMe: blockedByMe ?? this.blockedByMe,
      blockedByOther: blockedByOther ?? this.blockedByOther,
      canSendMessage: canSendMessage ?? this.canSendMessage,
      messageRequestStatus: messageRequestStatus ?? this.messageRequestStatus,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final dynamic rawParticipant = json['participant'] ??
        json['other_user'] ??
        json['receiver'] ??
        json['user'] ??
        json['member'] ??
        json['target_user'];
    final dynamic rawLastMsg = json['last_message'] ?? json['latest_message'] ?? json['message'];

    final int participantId = (rawParticipant is Map<String, dynamic>)
        ? (rawParticipant['id'] as int? ?? rawParticipant['user_id'] as int? ?? 0)
        : (json['receiver_id'] as int? ?? json['other_user_id'] as int? ?? json['user_id'] as int? ?? 0);

    final String participantName = (rawParticipant is Map<String, dynamic>)
        ? (rawParticipant['name'] as String? ?? '')
        : (json['receiver_name'] as String? ?? json['user_name'] as String? ?? 'Member');

    final String? participantPhoto = (rawParticipant is Map<String, dynamic>)
        ? (rawParticipant['photo'] as String? ?? rawParticipant['avatar'] as String?)
        : (json['receiver_photo'] as String? ?? json['user_photo'] as String?);

    final bool blockedByMe = json['blocked_by_me'] as bool? ?? false;
    final bool blockedByOther = json['blocked_by_other'] as bool? ?? false;
    final bool isBlocked = json['is_blocked'] as bool? ??
        json['blocked'] as bool? ??
        (blockedByMe || blockedByOther);

    return ChatThread(
      id: json['id'] as int? ?? 0,
      participant: rawParticipant is Map<String, dynamic>
          ? ChatParticipant.fromJson(rawParticipant)
          : ChatParticipant(
              id: participantId,
              name: participantName,
              photo: participantPhoto,
            ),
      unreadCount: json['unread_count'] as int? ?? json['unread_messages_count'] as int? ?? 0,
      isBlocked: isBlocked,
      blockedByMe: blockedByMe,
      blockedByOther: blockedByOther,
      canSendMessage: json['can_send_message'] as bool? ?? true,
      threadCode: json['thread_code'],
      messageRequestStatus: json['message_request_status'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      lastMessage: rawLastMsg is Map<String, dynamic> ? ChatMessage.fromJson(rawLastMsg) : null,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : (json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null),
    );
  }
}

/// Pagination wrapper for messages.
class ChatMessagesPage {
  const ChatMessagesPage({
    required this.messages,
    required this.currentPage,
    required this.lastPage,
  });

  final List<ChatMessage> messages;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory ChatMessagesPage.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final List<dynamic> rawList =
        rawData is List ? rawData : <dynamic>[];
    final dynamic meta = json['meta'];
    return ChatMessagesPage(
      messages: rawList
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(),
      currentPage: meta is Map ? (meta['current_page'] as int? ?? 1) : 1,
      lastPage: meta is Map ? (meta['last_page'] as int? ?? 1) : 1,
    );
  }
}

/// Pusher broadcast config (read from app constants).
class ChatPusherConfig {
  const ChatPusherConfig({
    required this.key,
    required this.cluster,
    this.authEndpoint,
    this.authToken,
  });

  final String key;
  final String cluster;
  final String? authEndpoint;
  final String? authToken;
}
