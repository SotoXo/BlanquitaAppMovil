import 'dart:convert';
import 'dart:io';

import 'package:blanquita/core/network/esp32_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts exact HERE response and builds WebSocket from sender IP', () {
    final uri = Esp32DiscoveryService.parseResponse(
      utf8.encode('BLANQUITA_HERE:81'),
      '192.168.43.27',
    );
    expect(uri.toString(), 'ws://192.168.43.27:81/');
    expect(Esp32DiscoveryService.discoveryPort, 4210);
    // No assumption about a /24 subnet or a fixed hotspot address.
    expect(
      Esp32DiscoveryService.parseResponse(
        utf8.encode('BLANQUITA_HERE:81'),
        '10.2.1.255',
      ),
      isNotNull,
    );
  });

  test('rejects invalid responses and invalid sender addresses', () {
    for (final text in [
      '',
      'BLANQUITA_DISCOVER',
      'READY',
      'BLANQUITA_HERE',
      'BLANQUITA_HERE:80',
      'BLANQUITA_HERE:8081',
      'BLANQUITA_HERE:81:192.168.1.2',
      'BLANQUITA_HERE:81\n',
      ' BLANQUITA_HERE:81',
      'BLANQUITA_HERE:81\u0000',
    ]) {
      expect(
        Esp32DiscoveryService.parseResponse(utf8.encode(text), '192.168.43.27'),
        isNull,
        reason: text,
      );
    }
    expect(
      Esp32DiscoveryService.parseResponse([0xff, 0xfe], '192.168.43.27'),
      isNull,
    );
    for (final address in [
      'host.local',
      '::1',
      '192.168.1.999',
      '192.168.01.2',
      '0.0.0.0',
      '255.255.255.255',
      '224.0.0.1',
    ]) {
      expect(
        Esp32DiscoveryService.parseResponse(
          utf8.encode('BLANQUITA_HERE:81'),
          address,
        ),
        isNull,
        reason: address,
      );
    }
  });

  test(
    'native UDP uses exact request and source address after invalid packet',
    () async {
      // A local transport fixture, never a production device or command source.
      final peer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final service = Esp32DiscoveryService(
        port: peer.port,
        broadcastAddress: '127.0.0.1',
        timeout: const Duration(seconds: 1),
      );
      final received = <String>[];
      final subscription = peer.listen((event) {
        if (event != RawSocketEvent.read) return;
        final packet = peer.receive();
        if (packet == null) return;
        received.add(utf8.decode(packet.data));
        peer.send(
          utf8.encode('BLANQUITA_HERE:80'),
          packet.address,
          packet.port,
        );
        // Windows may return zero for an immediately consecutive UDP send.
        Future<void>.delayed(const Duration(milliseconds: 10), () {
          peer.send(
            utf8.encode('BLANQUITA_HERE:81'),
            packet.address,
            packet.port,
          );
        });
      });
      try {
        expect((await service.discover()).toString(), 'ws://127.0.0.1:81/');
        expect(received, ['BLANQUITA_DISCOVER']);
      } finally {
        service.dispose();
        await subscription.cancel();
        peer.close();
      }
    },
  );

  test('UDP timeout is bounded and transmits at most three requests', () async {
    final peer = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final service = Esp32DiscoveryService(
      port: peer.port,
      broadcastAddress: '127.0.0.1',
      timeout: const Duration(milliseconds: 100),
      retryInterval: const Duration(milliseconds: 10),
    );
    var packets = 0;
    final subscription = peer.listen((event) {
      if (event == RawSocketEvent.read) {
        while (peer.receive() != null) {
          packets++;
        }
      }
    });
    try {
      expect(await service.discover(), isNull);
      expect(packets, 3);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(packets, 3);
    } finally {
      service.dispose();
      await subscription.cancel();
      peer.close();
    }
  });

  test(
    'cancel and dispose settle pending discovery without a candidate',
    () async {
      final service = Esp32DiscoveryService();
      final pending = service.discover();
      service.cancel();
      expect(await pending, isNull);
      final next = service.discover();
      service.dispose();
      expect(await next, isNull);
      expect(await service.discover(), isNull);
    },
  );
}
