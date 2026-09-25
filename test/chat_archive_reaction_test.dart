// Archive, mute and emoji reactions — the three chat features the API gained
// alongside `GET /chat/threads?archived=1`, `POST /chat/threads/{t}/archive`,
// `POST /chat/threads/{t}/mute` and `POST /chat/messages/{m}/reaction`.
//
// Every value is parsed from the API's own JSON shape (never hand-built
// objects), so a change to those field names fails here rather than silently
// rendering an un-archived, un-muted, reaction-less inbox.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/features/chat/views/chat_inbox_view.dart';
import 'package:hamqadam/features/chat/widgets/chat_reaction_bar.dart';
import 'package:hamqadam/models/chat_model.dart';

Map<String, dynamic> _threadJson({
  bool archived = false,
  bool muted = false,
}) {
  return <String, dynamic>{
    'id': 15,
    'thread_code': '222026081419',
    'other_user': <String, dynamic>{'id': 19, 'name': 'Ayesha Khan'},
    'unread_count': 0,
    'blocked_by_me': false,
    'blocked_by_other': false,
    'can_send_message': true,
    'archived': archived,
    'muted': muted,
    'created_at': '2026-09-20T10:00:00.000000Z',
    'last_message_at': DateTime.now().toUtc().toIso8601String(),
    'disappear_after': 0,
  };
}

Map<String, dynamic> _messageJson({
  List<dynamic> reactions = const <dynamic>[],
}) {
  return <String, dynamic>{
    'id': 16,
    'thread_id': 15,
    'sender_id': 22,
    'message': 'Sure, thank you!',
    'message_type': 'text',
    'created_at': '2026-09-20T10:00:00.000000Z',
    'reactions': reactions,
  };
}

