// The realtime layer is the part of this app that "sometimes worked", so the
// invariants that make it reliable are pinned here rather than left to a manual
// two-phone test.
//
// What is covered:
//   * the de-duplication gate, which is what stops one message producing three
//     tray notifications (socket + push + poller);
//   * the channel names Laravel actually publishes on;
//   * the delivery state that lets a message bubble be drawn before the server
//     has confirmed it.
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/core/services/notification_service.dart';
import 'package:hamqadam/core/services/pusher_chat_service.dart';
import 'package:hamqadam/models/chat_model.dart';

void main() {
  group('the notification de-duplication gate', () {
    test('the first claimant wins and the rest are dropped', () {
      // One message id, four arrival paths. Only the first may notify.
      final String key = 'msg:${DateTime.now().microsecondsSinceEpoch}';

      expect(NotificationService.instance.claim(key), isTrue,
          reason: 'the socket got there first');
      expect(NotificationService.instance.claim(key), isFalse,
          reason: 'the FCM push for the same message must be dropped');
      expect(NotificationService.instance.claim(key), isFalse,
          reason: 'the notifications poller must be dropped too');
    });

    test('different ids are independent', () {
      final int seed = DateTime.now().microsecondsSinceEpoch;
      expect(NotificationService.instance.claim('msg:$seed-a'), isTrue);
      expect(NotificationService.instance.claim('msg:$seed-b'), isTrue);
    });

    test('a released claim may be shown again', () {
      // A second call offer reuses the call id, so the ring has to be allowed
      // through once the first one's tray entry has been cancelled.
      final String key = 'call:${DateTime.now().microsecondsSinceEpoch}';
      expect(NotificationService.instance.claim(key), isTrue);
      expect(NotificationService.instance.claim(key), isFalse);

      NotificationService.instance.releaseClaim(key);
      expect(NotificationService.instance.claim(key), isTrue);
    });
  });

  group('the keys the three paths agree on', () {
    test('an activity key is the same from a push and from the poller', () {
      // The server's activity pushes carry `type` / `notify_by` / `info_id` and
      // no notification-row id, while the poller has the row. Keying on the
      // three fields both of them do have is what collapses them — otherwise
      // one interest notified twice, once from each path.
      final String fromPush = NotificationService.activityKey(
        type: 'interest_received',
        notifyBy: 7,
        infoId: 41,
      );
      final String fromPoller = NotificationService.activityKey(
        type: 'Interest_Received', // the row's casing differs from the push's
        notifyBy: 7,
        infoId: 41,
      );

      expect(fromPush, fromPoller);
      expect(NotificationService.instance.claim(fromPush), isTrue);
      expect(NotificationService.instance.claim(fromPoller), isFalse);
    });

    test('a different interest from the same person is its own key', () {
      expect(
        NotificationService.activityKey(type: 'interest', notifyBy: 7, infoId: 41),
        isNot(NotificationService.activityKey(
            type: 'interest', notifyBy: 7, infoId: 42)),
      );
    });

    test('the chat content key collapses the second, id-less push', () {
      // The backend sends two pushes per message: ChatApiService's, which
      // carries `message_id`, and NotificationHelper's, which does not. The
      // second is dropped on the conversation plus the text.
      final String key = NotificationService.chatContentKey(16, ' Assalam-o-Alaikum ');

      expect(
        key,
        NotificationService.chatContentKey(16, 'Assalam-o-Alaikum'),
        reason: 'surrounding whitespace must not split the key',
      );
      expect(
        key,
        isNot(NotificationService.chatContentKey(17, 'Assalam-o-Alaikum')),
        reason: 'the same text in another conversation is a different message',
      );

      expect(NotificationService.instance.claim(key), isTrue);
      expect(NotificationService.instance.claim(key), isFalse);
    });

    test('a content claim expires so repeated text can notify again', () {
      final String key =
          NotificationService.chatContentKey(16, 'ok ${DateTime.now().microsecondsSinceEpoch}');

      expect(NotificationService.instance.claim(key), isTrue);
      // A zero window is the boundary case of the short TTL a content key uses:
      // the claim is remembered, but it no longer suppresses.
      expect(
        NotificationService.instance.claim(key, ttl: Duration.zero),
        isTrue,
        reason: 'content keys must not silence a message forever',
      );
    });
  });

  group('realtime channel names', () {
    test('both channels carry the private- prefix Laravel publishes on', () {
      // `PrivateChannel('App.User.9')` reaches Pusher as `private-App.User.9`.
      // Subscribing without the prefix is subscribing to a public channel
      // nobody writes to, and Pusher only authorizes `private-`/`presence-`
      // channels — so the authorizer would never even run.
      expect(PusherChatService.userChannel(9), 'private-App.User.9');
      expect(PusherChatService.threadChannel(12), 'private-chat-thread.12');
    });
  });

  group('realtime status', () {
    test('only `connected` means events are arriving', () {
      // Everything else has to read as "go and fetch", because a socket that is
      // up with every channel refused looks exactly like a quiet server.
      expect(
        RealtimeStatus.values,
        containsAll(<RealtimeStatus>[
          RealtimeStatus.idle,
          RealtimeStatus.connecting,
          RealtimeStatus.connected,
          RealtimeStatus.disconnected,
          RealtimeStatus.unavailable,
        ]),
      );
    });
  });

  group('outgoing message delivery state', () {
    ChatMessage optimistic() => ChatMessage(
          id: 0,
          threadId: 16,
          senderId: 3,
          message: 'Assalam-o-Alaikum',
          messageType: 'text',
          createdAt: DateTime(2026, 9, 2, 10, 30),
          delivery: MessageDelivery.sending,
          localId: 'local-1',
          localAttachmentPaths: const <String>['/tmp/photo.jpg'],
        );

    test('a message read back from the API is already sent', () {
      final ChatMessage parsed = ChatMessage.fromJson(<String, dynamic>{
        'id': 40,
        'thread_id': 16,
        'sender_id': 3,
        'message': 'Hi',
        'message_type': 'text',
        'created_at': '2026-09-02T10:30:00.000000Z',
      });

      expect(parsed.delivery, MessageDelivery.sent);
      expect(parsed.isPending, isFalse);
      expect(parsed.isFailed, isFalse);
      expect(parsed.localId, isNull);
    });

    test('an optimistic bubble is pending and knows its local files', () {
      final ChatMessage m = optimistic();
      expect(m.isPending, isTrue);
      expect(m.id, 0, reason: 'no server id yet');
      expect(m.localId, 'local-1', reason: 'this is how the echo finds it');
      expect(m.localAttachmentPaths, <String>['/tmp/photo.jpg']);
    });

    test('a failed send keeps its text and its attachments for the retry', () {
      final ChatMessage failed =
          optimistic().copyWith(delivery: MessageDelivery.failed);

      expect(failed.isFailed, isTrue);
      expect(failed.message, 'Assalam-o-Alaikum');
      expect(failed.localAttachmentPaths, <String>['/tmp/photo.jpg']);
      expect(failed.localId, 'local-1');
    });

    test('copyWith can adopt the server id and thread the POST came back with', () {
      // A first message creates the thread, so the id the server returns is the
      // one the conversation has to switch to.
      final ChatMessage confirmed = optimistic().copyWith(
        id: 41,
        threadId: 99,
        delivery: MessageDelivery.sent,
      );

      expect(confirmed.id, 41);
      expect(confirmed.threadId, 99);
      expect(confirmed.delivery, MessageDelivery.sent);
      expect(confirmed.message, 'Assalam-o-Alaikum');
    });
  });
}
