// The Calls tab reads from a local log now, so the rules that decide what a
// row says — and which rows count as missed — are pinned here rather than left
// to a two-phone test.
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/call_log_entry.dart';
import 'package:hamqadam/models/call_model.dart';

/// A call payload shaped exactly like `CallService::payload()` builds it.
Map<String, dynamic> _call({
  int id = 41,
  int callerId = 10,
  int receiverId = 66,
  String status = 'ended',
  String type = 'audio',
  String? answeredAt,
  String? endedAt = '2026-09-02T20:41:29.000000Z',
  int duration = 0,
}) {
  return <String, dynamic>{
    'id': id,
    'conversation_id': 17,
    'thread_id': 17,
    'agora_channel': 'call.17.$id',
    'call_type': type,
    'status': status,
    'caller': <String, dynamic>{'id': callerId, 'name': 'Ayesha Khan test', 'photo': 'a.jpg'},
    'receiver': <String, dynamic>{'id': receiverId, 'name': 'Younis Gopang', 'photo': 'y.jpg'},
    'answered_at': answeredAt,
    'ended_at': endedAt,
    'duration_seconds': duration,
    'ended_by_user_id': callerId,
  };
}

void main() {
  const int me = 66; // the receiver in the fixture above
  const int them = 10;

  group('direction is worked out from who placed the call', () {
    test('a call I received is incoming', () {
      final CallLogEntry entry =
          CallLogEntry.fromCall(CallModel.fromJson(_call()), myUserId: me)!;

      expect(entry.direction, CallLogDirection.incoming);
      expect(entry.peerId, them);
      expect(entry.peerName, 'Ayesha Khan test');
    });

    test('a call I placed is outgoing', () {
      final CallLogEntry entry =
          CallLogEntry.fromCall(CallModel.fromJson(_call()), myUserId: them)!;

      expect(entry.direction, CallLogDirection.outgoing);
      expect(entry.peerId, me, reason: 'the peer is whoever I am not');
    });

    test('a call with nobody I recognise is not logged', () {
      expect(
        CallLogEntry.fromCall(CallModel.fromJson(_call()), myUserId: 999),
        isNull,
        reason: 'peerFor returns the caller, but a row with no real peer is noise',
      );
    });
  });

  group('outcome comes from the server status', () {
    CallLogOutcome outcomeFor(String status, {String? answeredAt}) =>
        CallLogEntry.outcomeOf(
          CallModel.fromJson(_call(status: status, answeredAt: answeredAt)),
        );

    test('a rejected call is declined', () {
      expect(outcomeFor('rejected'), CallLogOutcome.declined);
    });

    test('a missed call is missed', () {
      expect(outcomeFor('missed'), CallLogOutcome.missed);
    });

    test('an ended call that was never answered was given up on', () {
      // The server records "gave up before answer" and "talked then hung up"
      // both as `ended`; `answered_at` is the only thing that separates them.
      expect(outcomeFor('ended'), CallLogOutcome.cancelled);
      expect(
        outcomeFor('ended', answeredAt: '2026-09-02T20:40:56.000000Z'),
        CallLogOutcome.answered,
      );
    });

    test('a call still ringing is in progress', () {
      expect(outcomeFor('calling'), CallLogOutcome.ringing);
      expect(outcomeFor('ringing'), CallLogOutcome.ringing);
    });
  });

  group('what counts as a missed call', () {
    CallLogEntry entry({
      required CallLogDirection direction,
      required CallLogOutcome outcome,
    }) =>
        CallLogEntry(
          callId: 1,
          threadId: 17,
          peerId: them,
          peerName: 'Ayesha',
          isVideo: false,
          direction: direction,
          outcome: outcome,
          startedAt: DateTime(2026, 9, 2, 20, 41),
        );

    test('an incoming call nobody answered is missed', () {
      expect(
        entry(
          direction: CallLogDirection.incoming,
          outcome: CallLogOutcome.missed,
        ).isMissedCall,
        isTrue,
      );
    });

    test('an incoming call the caller cancelled is also missed', () {
      // From the receiver's side there is no difference worth drawing: the
      // phone rang and they did not get to it.
      final CallLogEntry e = entry(
        direction: CallLogDirection.incoming,
        outcome: CallLogOutcome.cancelled,
      );
      expect(e.isMissedCall, isTrue);
      expect(e.label, 'Missed call');
    });

    test('an incoming call I declined is not missed', () {
      final CallLogEntry e = entry(
        direction: CallLogDirection.incoming,
        outcome: CallLogOutcome.declined,
      );
      expect(e.isMissedCall, isFalse);
      expect(e.label, 'You declined');
    });

    test('my own unanswered outgoing call is not a missed call for me', () {
      final CallLogEntry e = entry(
        direction: CallLogDirection.outgoing,
        outcome: CallLogOutcome.missed,
      );
      expect(e.isMissedCall, isFalse, reason: 'the badge is for calls I missed');
      expect(e.label, 'No answer');
    });

    test('a cancelled outgoing call says I cancelled it', () {
      expect(
        entry(
          direction: CallLogDirection.outgoing,
          outcome: CallLogOutcome.cancelled,
        ).label,
        'Cancelled',
      );
    });
  });

  group('a row survives being stored and read back', () {
    test('every field round-trips through JSON', () {
      final CallLogEntry original = CallLogEntry(
        callId: 88,
        threadId: 17,
        peerId: them,
        peerName: 'Ayesha Khan test',
        peerPhoto: 'a.jpg',
        isVideo: true,
        direction: CallLogDirection.outgoing,
        outcome: CallLogOutcome.answered,
        startedAt: DateTime(2026, 9, 2, 20, 40, 56),
        durationSeconds: 33,
        seen: true,
      );

      final CallLogEntry back = CallLogEntry.fromJson(original.toJson())!;

      expect(back.callId, 88);
      expect(back.threadId, 17);
      expect(back.peerId, them);
      expect(back.peerName, 'Ayesha Khan test');
      expect(back.peerPhoto, 'a.jpg');
      expect(back.isVideo, isTrue);
      expect(back.direction, CallLogDirection.outgoing);
      expect(back.outcome, CallLogOutcome.answered);
      expect(back.startedAt, DateTime(2026, 9, 2, 20, 40, 56));
      expect(back.durationSeconds, 33);
      expect(back.seen, isTrue);
    });

    test('an unreadable row is dropped rather than crashing the list', () {
      expect(CallLogEntry.fromJson(<String, dynamic>{}), isNull);
      expect(
        CallLogEntry.fromJson(<String, dynamic>{'call_id': 5}),
        isNull,
        reason: 'no timestamp means it could never be sorted',
      );
    });
  });
}
