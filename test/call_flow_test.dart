// Mobile calls now run on the backend's own call API — the same one the
// website drives — so a call placed on a phone writes the same `calls` row and
// the same server logs as one placed in a browser.
//
// Before this, the app ran a parallel scheme of its own: it invented the Agora
// channel (`call_thread_{id}`), sent the invite as a chat message beginning
// `[CALL_INVITE:`, polled the thread every three seconds to spot it, and joined
// with a temporary Agora token compiled into the binary. None of that reached
// `POST /calls`, so nothing was logged, a closed app never rang, and a mobile
// member could not reach a web one.
//
// The channel names and event names asserted here are read off the backend:
// `App\Events\ChatMessageSent` / `CallBroadcastEvent` broadcast on
// `PrivateChannel('App.User.{id}')` and `PrivateChannel('chat-thread.{id}')`,
// and `resources/views/frontend/layouts/app.blade.php` listens with
// `Echo.private('App.User.{id}').listen('.call-incoming', …)`.
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/core/services/pusher_chat_service.dart';
import 'package:hamqadam/constants/api_endpoints.dart';
import 'package:hamqadam/models/call_model.dart';

/// A `call-incoming` broadcast exactly as `CallService::payload()` builds it,
/// including `rtc: null` — the server withholds the token from broadcasts so
/// each side has to fetch its own.
Map<String, dynamic> _incomingBroadcast({
  int callId = 41,
  int callerId = 7,
  int receiverId = 9,
  String status = 'calling',
  String type = 'video',
  String? ringExpiresAt,
}) {
  return <String, dynamic>{
    'call': <String, dynamic>{
      'id': callId,
      'conversation_id': 12,
      'thread_id': 12,
      'agora_channel': 'call_12_41',
      'call_type': type,
      'status': status,
      'caller': <String, dynamic>{
        'id': callerId,
        'code': 'HQ7',
        'name': 'Bilal Ahmed',
        'photo': 'https://hamqadam.com/uploads/all/caller.jpg',
      },
      'receiver': <String, dynamic>{
        'id': receiverId,
        'code': 'HQ9',
        'name': 'Sana Khan',
        'photo': 'https://hamqadam.com/uploads/all/receiver.jpg',
      },
      'self': <String, dynamic>{},
      'peer': <String, dynamic>{},
      'ring_expires_at': ringExpiresAt,
      'started_at': null,
      'answered_at': null,
      'ended_at': null,
      'duration_seconds': 0,
      'ended_by_user_id': null,
      'metadata': <dynamic>[],
      'message': 'Ali is calling you...',
      'actor_id': callerId,
    },
    'rtc': null,
  };
}

