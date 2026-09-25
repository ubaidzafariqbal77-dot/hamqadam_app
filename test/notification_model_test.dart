import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/notification_model.dart';
import 'package:hamqadam/repositories/notification_repository.dart';

void main() {
  group('NotificationModel Tests', () {
    test('parses a chat_message row from GET /notifications', () {
      final NotificationModel notif = NotificationModel.fromJson(<String, dynamic>{
        'id': 223,
        'type': 'chat_message',
        'title': 'Ubaid DEV',
        'message': 'Beautiful',
        'deep_link': '/chat/30',
        'notify_by': 143,
        'info_id': 30,
        'payload': <String, dynamic>{'route': '/chat/30'},
        'read_at': null,
        'created_at': '2026-09-24T10:00:00.000000Z',
      });

      expect(notif.id, 223);
      expect(notif.type, 'chat_message');
      expect(notif.title, 'Ubaid DEV');
      expect(notif.message, 'Beautiful');
      expect(notif.deepLink, '/chat/30');
      expect(notif.notifyBy, 143);
      expect(notif.infoId, 30);
      expect(notif.isRead, false);
      expect(notif.isChatMessage, true);
      expect(notif.createdAt, isNotNull);
    });

    test('parses an activity row and read state correctly', () {
      final NotificationModel notif = NotificationModel.fromJson(<String, dynamic>{
        'id': 9,
        'type': 'interest',
        'title': 'New Interest',
        'message': 'Ali sent you an interest.',
        'read_at': '2026-09-20T08:30:00.000000Z',
        'created_at': '2026-09-20T08:00:00.000000Z',
      });

      expect(notif.isRead, true);
      expect(notif.isChatMessage, false);
      expect(notif.readAt, isNotNull);
    });

    test('copyWith keeps every field and can mark read', () {
      final NotificationModel original = NotificationModel(
        id: 7,
        type: 'coin_received',
        title: 'Coins Received',
        message: 'You received 10 coins.',
        deepLink: '/coins',
        notifyBy: 5,
        infoId: 2,
        payload: <String, dynamic>{'route': '/coins'},
        createdAt: DateTime(2026, 9, 1),
      );

      final NotificationModel read = original.copyWith(readAt: DateTime(2026, 9, 25));

      expect(read.id, 7);
      expect(read.type, 'coin_received');
      expect(read.title, 'Coins Received');
      expect(read.message, 'You received 10 coins.');
      expect(read.deepLink, '/coins');
      expect(read.notifyBy, 5);
      expect(read.infoId, 2);
      expect(read.payload, original.payload);
      expect(read.createdAt, original.createdAt);
      expect(read.isRead, true);
      expect(original.isRead, false);
    });

    test('parses the notification page envelope with unread_count', () {
      final NotificationPage page = NotificationPage.fromJson(<String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{'id': 1, 'type': 'interest', 'title': 'New Interest', 'message': 'hi'},
          <String, dynamic>{'id': 2, 'type': 'chat_message', 'title': 'Ubaid DEV', 'message': 'Beautiful'},
        ],
        'meta': <String, dynamic>{
          'unread_count': 5,
          'current_page': 1,
          'last_page': 2,
        },
      });

      expect(page.notifications.length, 2);
      expect(page.unreadCount, 5);
      expect(page.currentPage, 1);
      expect(page.lastPage, 2);
      expect(page.notifications[1].isChatMessage, true);
    });

    test('markAsRead parses the V1 response shape (row + unread_count)', () {
      // Mirrors NotificationRepository.markAsRead's parsing of
      // {success, message, data: {row..., unread_count}} from the backend.
      final Map<String, dynamic> raw = <String, dynamic>{
        'success': true,
        'message': 'Notification marked as read.',
        'data': <String, dynamic>{
          'id': 223,
          'type': 'chat_message',
          'title': 'Ubaid DEV',
          'message': 'Beautiful',
          'read_at': '2026-09-25T03:50:00.000000Z',
          'unread_count': 4,
        },
      };

      final Map<String, dynamic> data = raw['data'] as Map<String, dynamic>;
      final NotificationModel row = NotificationModel.fromJson(data);
      final int unreadCount = data['unread_count'] as int? ?? 0;

      expect(row.isRead, true);
      expect(unreadCount, 4);
      expect(MarkReadResult(notification: row, unreadCount: unreadCount).unreadCount, 4);
    });
  });
}
