import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:blanquita/core/network/esp32_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 parses exact identity and type with IP only from datagram', () {
    final d = Esp32DiscoveryService.parseV2Response(
      utf8.encode('BLANQUITA_HERE_V2|robot-01|cartesian-controller|81'),
      '172.20.10.9',
    )!;
    expect(d.deviceId, 'robot-01');
    expect(d.ip, '172.20.10.9');
    expect(d.port, 81);
    for (final text in [
      'READY',
      'BLANQUITA_HERE:81',
      'BLANQUITA_HERE_V2||cartesian-controller|81',
      'BLANQUITA_HERE_V2|robot|sensor|81',
      'BLANQUITA_HERE_V2|robot|cartesian-controller|80',
      'BLANQUITA_HERE_V2|robot|cartesian-controller|81|10.0.0.2',
      'BLANQUITA_HERE_V2|robot|cartesian-controller|81\n',
    ]) {
      expect(
        Esp32DiscoveryService.parseV2Response(utf8.encode(text), '10.1.2.3'),
        isNull,
      );
    }
    expect(Esp32DiscoveryService.parseV2Response([255], '10.1.2.3'), isNull);
    expect(
      Esp32DiscoveryService.parseV2Response(
        utf8.encode('BLANQUITA_HERE_V2|robot|cartesian-controller|81'),
        '255.255.255.255',
      ),
      isNull,
    );
  });
  test(
    'native UDP collects several replies throughout bounded window and deduplicates',
    () async {
      final peer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final service = Esp32DiscoveryService(
        port: peer.port,
        broadcastAddress: '127.0.0.1',
        timeout: const Duration(milliseconds: 250),
        retryInterval: const Duration(milliseconds: 50),
      );
      final requests = <String>[];
      final timers = <Timer>[];
      final sub = peer.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? p;
        while ((p = peer.receive()) != null) {
          final packet = p!;
          requests.add(utf8.decode(packet.data));
          for (var i = 0; i < 3; i++) {
            timers.add(
              Timer(Duration(milliseconds: 10 + i * 20), () {
                peer.send(
                  utf8.encode(
                    'BLANQUITA_HERE_V2|${i == 1 ? 'second' : 'first'}|cartesian-controller|81',
                  ),
                  packet.address,
                  packet.port,
                );
              }),
            );
          }
        }
      });
      try {
        var done = false;
        final finding = service.discoverDevices().then((list) {
          done = true;
          return list;
        });
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(done, false);
        final devices = await finding;
        expect(devices.map((d) => d.deviceId).toSet(), {'first', 'second'});
        expect(devices, hasLength(2));
        expect(devices.every((d) => d.ip == '127.0.0.1'), true);
        expect(requests, hasLength(3));
        expect(requests.every((r) => r == 'BLANQUITA_DISCOVER_V2'), true);
      } finally {
        service.dispose();
        for (final t in timers) {
          t.cancel();
        }
        await sub.cancel();
        peer.close();
      }
    },
  );
  test(
    'UDP cancellation discards partial results and dispose settles pending bind',
    () async {
      final service = Esp32DiscoveryService();
      final first = service.discoverDevices();
      service.cancel();
      expect(await first, isEmpty);
      final second = service.discoverDevices();
      service.dispose();
      expect(await second, isEmpty);
      expect(await service.discoverDevices(), isEmpty);
    },
  );
}