void main() {
  group('the app subscribes to the channels Laravel publishes on', () {
    test('the user channel is the private one', () {
      // `PrivateChannel('App.User.9')` reaches Pusher as `private-App.User.9`.
      // Subscribing without the prefix is subscribing to a public channel
      // nobody writes to — which is why no event ever arrived, and why the
      // service's own `onAuthorizer` never ran (Pusher authorizes only
      // `private-` and `presence-` channels).
      expect(PusherChatService.userChannel(9), 'private-App.User.9');
    });

    test('the thread channel is the private one', () {
      expect(PusherChatService.threadChannel(12), 'private-chat-thread.12');
    });

    test('both match what the website subscribes to', () {
      // resources/views/frontend/layouts/app.blade.php:
      //   Echo.private('App.User.{{ Auth::id() }}')
      // resources/views/frontend/member/messages/messages.blade.php:
      //   Echo.private(`chat-thread.${threadId}`)
      expect(PusherChatService.userChannel(1), startsWith('private-App.User.'));
      expect(PusherChatService.threadChannel(1), startsWith('private-chat-thread.'));
    });
  });

  group('the call endpoints are the ones the website uses', () {
    test('paths match routes/api_v1.php', () {
      // The call routes are a `prefix('/calls')` group nested INSIDE
      // `prefix('chat')`, so every path carries both:
      //
      //   Route::middleware('auth:sanctum')->prefix('chat')->group(function () {
      //       Route::prefix('/calls')->group(function () {
      //           Route::post('/', [CallController::class, 'start']);
      //
      // This test asserted the bare `/calls` form, which is the group's own
      // prefix read without its parent — every one of those would 404.
      expect(ApiEndpoints.callStart, '/chat/calls');
      expect(ApiEndpoints.callAccept(41), '/chat/calls/41/accept');
      expect(ApiEndpoints.callReject(41), '/chat/calls/41/reject');
      expect(ApiEndpoints.callCancel(41), '/chat/calls/41/cancel');
      expect(ApiEndpoints.callConnect(41), '/chat/calls/41/connect');
      expect(ApiEndpoints.callEnd(41), '/chat/calls/41/end');
      expect(ApiEndpoints.callMissed(41), '/chat/calls/41/missed');
      expect(ApiEndpoints.call(41), '/chat/calls/41');
      expect(ApiEndpoints.threadCalls(12), '/chat/threads/12/calls');
    });
  });

  group('a call broadcast parses into a usable call', () {
    test('every field the UI needs survives the round trip', () {
      final CallSession session = CallSession.fromJson(_incomingBroadcast())!;
      final CallModel call = session.call;

      expect(call.id, 41);
      expect(call.threadId, 12);
      expect(call.agoraChannel, 'call_12_41');
      expect(call.isVideo, isTrue);
      expect(call.status, CallStatus.calling);
      expect(call.caller?.displayName, 'Bilal Ahmed');
      expect(call.receiver?.id, 9);
    });

    test('a broadcast carries no credentials — each side fetches its own', () {
      // `CallService::start()` sets `$payload['rtc'] = null` before
      // broadcasting; the caller's token comes back over HTTP and the
      // receiver's from `POST /calls/{id}/accept`.
      expect(CallSession.fromJson(_incomingBroadcast())!.rtc, isNull);
    });

    test('roles are read from the payload, not guessed', () {
      final CallModel call = CallSession.fromJson(_incomingBroadcast())!.call;

      expect(call.isReceiver(9), isTrue);
      expect(call.isCaller(9), isFalse);
      expect(call.isCaller(7), isTrue);
      // The event also lands on the thread channel, where the caller hears its
      // own ring; the receiver check is what stops it ringing for them.
      expect(call.isReceiver(7), isFalse);
    });

    test('the peer is whoever the viewer is not', () {
      final CallModel call = CallSession.fromJson(_incomingBroadcast())!.call;

      expect(call.peerFor(9)?.id, 7);
      expect(call.peerFor(7)?.id, 9);
    });

    test('an absent participant serialises as [] and reads as null', () {
      final Map<String, dynamic> body = _incomingBroadcast();
      (body['call'] as Map<String, dynamic>)['receiver'] = <dynamic>[];

      expect(CallSession.fromJson(body)!.call.receiver, isNull);
    });

    test('a payload with no call node is refused rather than half-built', () {
      expect(CallSession.fromJson(<String, dynamic>{'rtc': null}), isNull);
    });
  });

  group('rtc credentials', () {
    test('an accept response carries the receiver\'s own token and uid', () {
      final CallSession session = CallSession.fromJson(<String, dynamic>{
        'call': (_incomingBroadcast(status: 'accepted')['call']),
        'rtc': <String, dynamic>{
          'app_id': 'abc123',
          'channel': 'call_12_41',
          'token': '007eJxSIGNED',
          'uid': 9,
          'expires_at': '2026-08-30T12:00:00.000000Z',
          'expires_in': 3600,
        },
      })!;

      final RtcCredentials rtc = session.rtc!;
      expect(rtc.appId, 'abc123');
      expect(rtc.channel, 'call_12_41');
      expect(rtc.token, '007eJxSIGNED');
      // The token is signed for this uid; joining Agora as any other uid — 0
      // included, which is what the screen used to pass — is rejected.
      expect(rtc.uid, 9);
      expect(rtc.expiresIn, 3600);
    });

    test('an incomplete rtc node is treated as absent', () {
      // Better to say "calling unavailable" than to join a channel with a
      // token that cannot work.
      expect(
        RtcCredentials.fromJson(<String, dynamic>{'app_id': 'abc', 'channel': 'c'}),
        isNull,
      );
      expect(RtcCredentials.fromJson(<String, dynamic>{}), isNull);
      expect(RtcCredentials.fromJson(null), isNull);
    });
  });

  group('call status', () {
    test('the live statuses are the ones worth ringing for', () {
      expect(CallStatus.parse('calling').isLive, isTrue);
      expect(CallStatus.parse('ringing').isLive, isTrue);
      expect(CallStatus.parse('accepted').isLive, isTrue);
      expect(CallStatus.parse('connected').isLive, isTrue);
    });

    test('a finished call is not rung for', () {
      // What stops a push delayed by Doze from ringing for a call the caller
      // gave up on minutes ago.
      for (final String s in <String>['rejected', 'cancelled', 'missed', 'busy', 'ended']) {
        expect(CallStatus.parse(s).isLive, isFalse, reason: s);
        expect(CallStatus.parse(s).isOver, isTrue, reason: s);
      }
    });

    test('an unknown status is neither live nor over', () {
      expect(CallStatus.parse('something_new'), CallStatus.unknown);
      expect(CallStatus.parse(null), CallStatus.unknown);
    });
  });

  group('the ring window comes from the server', () {
    test('a future expiry counts down', () {
      final String future =
          DateTime.now().toUtc().add(const Duration(seconds: 30)).toIso8601String();
      final CallModel call =
          CallSession.fromJson(_incomingBroadcast(ringExpiresAt: future))!.call;

      expect(call.secondsUntilRingExpiry, greaterThan(20));
      expect(call.secondsUntilRingExpiry, lessThanOrEqualTo(30));
    });

    test('an expiry already past floors at zero rather than going negative', () {
      final String past =
          DateTime.now().toUtc().subtract(const Duration(minutes: 2)).toIso8601String();
      final CallModel call =
          CallSession.fromJson(_incomingBroadcast(ringExpiresAt: past))!.call;

      expect(call.secondsUntilRingExpiry, 0);
    });

    test('no expiry reads as zero, so the caller falls back', () {
      expect(CallSession.fromJson(_incomingBroadcast())!.call.secondsUntilRingExpiry, 0);
    });
  });
}
