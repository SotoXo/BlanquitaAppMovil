import 'dart:convert';

import 'package:blanquita/features/vision/domain/vision_endpoint.dart';
import 'package:blanquita/features/vision/services/vision_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UDP sender and advertised port produce the exact desktop endpoint', () {
    final uri = VisionDiscoveryService.parseResponse(
      utf8.encode('BLANQUITA_VISION_HERE:8765'),
      '192.168.137.233',
    )!;
    expect(uri.toString(), 'ws://192.168.137.233:8765/vision');
    expect(uri.scheme, 'ws');
    expect(uri.host, '192.168.137.233');
    expect(uri.port, 8765);
    expect(uri.path, '/vision');
    expect(uri.hasFragment, false);
    expect(uri.hasQuery, false);
  });

  test('manual, legacy and router URLs converge on one endpoint', () {
    for (final suffix in ['', '/', '/vision', '/vision/', '/#/vision']) {
      final uri = VisionEndpoint.parse(' ws://192.168.137.233:8765$suffix ');
      expect(uri.toString(), 'ws://192.168.137.233:8765/vision');
      expect(uri.hasFragment || uri.hasQuery, false);
    }
    expect(VisionEndpoint.parse('ws://laptop').port, 8765);
    expect(
      VisionEndpoint.fromHost('127.0.0.1', port: 1234).toString(),
      'ws://127.0.0.1:1234/vision',
    );
  });

  test(
    'no HTTP, WSS, arbitrary path, query, fragment or credentials reach IO',
    () {
      for (final value in [
        'http://192.168.137.233:8765/',
        'https://laptop/vision',
        'wss://laptop/vision',
        'ws://laptop/other',
        'ws://laptop/vision#',
        'ws://laptop/#other',
        'ws://laptop/vision?token=a',
        'ws://laptop/vision?',
        'ws://user:pass@laptop/vision',
        'ws://laptop:0/vision',
        'ws://laptop:65536/vision',
        'ws://laptop:abc/vision',
        'ws://',
      ]) {
        expect(VisionEndpoint.isValid(value), false, reason: value);
        expect(
          () => VisionEndpoint.parse(value),
          throwsFormatException,
          reason: value,
        );
      }
    },
  );
}
