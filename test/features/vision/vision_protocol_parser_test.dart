import 'dart:convert';

import 'package:blanquita/features/vision/domain/vision_message.dart';
import 'package:blanquita/features/vision/services/vision_protocol_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String packet(String type, [Map<String, Object?> payload = const {}]) =>
    jsonEncode({
      'protocol': 'blanquita-vision',
      'version': 1,
      'type': type,
      'messageId': 'report-1',
      'timestamp': '2026-10-06T10:30:00Z',
      'payload': payload,
    });

void main() {
  const parser = VisionProtocolParser();
  test('vision.ready supplies readiness without invented telemetry', () {
    final result = parser.parse(packet('vision.ready'));
    expect(result.message!.type, VisionMessageType.ready);
    expect(result.message!.status.ready, true);
    expect(result.message!.status.cameraName, isNull);
    expect(result.message!.status.fps, isNull);
  });

  test('vision.status accepts partial typed telemetry', () {
    final result = parser.parse(
      packet('vision.status', {
        'ready': false,
        'cameraName': 'USB',
        'cameraStatus': 'operative',
        'detectorStatus': 'active',
        'calibrationStatus': 'valid',
        'fps': 24,
        'latency': 8.2,
      }),
    );
    final status = result.message!.status;
    expect(status.ready, false);
    expect(status.cameraName, 'USB');
    expect(status.fps, 24.0);
    expect(status.latency, 8.2);
    expect(status.calibrationStatus, 'valid');
  });

  test('valid report preserves position, confidence and server timestamp', () {
    final report = parser
        .parse(
          packet('vision.report', {
            'detected': true,
            'object': 'pieza',
            'position': {'x': 145.2, 'z': 78.4},
            'confidence': 0.96,
            'alerts': ['prueba'],
          }),
        )
        .message!
        .report!;
    expect(report.id, 'report-1');
    expect(report.detected, true);
    expect(report.object, 'pieza');
    expect(report.position!.x, 145.2);
    expect(report.position!.z, 78.4);
    expect(report.position!.confidence, 0.96);
    expect(report.position!.timestamp, DateTime.utc(2026, 10, 6, 10, 30));
    expect(report.alerts, ['prueba']);
  });

  test('missing, null and empty positions remain null', () {
    for (final payload in <Map<String, Object?>>[
      {},
      {'detected': false},
      {'position': null},
      {'position': {}},
    ]) {
      expect(
        parser
            .parse(packet('vision.report', payload))
            .message!
            .report!
            .position,
        isNull,
      );
    }
  });

  test('partial position never invents the missing axis', () {
    final position = parser
        .parse(
          packet('vision.report', {
            'position': {'x': 4},
          }),
        )
        .message!
        .report!
        .position!;
    expect(position.x, 4);
    expect(position.z, isNull);
    expect(position.hasPosition, false);
  });

  test('invalid JSON and non-text frames are rejected safely', () {
    for (final raw in <Object?>[
      '{bad',
      'null',
      '[]',
      4,
      [0, 1],
      null,
    ]) {
      final result = parser.parse(raw);
      expect(result.error, isNotNull);
      expect(result.message, isNull);
    }
  });

  test(
    'incorrect protocol, version and required envelope fields are rejected',
    () {
      final original =
          jsonDecode(packet('vision.ready')) as Map<String, dynamic>;
      for (final change in <Map<String, Object?>>[
        {'protocol': 'esp32'},
        {'version': 2},
        {'version': '1'},
        {'version': 1.0},
        {'messageId': ''},
        {'timestamp': 'yesterday'},
        {'payload': []},
        {'type': null},
      ]) {
        expect(
          parser.parse(jsonEncode({...original, ...change})).error,
          isNotNull,
        );
      }
    },
  );

  test('unknown type is ignored rather than interpreted as a command', () {
    for (final type in ['vision.future', 'motor.move', 'd']) {
      final result = parser.parse(packet(type));
      expect(result.ignored, true);
      expect(result.message, isNull);
      expect(result.error, isNull);
    }
  });

  test('heartbeat and ping correlation are decoded', () {
    final message = parser
        .parse(packet('vision.heartbeat', {'replyTo': 'mobile-1'}))
        .message!;
    expect(message.type, VisionMessageType.heartbeat);
    expect(message.replyTo, 'mobile-1');
  });

  test('camera and calibration status messages use status/name', () {
    final camera = parser
        .parse(
          packet('camera.status', {'status': 'disconnected', 'name': 'USB'}),
        )
        .message!;
    final calibration = parser
        .parse(packet('calibration.status', {'status': 'invalid'}))
        .message!;
    expect(camera.status.cameraStatus, 'disconnected');
    expect(camera.status.cameraName, 'USB');
    expect(calibration.status.calibrationStatus, 'invalid');
  });

  test('hello and server error are supported', () {
    expect(parser.parse(packet('vision.hello')).message!.status.ready, isNull);
    expect(
      parser
          .parse(
            packet('vision.error', {
              'code': 'CAMERA_LOST',
              'message': 'Sin cámara',
            }),
          )
          .message!
          .error,
      'Sin cámara',
    );
  });

  test('malformed known payload fields are rejected atomically', () {
    for (final payload in <Map<String, Object?>>[
      {'detected': 'yes'},
      {'object': 4},
      {'position': 'x'},
      {
        'position': {'x': '145'},
      },
      {
        'position': {'z': 1e1000},
      },
      {'confidence': -0.1},
      {'confidence': 1.1},
      {'confidence': '0.96'},
      {'ready': 1},
      {'fps': -1},
      {'latency': -1},
      {
        'alerts': [7],
      },
      {'cameraName': 7},
    ]) {
      // JSON cannot encode infinities; inject an overflowing numeric literal.
      final raw =
          payload['position'] is Map &&
              (payload['position'] as Map)['z'] == double.infinity
          ? packet(
              'vision.report',
            ).replaceFirst('"payload":{}', '"payload":{"position":{"z":1e999}}')
          : packet('vision.report', payload);
      expect(parser.parse(raw).error, isNotNull, reason: '$payload');
    }
  });

  test('invalid calendar timestamps are not silently normalized', () {
    for (final timestamp in [
      '2026-02-30T10:30:00Z',
      '2026-13-01T00:00:00Z',
      '2026-10-06T25:00:00Z',
    ]) {
      final raw = packet(
        'vision.report',
      ).replaceFirst('2026-10-06T10:30:00Z', timestamp);
      expect(parser.parse(raw).error, isNotNull);
    }
  });
}
