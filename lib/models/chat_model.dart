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

  /// Derive the media category for an attachment.
  ///
  /// The file's own extension wins over [serverType]. Every upload made before
  /// the API started classifying them is stored as `image` whatever it really
  /// is, so a voice note read back from history claims to be an image — which
  /// put it in the picture grid as a broken thumbnail instead of in a player.
  /// Trusting the extension repairs those rows on the client, with no
  /// migration and no second round trip.
  ///
  /// [serverType] still decides when the extension says nothing: a file with
  /// no extension, or one these lists do not know.
  static String _detectType(String serverType, String extension, String name, String url) {
    final String ext = _extensionOf(extension, name, url);

    if (_imageExts.contains(ext)) return 'image';
    if (_audioExts.contains(ext)) return 'audio';
    if (_videoExts.contains(ext)) return 'video';

    if (serverType.isNotEmpty && serverType != 'file') return serverType;
    return 'file';
  }

  /// Lower-case extension, preferring the API's own `extension` field and
  /// falling back to the URL. `original_name` comes back with the extension
  /// already stripped, so it is the least useful of the three.
  static String _extensionOf(String extension, String name, String url) {
    final String declared = extension.trim().toLowerCase().replaceAll('.', '');
    if (declared.isNotEmpty) return declared;

    for (final String candidate in <String>[url, name]) {
      final String src = candidate.toLowerCase().split('?').first.split('#').first;
      if (!src.contains('.')) continue;
      final String ext = src.split('.').last;
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }

    return '';
  }

  bool get isImage => type == 'image';

  bool get isFile => !isImage && type != 'audio' && type != 'video';
  bool get isAudio => type == 'audio';
  bool get isVideo => type == 'video';

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    final String serverType = json['type'] as String? ?? '';
    final String name = json['name'] as String? ?? '';
    final String originalName = json['original_name'] as String? ?? '';
    final String url = json['url'] as String? ?? '';
    final String extension = json['extension'] as String? ?? '';
    final String resolvedType = _detectType(
      serverType,
      extension,
      originalName.isNotEmpty ? originalName : name,
      url,
    );

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

/// One emoji reaction on a message, already grouped by the API.
///
/// The server collapses every reaction row into per-emoji buckets, so the
/// bubble only has to render `emoji × count` plus whether *I* am one of them
/// ([mine]) to decide the highlighted style.
class ChatReaction {
  const ChatReaction({
    required this.emoji,
    required this.count,
    this.mine = false,
    this.users = const <String>[],
    this.userIds = const <int>[],
  });

  final String emoji;
  final int count;

  /// True when the signed-in member is one of the people who reacted — tapping
  /// the same emoji again clears it server-side.
  final bool mine;

  /// Display names of the reactors, for the "who reacted" tooltip. Parallel to
  /// [userIds] (same index = same person).
  final List<String> users;

  /// Ids of the reactors. A realtime reaction names the person who reacted but
  /// not the emoji they dropped, so the local patch needs the ids to take that
  /// member out of whatever bucket they were in before.
  final List<int> userIds;

