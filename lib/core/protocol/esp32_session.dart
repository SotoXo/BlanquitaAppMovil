import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/esp32_device.dart';

/// Proposed wire protocol. Requires matching Arduino firmware; never downgrades.
class Esp32Session {
  Esp32Session({
    required this.deviceId,
    required String secret,
    String? clientNonce,
  }) : _key = decodeHex(secret),
       clientNonce = clientNonce ?? randomHex(32) {
    if (!Esp32Device.validId(deviceId) ||
        !validSecret(secret) ||
        !isHex(this.clientNonce, 64)) {
      throw const FormatException('Credencial V2 inválida');
    }
  }

  final String deviceId;
  final String clientNonce;
  final List<int> _key;
  String? _sessionId;
  String? _transcript;
  List<int>? _sessionKey;
  bool _authorized = false;
  int _sent = 0;
  int _received = 0;
  bool get authorized => _authorized;
  bool get identityVerified => _transcript != null;

  static bool isHex(String value, int length) =>
      value.length == length &&
      RegExp(r'^[0-9a-f]+$').stringMatch(value) == value;
  static bool validSecret(String value) => isHex(value, 64);
  static String randomHex(int bytes) {
    final random = Random.secure();
    return List.generate(
      bytes,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static List<int> decodeHex(String value) {
    if (value.length.isOdd ||
        RegExp(r'^[0-9a-f]+$').stringMatch(value) != value) {
      throw const FormatException('Hex inválido');
    }
    return [
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ];
  }

  static String mac(List<int> key, String text) =>
      Hmac(sha256, key).convert(utf8.encode(text)).toString();

  static bool _matches(String expected, Object? actual) {
    if (actual is! String || !isHex(actual, 64)) return false;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected.codeUnitAt(i) ^ actual.codeUnitAt(i);
    }
    return difference == 0;
  }

  String hello() => jsonEncode({
    'type': 'hello.v2',
    'deviceId': deviceId,
    'clientNonce': clientNonce,
  });

  Map<String, dynamic> _frame(Object? data) {
    if (data is! String || utf8.encode(data).length > 4096) {
      throw const FormatException('Trama V2 inválida');
    }
    final json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Trama V2 inválida');
    }
    return json;
  }

  /// Returns auth after verifying the device's proof of the provisioned key.
  String answerChallenge(Object? data) {
    final frame = _frame(data);
    if (_transcript != null ||
        frame['type'] != 'challenge.v2' ||
        frame['deviceId'] != deviceId ||
        frame['deviceType'] != Esp32Device.cartesianType ||
        frame['clientNonce'] != clientNonce ||
        frame['serverNonce'] is! String ||
        !isHex(frame['serverNonce'] as String, 64) ||
        frame['sessionId'] is! String ||
        !isHex(frame['sessionId'] as String, 32)) {
      throw const FormatException('Identidad V2 incorrecta');
    }
    final transcript =
        '$deviceId|${Esp32Device.cartesianType}|$clientNonce|${frame['serverNonce']}|${frame['sessionId']}';
    if (!_matches(
      mac(_key, 'BLANQUITA_V2|server|$transcript'),
      frame['proof'],
    )) {
      throw const FormatException('Prueba del dispositivo inválida');
    }
    _transcript = transcript;
    _sessionId = frame['sessionId'] as String;
    _sessionKey = decodeHex(mac(_key, 'BLANQUITA_V2|session|$transcript'));
    return jsonEncode({
      'type': 'auth.v2',
      'sessionId': _sessionId,
      'proof': mac(_key, 'BLANQUITA_V2|client|$transcript'),
    });
  }

  void acceptReady(Object? data) {
    final frame = _frame(data);
    if (_authorized ||
        _transcript == null ||
        frame['type'] != 'ready.v2' ||
        frame['sessionId'] != _sessionId ||
        !_matches(
          mac(_key, 'BLANQUITA_V2|ready|$_transcript'),
          frame['proof'],
        )) {
      throw const FormatException('READY V2 no autorizado');
    }
    _authorized = true;
  }

  String command(String command) {
    if (!_authorized ||
        command.length != 1 ||
        !RegExp(r'^[adwsxkqejz+\-]$').hasMatch(command) ||
        _sent >= 2147483647) {
      throw const FormatException('Comando no autorizado');
    }
    final sequence = ++_sent;
    return jsonEncode({
      'type': 'command.v2',
      'sessionId': _sessionId,
      'seq': sequence,
      'command': command,
      'proof': mac(
        _sessionKey!,
        'BLANQUITA_V2|command|$_sessionId|$sequence|$command',
      ),
    });
  }

  String event(Object? data) {
    final frame = _frame(data);
    final sequence = frame['seq'];
    final payload = frame['payload'];
    if (!_authorized ||
        frame['type'] != 'event.v2' ||
        frame['sessionId'] != _sessionId ||
        sequence is! int ||
        sequence != _received + 1 ||
        sequence > 2147483647 ||
        payload is! String ||
        payload.isEmpty ||
        payload.length > 1024 ||
        payload.contains('|') ||
        !_matches(
          mac(
            _sessionKey!,
            'BLANQUITA_V2|event|$_sessionId|$sequence|$payload',
          ),
          frame['proof'],
        )) {
      throw const FormatException('Evento V2 inválido o repetido');
    }
    _received = sequence;
    return payload;
  }
}
