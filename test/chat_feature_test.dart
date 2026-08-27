import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/chat_model.dart';

void main() {
  group('ChatModel Tests', () {
    test('parses ChatAttachment from JSON correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 812,
        'name': 'contract.pdf',
        'original_name': 'contract.pdf',
        'type': 'file',
        'url': 'https://example.com/uploads/contract.pdf',
        'download_url': 'https://example.com/aiz-uploader/download/812',
        'preview_url': null,
        'size': 245671,
      };

      final ChatAttachment attachment = ChatAttachment.fromJson(json);

      expect(attachment.id, 812);
      expect(attachment.name, 'contract.pdf');
      expect(attachment.originalName, 'contract.pdf');
      expect(attachment.type, 'file');
      expect(attachment.isFile, true);
      expect(attachment.isImage, false);
      expect(attachment.size, 245671);
    });

    test('parses ChatMessage from JSON with attachments and reply', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 40,
        'thread_id': 16,
        'sender_id': 3,
        'message': 'Hi, how are you?',
        'message_type': 'text',
        'created_at': '2026-08-26T12:00:00.000000Z',
        'reply_to_chat_id': 39,
        'reply_to_message': <String, dynamic>{
          'id': 39,
          'thread_id': 16,
          'sender_id': 4,
          'message': 'Assalamualaikum',
          'message_type': 'text',
          'created_at': '2026-08-26T11:59:00.000000Z',
        },
        'attachments': <dynamic>[
          <String, dynamic>{
            'id': 812,
            'name': 'photo.jpg',
            'original_name': 'photo.jpg',
            'type': 'image',
            'url': 'https://example.com/photo.jpg',
            'download_url': 'https://example.com/download/812',
          }
        ],
      };

      final ChatMessage message = ChatMessage.fromJson(json);

      expect(message.id, 40);
      expect(message.threadId, 16);
      expect(message.senderId, 3);
      expect(message.message, 'Hi, how are you?');
      expect(message.replyToChatId, 39);
      expect(message.replyToMessage, isNotNull);
      expect(message.replyToMessage!.message, 'Assalamualaikum');
      expect(message.attachments.length, 1);
      expect(message.attachments.first.isImage, true);
      expect(message.isMine(3), true);
      expect(message.isMine(4), false);
    });

    test('parses ChatMessage response with nested sender object correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 13,
        'thread_id': 17,
        'sender': <String, dynamic>{
          'id': 10,
          'code': '2026078',
          'name': 'Ayesha Khan',
          'photo': null,
        },
        'message': 'Assalamualaikum, how are you Younis?',
        'message_type': 'text',
        'attachments': <dynamic>[],
        'reply_to': null,
        'delivered_at': '2026-08-27T06:05:50.000000Z',
        'read_at': null,
        'seen': false,
        'moderation_status': 'clean',
        'toxicity_score': 0,
        'created_at': '2026-08-27T06:05:50.000000Z',
      };

      final ChatMessage message = ChatMessage.fromJson(json);

      expect(message.id, 13);
      expect(message.threadId, 17);
      expect(message.senderId, 10);
      expect(message.senderName, 'Ayesha Khan');
      expect(message.message, 'Assalamualaikum, how are you Younis?');
      expect(message.isMine(10), true);
    });

    test('parses ChatThread from JSON correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 16,
        'participant': <String, dynamic>{
          'id': 4,
          'name': 'Ayesha Khan',
          'photo': 'https://example.com/ayesha.jpg',
          'is_online': true,
        },
        'unread_count': 2,
        'is_blocked': false,
        'created_at': '2026-08-26T10:00:00.000000Z',
        'last_message': <String, dynamic>{
          'id': 40,
          'thread_id': 16,
          'sender_id': 4,
          'message': 'Looking forward to speaking.',
          'message_type': 'text',
          'created_at': '2026-08-26T12:00:00.000000Z',
        },
      };

      final ChatThread thread = ChatThread.fromJson(json);

      expect(thread.id, 16);
      expect(thread.participant.id, 4);
      expect(thread.participant.name, 'Ayesha Khan');
      expect(thread.participant.isOnline, true);
      expect(thread.unreadCount, 2);
      expect(thread.isBlocked, false);
      expect(thread.previewText, 'Looking forward to speaking.');
    });
  });
}
