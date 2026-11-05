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

    test('parses the backend resource shape where type lives in data', () {
      const String notificationTypeOnDisk = 'App\\Notifications\\InterestNotification';
      final NotificationModel notif = NotificationModel.fromJson(<String, dynamic>{
        'id': 101,
        'type': notificationTypeOnDisk,
        'data': <String, dynamic>{
          'type': 'interest',
          'event_key': 'interest_received',
          'title': 'Someone Is Interested',
          'message': ':name has expressed interest in you.',
          'notify_by': 42,
          'info_id': 7,
          'route': '/interests',
          'deep_link': '/interests',
          'payload': <String, dynamic>{
            'event_key': 'interest_received',
            'name': 'Sana',
          },
          'category': 'discovery',
        },
        'category': 'discovery',
        'read_at': null,
        'created_at': '2026-10-05T12:00:00.000000Z',
      });

      expect(notif.type, notificationTypeOnDisk);
      expect(notif.typeFallback, 'interest');
      expect(notif.payload?['event_key'], 'interest_received');
      expect(notif.payload?['name'], 'Sana');
      expect(notif.payload?['route'], '/interests');
      expect(notif.payload?['deep_link'], '/interests');
      expect(notif.route, '/interests');
      expect(notif.category, 'discovery');
      expect(notif.title, 'Someone Is Interested');
      expect(notif.message, ':name has expressed interest in you.');
      expect(notif.notifyBy, 42);
      expect(notif.infoId, 7);
    });

    test('the fallback label route works for the legacy flat row the app already renders', () {
      final NotificationModel notif = NotificationModel.fromJson(<String, dynamic>{
        'id': 7,
        'type': 'interest',
        'title': 'New Interest',
        'message': 'Ali sent you an interest.',
        'deep_link': '/interests',
        'notify_by': 143,
        'info_id': 30,
      });

      expect(notif.typeFallback, 'interest');
      expect(notif.title, 'New Interest');
      expect(notif.route, '/interests');
    });

    test('route falls back through nested data then outer row', () {
      final NotificationModel notif = NotificationModel.fromJson(<String, dynamic>{
        'id': 102,
        'data': <String, dynamic>{'route': '/proposals'},
      });

      expect(notif.route, '/proposals');
    });

    test('route falls back to / when there is no route anywhere', () {
      final NotificationModel notif = NotificationModel.fromJson(<String, dynamic>{
        'id': 103,
      });

      expect(notif.route, '/');
    });

    test('copyWith keeps every field and can mark read', () {
      final NotificationModel original = NotificationModel(
        id: 7,
        type: 'coin_received',
        typeFallback: 'coin_received',
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
      expect(read.typeFallback, 'coin_received');
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

    test('markAsRead also parses the nested notification shape the backend returns', () {
      final Map<String, dynamic> raw = <String, dynamic>{
        'success': true,
        'message': 'Notification marked as read.',
        'data': <String, dynamic>{
          'notification': <String, dynamic>{
            'id': 224,
            'type': 'proposal',
            'title': 'New Proposal',
            'message': 'Sana sent you a proposal.',
            'read_at': '2026-10-05T09:00:00.000000Z',
          },
          'unread_count': 3,
        },
      };

      final Map<String, dynamic> data = raw['data'] as Map<String, dynamic>;
      final NotificationModel row = NotificationModel.fromJson(
        data['notification'] as Map<String, dynamic>,
      );
      final int unreadCount = data['unread_count'] as int? ?? 0;

      expect(row.id, 224);
      expect(row.isRead, true);
      expect(unreadCount, 3);
    });

    test('markAsRead parsing tolerates plain integers and string unread_count', () {
      final Map<String, dynamic> raw = <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 225,
          'type': 'interest',
          'read_at': '2026-10-05T09:05:00.000000Z',
          'unread_count': '2',
        },
        'meta': <String, dynamic>{'unread_count': 2},
      };

      final Map<String, dynamic> data = raw['data'] as Map<String, dynamic>;
      final NotificationModel row = NotificationModel.fromJson(data);
      final int unreadCount = data['unread_count'] is int
          ? data['unread_count'] as int
          : int.tryParse(data['unread_count']?.toString() ?? '0') ?? 0;

      expect(row.isRead, true);
      expect(unreadCount, 2);
    });
  });
}
