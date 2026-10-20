import 'dart:convert';
import 'dart:io';

import 'package:blanquita/features/vision/services/vision_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blanquita/core/network/esp32_discovery_service.dart';

void main() {
  test('DHCP source IP is used exactly and payload cannot supply an IP', () {
    for (final sender in ['172.20.10.7', '10.42.193.22', '192.168.137.115']) {
      expect(
        VisionDiscoveryService.parseResponse(
          utf8.encode(VisionDiscoveryService.response),
          sender,
        ).toString(),
        'ws://$sender:8765/vision',
      );
      expect(
        VisionDiscoveryService.parseResponse(
          utf8.encode('${VisionDiscoveryService.response}:1.2.3.4'),
          sender,
        ),
        isNull,
      );
    }
  });

  test(
    'Vision cancellation does not cancel simultaneous ESP32 UDP discovery',
    () async {
      final espPeer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final visionPeer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final machine = Esp32DiscoveryService(
        port: espPeer.port,
        broadcastAddress: '127.0.0.1',
        timeout: const Duration(seconds: 1),
      );
      final vision = VisionDiscoveryService(
        port: visionPeer.port,
        broadcastAddress: '127.0.0.1',
        timeout: const Duration(seconds: 1),
      );
      final subscriptions = [
        espPeer.listen((event) {
          if (event != RawSocketEvent.read) return;
          final packet = espPeer.receive();
          if (packet == null) return;
          expect(utf8.decode(packet.data), Esp32DiscoveryService.request);
          vision.cancel();
          espPeer.send(
            utf8.encode(Esp32DiscoveryService.response),
            packet.address,
            packet.port,
          );
        }),
        visionPeer.listen((event) {
          if (event == RawSocketEvent.read) visionPeer.receive();
        }),
      ];
      try {
        final findingVision = vision.discover();
        final findingMachine = machine.discover();
        expect((await findingMachine).toString(), 'ws://127.0.0.1:81/');
        expect(await findingVision, isNull);
      } finally {
        machine.dispose();
        vision.dispose();
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        espPeer.close();
        visionPeer.close();
      }
    },
  );

  test('accepts exact HERE response and builds WebSocket from sender IP', () {
    final uri = VisionDiscoveryService.parseResponse(
      utf8.encode('BLANQUITA_VISION_HERE:8765'),
      '192.168.43.27',
    );
    expect(uri.toString(), 'ws://192.168.43.27:8765/vision');
    expect(VisionDiscoveryService.discoveryPort, 4211);
    // No assumption about a /24 subnet or a fixed hotspot address.
    expect(
      VisionDiscoveryService.parseResponse(
        utf8.encode('BLANQUITA_VISION_HERE:8765'),
        '10.2.1.255',
      ),
      isNotNull,
    );
  });

  test('rejects invalid responses and invalid sender addresses', () {
    for (final text in [
      '',
      'BLANQUITA_VISION_DISCOVER',
      'READY',
      'BLANQUITA_VISION_HERE',
      'BLANQUITA_VISION_HERE:80',
      'BLANQUITA_VISION_HERE:8766',
      'BLANQUITA_VISION_HERE:8765:192.168.1.2',
      'BLANQUITA_VISION_HERE:8765\n',
      ' BLANQUITA_VISION_HERE:8765',
      'BLANQUITA_VISION_HERE:8765\u0000',
    ]) {
      expect(
        VisionDiscoveryService.parseResponse(
          utf8.encode(text),
          '192.168.43.27',
        ),
        isNull,
        reason: text,
      );
    }
    expect(
      VisionDiscoveryService.parseResponse([0xff, 0xfe], '192.168.43.27'),
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
        VisionDiscoveryService.parseResponse(
          utf8.encode('BLANQUITA_VISION_HERE:8765'),
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
      final service = VisionDiscoveryService(
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
          utf8.encode('BLANQUITA_VISION_HERE:80'),
          packet.address,
          packet.port,
        );
        // Windows may return zero for an immediately consecutive UDP send.
        Future<void>.delayed(const Duration(milliseconds: 10), () {
          peer.send(
            utf8.encode('BLANQUITA_VISION_HERE:8765'),
            packet.address,
            packet.port,
          );
        });
      });
      try {
        expect(
          (await service.discover()).toString(),
          'ws://127.0.0.1:8765/vision',
        );
        expect(received, ['BLANQUITA_VISION_DISCOVER']);
      } finally {
        service.dispose();
        await subscription.cancel();
        peer.close();
      }
    },
  );

  test('UDP timeout is bounded and transmits at most three requests', () async {
    final peer = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final service = VisionDiscoveryService(
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
      final service = VisionDiscoveryService();
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