  factory ChatReaction.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawUsers = json['users'] as List<dynamic>? ?? <dynamic>[];
    final List<Map<String, dynamic>> people =
        rawUsers.whereType<Map<String, dynamic>>().toList();
    return ChatReaction(
      emoji: json['emoji'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      mine: json['mine'] as bool? ?? false,
      users: people
          .map((Map<String, dynamic> u) => u['name'] as String? ?? '')
          .where((String name) => name.isNotEmpty)
          .toList(),
      userIds: people
          .map((Map<String, dynamic> u) => u['id'] as int? ?? 0)
          .where((int id) => id > 0)
          .toList(),
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

  /// The server has it, the POST failed. Kept on screen so the text is not lost and can be retried.
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
    this.deliveredAt,
    this.readAt,
    this.seen = false,
    this.metadata,
    this.expiresAt,
    this.reactions = const <ChatReaction>[],
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

  /// When the recipient's app acknowledged having this message on device —
  /// the sender's single tick becomes a double tick at this moment.
  final DateTime? deliveredAt;

  /// When the recipient opened the conversation — the blue double tick.
  final DateTime? readAt;

  /// Server's read flag (kept alongside [readAt]; older rows set it without
  /// the timestamp).
  final bool seen;

  /// Free-form server extras. For a voice note: `{duration: seconds,
  /// waveform: [int, …]}` — everything the player bubble needs to draw.
  final Map<String, dynamic>? metadata;

  /// When this disappearing message will vanish from the thread (null =
  /// keep forever). The server hides+deletes rows past this moment.
  final DateTime? expiresAt;

  /// Emoji reactions on this message, grouped per emoji by the API.
  final List<ChatReaction> reactions;

  /// True once the disappearing deadline has passed on-device — the bubble
  /// renders as a tombstone until the next fetch removes it.
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Ticks for one of MY messages, resolved from the server's own flags:
  /// sending → clock, failed → alert, read → blue double, delivered → double,
  /// otherwise single.
  bool get serverRead => readAt != null || seen;
  bool get serverDelivered => deliveredAt != null || serverRead;

  /// True when this message is a voice note: typed as one by the sender, or an
  /// audio attachment arrived from the website.
  bool get isVoice =>
      messageType == 'voice' ||
      (messageType == 'audio') ||
      (attachments.isNotEmpty && attachments.every((ChatAttachment a) => a.isAudio));

  /// Length in seconds recorded with a voice note (null when unknown).
  /// Tolerant of strings: older rows and web-sent notes stored "7", not 7.
  int? get voiceDuration {
    final dynamic raw = metadata?['duration'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// Amplitude bars recorded with a voice note (0–15ish each; empty when the
  /// client that sent it did not capture one). String-tolerant for the same
  /// reason as [voiceDuration].
  List<int> get voiceWaveform =>
      ((metadata?['waveform'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0)
          .toList();

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
    DateTime? deliveredAt,
    DateTime? readAt,
    bool? seen,
    Map<String, dynamic>? metadata,
    List<ChatReaction>? reactions,
    String? localId,
    List<String>? localAttachmentPaths,
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
      localId: localId ?? this.localId,
      localAttachmentPaths: localAttachmentPaths ?? this.localAttachmentPaths,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      seen: seen ?? this.seen,
      metadata: metadata ?? this.metadata,
      expiresAt: expiresAt,
      reactions: reactions ?? this.reactions,
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
      deliveredAt: DateTime.tryParse(json['delivered_at'] as String? ?? ''),
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
      seen: json['seen'] as bool? ?? false,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      reactions: (json['reactions'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ChatReaction.fromJson)
          .toList(),
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
    this.lastActiveAt,
  });

  final int id;
  final String name;
  final String? photo;
  final bool isOnline;

  /// The member's last active moment from the server's presence stamp. Null
  /// when the server has not seen them (never active / older app version).
  final DateTime? lastActiveAt;

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
      lastActiveAt: DateTime.tryParse(json['last_active_at'] as String? ?? ''),
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
    this.disappearAfter = 0,
    this.isArchived = false,
    this.isMuted = false,
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

  /// Remembered disappearing-message TTL for this thread (seconds; 0 = off).
  /// New messages default to it; the composer's timer chip reflects it.
  final int disappearAfter;

  /// Archived into the Archived tab for *this* member only — archive is per
  /// side, so the other person keeps seeing the chat in their inbox.
  final bool isArchived;

  /// Notifications silenced for this member only; messages keep arriving.
  final bool isMuted;

  String get previewText {
    if (lastMessage == null) return 'No messages yet';
    // Voice notes first: an audio-only message has no text, so the generic
    // attachment label below read "📎 Attachment" for what is really a voice
    // note. Same for other media kinds — the preview should say WHAT it is.
    final ChatMessage last = lastMessage!;
    if (last.isVoice) {
      final int? secs = last.voiceDuration;
      return secs != null && secs > 0
          ? '🎤 Voice message (${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')})'
          : '🎤 Voice message';
    }
    if (last.isCallInvite) return last.callDisplayName;
    if (last.isCallDecline) return last.callDisplayName;
    if (last.isAttachmentOnly) {
      if (last.attachments.every((ChatAttachment a) => a.isImage)) {
        return '📷 Photo';
      }
      if (last.attachments.every((ChatAttachment a) => a.isVideo)) {
        return '🎬 Video';
      }
      return '📎 Attachment';
    }
    return last.message;
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
    int? disappearAfter,
    bool? isArchived,
    bool? isMuted,
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
      disappearAfter: disappearAfter ?? this.disappearAfter,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
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
      disappearAfter: json['disappear_after'] as int? ?? 0,
      isArchived: json['archived'] as bool? ?? false,
      isMuted: json['muted'] as bool? ?? false,
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
