import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../features/vision/support/vision_test_channel.dart';
import 'package:blanquita/core/storage/esp32_credential_store.dart';

const testDeviceId = 'blanquita-main-01';
const testSecret =
    '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';

class MemoryCredentials implements Esp32CredentialStore {
  final values = <String, String>{};
  bool failWrites = false;
  Completer<void>? writeBarrier;
  @override
  Future<String?> read(String deviceId) async => values[deviceId];
  @override
  Future<void> write(String deviceId, String secret) async {
    await writeBarrier?.future;
    if (failWrites) throw StateError('storage unavailable');
    values[deviceId] = secret;
  }

  @override
  Future<void> delete(String deviceId) async {
    values.remove(deviceId);
  }
}

class _PeerSink extends TestVisionSink {
  _PeerSink(this.peer);
  final Esp32TestPeer peer;
  @override
  void add(dynamic data) {
    super.add(data);
    peer.handle(data as String);
  }
}

/// Independent firmware fixture. It does not call the production session codec.
class Esp32TestPeer extends TestVisionChannel {
  Esp32TestPeer({
    this.deviceId = testDeviceId,
    this.secret = testSecret,
    this.reply = true,
    this.busy = false,
    this.badProof = false,
    this.initialLimits = false,
  }) {
    _sink = _PeerSink(this);
  }
  final String deviceId;
  final String secret;
  final bool reply;
  final bool busy;
  final bool badProof;
  final bool initialLimits;
  late final TestVisionSink _sink;
  @override
  TestVisionSink get sink => _sink;
  static const serverNonce =
      '1111111111111111111111111111111111111111111111111111111111111111';
  static const sessionId = '22222222222222222222222222222222';
  String? transcript;
  List<int>? sessionKey;
  bool authorized = false;
  int sequence = 0;
  int eventSequence = 0;
  final commands = <String>[];
  static List<int> hex(String text) => [
    for (var i = 0; i < text.length; i += 2)
      int.parse(text.substring(i, i + 2), radix: 16),
  ];
  static String sign(List<int> key, String text) =>
      Hmac(sha256, key).convert(utf8.encode(text)).toString();

  void handle(String data) {
    final frame = jsonDecode(data) as Map<String, dynamic>;
    if (!reply) return;
    switch (frame['type']) {
      case 'hello.v2':
        transcript =
            '$deviceId|cartesian-controller|${frame['clientNonce']}|$serverNonce|$sessionId';
        send({
          'type': 'challenge.v2',
          'deviceId': deviceId,
          'deviceType': 'cartesian-controller',
          'clientNonce': frame['clientNonce'],
          'serverNonce': serverNonce,
          'sessionId': sessionId,
          'proof': badProof
              ? '0' * 64
              : sign(hex(secret), 'BLANQUITA_V2|server|$transcript'),
        });
      case 'auth.v2':
        if (busy) {
          scheduleMicrotask(() => incoming.addError(StateError('BUSY')));
          return;
        }
        if (frame['sessionId'] != sessionId ||
            frame['proof'] !=
                sign(hex(secret), 'BLANQUITA_V2|client|$transcript')) {
          throw StateError('client proof');
        }
        sessionKey = hex(sign(hex(secret), 'BLANQUITA_V2|session|$transcript'));
        authorized = true;
        send({
          'type': 'ready.v2',
          'sessionId': sessionId,
          'proof': sign(hex(secret), 'BLANQUITA_V2|ready|$transcript'),
        });
        if (initialLimits) {
          scheduleMicrotask(() {
            if (sink.closed) return;
            for (final name in ['X_IZQ', 'X_DER', 'Z_ARRIBA', 'Z_ABAJO']) {
              event('SENSOR:FC:$name:0');
            }
          });
        }
      case 'command.v2':
        if (!authorized ||
            frame['sessionId'] != sessionId ||
            frame['seq'] != sequence + 1 ||
            frame['proof'] !=
                sign(
                  sessionKey!,
                  'BLANQUITA_V2|command|$sessionId|${frame['seq']}|${frame['command']}',
                )) {
          throw StateError('command protection');
        }
        sequence++;
        commands.add(frame['command'] as String);
      default:
        throw StateError('unexpected command');
    }
  }

  void send(Map<String, dynamic> frame) => scheduleMicrotask(() {
    if (!sink.closed) incoming.add(jsonEncode(frame));
  });
  String eventFrame(String payload, {int? seq}) {
    final next = seq ?? ++eventSequence;
    return jsonEncode({
      'type': 'event.v2',
      'sessionId': sessionId,
      'seq': next,
      'payload': payload,
      'proof': sign(
        sessionKey!,
        'BLANQUITA_V2|event|$sessionId|$next|$payload',
      ),
    });
  }

  void event(String payload) => incoming.add(eventFrame(payload));
}