Map<String, dynamic> _reactionJson(String emoji, int count, bool mine) {
  return <String, dynamic>{
    'emoji': emoji,
    'count': count,
    'mine': mine,
    'users': <dynamic>[
      <String, dynamic>{'id': 22, 'name': 'Jahanzaib Ali'},
      if (count > 1) <String, dynamic>{'id': 19, 'name': 'Ayesha Khan'},
    ],
  };
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ChatThread archive & mute', () {
    test('reads the per-side flags the API sends', () {
      final ChatThread plain = ChatThread.fromJson(_threadJson());
      expect(plain.isArchived, isFalse);
      expect(plain.isMuted, isFalse);

      final ChatThread archivedAndMuted = ChatThread.fromJson(
        _threadJson(archived: true, muted: true),
      );
      expect(archivedAndMuted.isArchived, isTrue);
      expect(archivedAndMuted.isMuted, isTrue);
    });

    test('an older payload without the flags reads as neither', () {
      final Map<String, dynamic> legacy = _threadJson()
        ..remove('archived')
        ..remove('muted');
      final ChatThread thread = ChatThread.fromJson(legacy);
      expect(thread.isArchived, isFalse);
      expect(thread.isMuted, isFalse);
    });

    test('copyWith flips one flag without losing the other', () {
      final ChatThread thread = ChatThread.fromJson(
        _threadJson(archived: true, muted: false),
      );
      final ChatThread muted = thread.copyWith(isMuted: true);
      expect(muted.isMuted, isTrue);
      expect(muted.isArchived, isTrue);
      expect(muted.participant.name, 'Ayesha Khan');
    });
  });

  group('ChatMessage reactions', () {
    test('parses the grouped buckets, ids and mine flag', () {
      final ChatMessage message = ChatMessage.fromJson(
        _messageJson(
          reactions: <dynamic>[
            _reactionJson('❤️', 2, true),
            _reactionJson('😂', 1, false),
          ],
        ),
      );

      expect(message.reactions.length, 2);
      expect(message.reactions.first.emoji, '❤️');
      expect(message.reactions.first.count, 2);
      expect(message.reactions.first.mine, isTrue);
      expect(message.reactions.first.userIds, <int>[22, 19]);
      expect(message.reactions.first.users, <String>[
        'Jahanzaib Ali',
        'Ayesha Khan',
      ]);
      expect(message.reactions.last.mine, isFalse);
    });

    test('a message with no reactions parses to an empty list', () {
      final ChatMessage message = ChatMessage.fromJson(_messageJson());
      expect(message.reactions, isEmpty);
    });

    test('copyWith can swap the reaction list', () {
      final ChatMessage message = ChatMessage.fromJson(_messageJson());
      final ChatMessage reacted = message.copyWith(
        reactions: <ChatReaction>[
          const ChatReaction(emoji: '👍', count: 1, mine: true),
        ],
      );
      expect(reacted.reactions.single.emoji, '👍');
      // The rest of the message is untouched.
      expect(reacted.message, 'Sure, thank you!');
      expect(message.reactions, isEmpty);
    });
  });

  group('ChatThreadCard mute marker', () {
    testWidgets('a muted chat shows the silenced glyph', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        ChatThreadCard(
          thread: ChatThread.fromJson(_threadJson(muted: true)),
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
    });

    testWidgets('an unmuted chat shows none', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        ChatThreadCard(
          thread: ChatThread.fromJson(_threadJson()),
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.notifications_off_rounded), findsNothing);
    });

    testWidgets('long-press reaches the archive/mute entry point', (
      WidgetTester tester,
    ) async {
      int longPresses = 0;
      await tester.pumpWidget(_wrap(
        ChatThreadCard(
          thread: ChatThread.fromJson(_threadJson()),
          onTap: () {},
          onLongPress: () => longPresses++,
        ),
      ));

      await tester.longPress(find.byType(ChatThreadCard));
      expect(longPresses, 1);
    });
  });

  group('ChatReactionPicker', () {
    testWidgets('offers every emoji and reports the tap', (
      WidgetTester tester,
    ) async {
      String? picked;
      await tester.pumpWidget(_wrap(
        ChatReactionPicker(onPick: (String emoji) => picked = emoji),
      ));

      for (final String emoji in kChatReactionEmojis) {
        expect(find.text(emoji), findsOneWidget);
      }

      await tester.tap(find.text('😂'));
      expect(picked, '😂');
    });

    testWidgets('a picked emoji offers remove', (WidgetTester tester) async {
      bool cleared = false;
      await tester.pumpWidget(_wrap(
        ChatReactionPicker(
          mine: '❤️',
          onPick: (_) {},
          onClear: () => cleared = true,
        ),
      ));

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(cleared, isTrue);
    });

    testWidgets('no remove control when I have not reacted', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        ChatReactionPicker(onPick: (_) {}),
      ));
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });

  group('MessageReactionRow', () {
    testWidgets('draws a pill per emoji and only counts above one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        MessageReactionRow(
          reactions: const <ChatReaction>[
            ChatReaction(emoji: '❤️', count: 2, mine: true),
            ChatReaction(emoji: '👍', count: 1),
          ],
          onTap: (_) {},
        ),
      ));

      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
      // A single reaction needs no "1" next to it.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('tapping a pill hands the reaction back', (
      WidgetTester tester,
    ) async {
      ChatReaction? tapped;
      await tester.pumpWidget(_wrap(
        MessageReactionRow(
          reactions: const <ChatReaction>[
            ChatReaction(emoji: '🙏', count: 1, mine: true),
          ],
          onTap: (ChatReaction reaction) => tapped = reaction,
        ),
      ));

      await tester.tap(find.text('🙏'));
      expect(tapped?.emoji, '🙏');
      expect(tapped?.mine, isTrue);
    });

    testWidgets('renders nothing at all without reactions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        MessageReactionRow(
          reactions: const <ChatReaction>[],
          onTap: (_) {},
        ),
      ));

      expect(find.byType(Wrap), findsNothing);
    });
  });
}
