import 'dart:convert';
import 'dart:io';
import 'package:blanquita/core/protocol/esp32_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vector =
      jsonDecode(File('docs/fixtures/esp32-v2-vectors.json').readAsStringSync())
          as Map<String, dynamic>;
  Esp32Session session() => Esp32Session(
    deviceId: vector['deviceId'],
    secret: vector['secret'],
    clientNonce: vector['clientNonce'],
  );
  String challenge() => jsonEncode({
    'type': 'challenge.v2',
    'deviceId': vector['deviceId'],
    'deviceType': 'cartesian-controller',
    'clientNonce': vector['clientNonce'],
    'serverNonce': vector['serverNonce'],
    'sessionId': vector['sessionId'],
    'proof': vector['serverProof'],
  });
  String ready() => jsonEncode({
    'type': 'ready.v2',
    'sessionId': vector['sessionId'],
    'proof': vector['readyProof'],
  });
  test('wire protocol matches independent .NET HMAC vectors for Arduino', () {
    final s = session();
    expect(s.authorized, false);
    expect(
      jsonDecode(s.answerChallenge(challenge()))['proof'],
      vector['clientProof'],
    );
    expect(s.identityVerified, true);
    expect(s.authorized, false);
    expect(() => s.command('a'), throwsFormatException);
    s.acceptReady(ready());
    final command = jsonDecode(s.command('a')) as Map<String, dynamic>;
    expect(command['seq'], 1);
    expect(command['command'], 'a');
    expect(command['proof'], vector['commandProof']);
    final event = jsonEncode({
      'type': 'event.v2',
      'sessionId': vector['sessionId'],
      'seq': 1,
      'payload': 'SENSOR:ESTADO:P=1,F=0',
      'proof': vector['eventProof'],
    });
    expect(s.event(event), 'SENSOR:ESTADO:P=1,F=0');
    expect(() => s.event(event), throwsFormatException);
  });
  test(
    'wrong ready proof, session and reordered handshake cannot authorize',
    () {
      final s = session();
      expect(() => s.acceptReady(ready()), throwsFormatException);
      s.answerChallenge(challenge());
      for (final frame in [
        'READY',
        jsonEncode({
          'type': 'ready.v2',
          'sessionId': vector['sessionId'],
          'proof': '0' * 64,
        }),
        jsonEncode({
          'type': 'ready.v2',
          'sessionId': '0' * 32,
          'proof': vector['readyProof'],
        }),
      ]) {
        expect(() => s.acceptReady(frame), throwsFormatException);
        expect(s.authorized, false);
      }
    },
  );
  test(
    'nonces differ between connections and malformed/oversized frames are rejected',
    () {
      expect(
        Esp32Session(
          deviceId: vector['deviceId'],
          secret: vector['secret'],
        ).clientNonce,
        isNot(
          Esp32Session(
            deviceId: vector['deviceId'],
            secret: vector['secret'],
          ).clientNonce,
        ),
      );
      for (final frame in ['[]', 'null', '{', ' ' * 4097]) {
        expect(() => session().answerChallenge(frame), throwsFormatException);
      }
      expect(
        () => Esp32Session(deviceId: 'bad|id', secret: vector['secret']),
        throwsFormatException,
      );
      expect(
        () => Esp32Session(deviceId: 'robot', secret: 'pin123'),
        throwsFormatException,
      );
    },
  );
}
