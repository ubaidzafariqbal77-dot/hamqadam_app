// The "Chat Conversations" reference screen: the inbox cards, the dotted
// separator between them and the Chats/Calls pills. These are pure rendering
// checks — every value on a card comes from a [ChatThread], so the tests build
// threads out of the API's own JSON shape rather than hand-made objects.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/features/chat/views/chat_inbox_view.dart';
import 'package:hamqadam/models/chat_model.dart';

ChatThread _thread({
  int id = 16,
  String name = 'Ayesha Khan',
  int unread = 0,
  Map<String, dynamic>? lastMessage,
}) {
  return ChatThread.fromJson(<String, dynamic>{
    'id': id,
    'participant': <String, dynamic>{
      'id': 4,
      'name': name,
      'photo': null,
      'is_online': false,
    },
    'unread_count': unread,
    'is_blocked': false,
    'created_at': '2026-09-20T10:00:00.000000Z',
    // The inbox timestamp reads this, and only falls back to the thread's own
    // creation date when the API does not send it.
    'last_message_at': DateTime.now().toUtc().toIso8601String(),
    'last_message': lastMessage ??
        <String, dynamic>{
          'id': 40,
          'thread_id': id,
          'sender_id': 4,
          'message': 'Sent the voice note about meeting',
          'message_type': 'text',
          'created_at':
              '${DateTime.now().toIso8601String().split('.').first}Z',
        },
  });
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ChatThreadCard', () {
    testWidgets('draws the name, preview and timestamp from the thread',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        ChatThreadCard(thread: _thread(), onTap: () {}),
      ));

      expect(find.text('Ayesha Khan'), findsOneWidget);
      expect(find.text('Sent the voice note about meeting'), findsOneWidget);
      // Today's message reads as a clock time, not a date.
      expect(find.textContaining(RegExp(r'(AM|PM)')), findsOneWidget);
      // No unread count, no badge.
      expect(find.text('2'), findsNothing);
    });

    testWidgets('shows the unread count badge on an unread conversation',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        ChatThreadCard(thread: _thread(unread: 2), onTap: () {}),
      ));

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('marks a voice note with the waveform', (WidgetTester tester) async {
      final ChatThread voice = _thread(
        lastMessage: <String, dynamic>{
          'id': 41,
          'thread_id': 16,
          'sender_id': 4,
          'message': '',
          'message_type': 'voice',
          'created_at': '2026-09-23T10:00:00.000000Z',
          'metadata': <String, dynamic>{'duration': 12},
          'attachments': <dynamic>[
            <String, dynamic>{
              'id': 900,
              'url': 'https://example.com/uploads/all/note.m4a',
              'type': 'audio',
              'extension': 'm4a',
            },
          ],
        },
      );

      await tester.pumpWidget(_wrap(
        ChatThreadCard(thread: voice, onTap: () {}),
      ));

      expect(find.byType(ChatMiniWaveform), findsOneWidget);
    });

    testWidgets('a text conversation has no waveform', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        ChatThreadCard(thread: _thread(), onTap: () {}),
      ));

      expect(find.byType(ChatMiniWaveform), findsNothing);
    });

    testWidgets('reports taps so the conversation can be opened',
        (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(
        ChatThreadCard(thread: _thread(), onTap: () => taps++),
      ));

      await tester.tap(find.byType(ChatThreadCard));
      await tester.pump();

      expect(taps, 1);
    });

    test('formats timestamps the way the reference does', () {
      expect(ChatThreadCard.formatTimestamp(null), '');
      expect(
        ChatThreadCard.formatTimestamp(DateTime.now()),
        matches(RegExp(r'\d{1,2}:\d{2} (AM|PM)')),
      );
      expect(
        ChatThreadCard.formatTimestamp(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        'Yesterday',
      );
      expect(
        ChatThreadCard.formatTimestamp(
          DateTime.now().subtract(const Duration(days: 30)),
        ),
        matches(RegExp(r'[A-Z][a-z]{2} \d{1,2}')),
      );
    });
  });

  group('Inbox chrome', () {
    testWidgets('the header carries the reference title', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const InboxHeader()));

      expect(find.text('Chat Conversations'), findsOneWidget);
      // The drawer control has to live here when the shell hides its app bar.
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });

    testWidgets('the Chats/Calls pills switch the selected tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Column(
              children: <Widget>[
                const InboxTabs(),
                const Expanded(
                  child: TabBarView(
                    children: <Widget>[Text('chats-body'), Text('calls-body')],
                  ),
                ),
              ],
            ),
          ),
        ),
      ));

      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Calls'), findsOneWidget);
      expect(find.text('chats-body'), findsOneWidget);

      await tester.tap(find.text('Calls'));
      await tester.pumpAndSettle();

      expect(find.text('calls-body'), findsOneWidget);
    });
  });

  testWidgets('the dotted separator paints without overflowing',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      const SizedBox(width: 240, child: ChatDottedDivider()),
    ));

    expect(find.byType(ChatDottedDivider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
