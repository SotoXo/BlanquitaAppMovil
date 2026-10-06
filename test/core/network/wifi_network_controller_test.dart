import 'dart:async';
import 'package:blanquita/core/diagnostics/connection_log.dart';
import 'package:blanquita/core/network/wifi_network_controller.dart';
import 'package:blanquita/core/network/wifi_network_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWifiService extends WifiNetworkService {
  FakeWifiService() : super(platformSupported: false);
  WifiNetworkStatus current = const WifiNetworkStatus(
    supported: true,
    wifiEnabled: true,
    connected: true,
    networkHandle: 'wifi-1',
    localIpv4: '192.168.43.40',
    rssiDbm: -55,
    linkSpeedMbps: 72,
    internetValidated: false,
    defaultRouteWifi: true,
  );
  final events = StreamController<WifiNetworkStatus>.broadcast(sync: true);
  Future<WifiNetworkStatus> Function()? reader;
  @override
  Future<WifiNetworkStatus> read() => reader?.call() ?? Future.value(current);
  Future<Map<Object?, Object?>> Function()? prober;
  @override
  Future<Map<Object?, Object?>> probeEndpointOnWifi(Uri endpoint) =>
      prober?.call() ??
      Future.value({
        'connected': false,
        'errorCode': 'HOST_UNREACHABLE',
        'technicalMessage': 'ConnectException: EHOSTUNREACH (No route to host)',
      });
  @override
  Stream<WifiNetworkStatus> watch() => events.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeWifiService service;
  late ConnectionLog log;
  late WifiNetworkController controller;
  late DateTime now;
  setUp(() {
    service = FakeWifiService();
    log = ConnectionLog();
    now = DateTime.utc(2026, 10, 6);
    controller = WifiNetworkController(
      service: service,
      connectionLog: log,
      now: () => now,
      sampleInterval: const Duration(days: 1),
    );
  });
  tearDown(() async {
    controller.dispose();
    await service.events.close();
    log.dispose();
  });

  test('connected Wi-Fi without Internet remains a real local link', () async {
    await controller.start();
    expect(controller.status.connected, true);
    expect(controller.status.internetValidated, false);
    expect(controller.status.localIpv4, '192.168.43.40');
    expect(controller.status.signalLabel, 'Fuerte');
    expect(controller.stabilityLabel, 'Observando enlace');
    now = now.add(const Duration(seconds: 12));
    await controller.refresh();
    expect(controller.stabilityLabel, 'Sin cortes observados durante 12 s');
    expect(controller.snapshot['Internet validado en Wi-Fi'], 'false');
    expect(
      log.entries.any((entry) => entry.channel == ConnectionChannel.network),
      true,
    );
  });

  test(
    'loss and changed association are counted, never guaranteed stable',
    () async {
      await controller.start();
      service.events.add(
        const WifiNetworkStatus(supported: true, wifiEnabled: true),
      );
      expect(controller.disconnects, 1);
      expect(controller.connectedSince, isNull);
      service.events.add(service.current);
      now = now.add(const Duration(seconds: 30));
      service.events.add(
        const WifiNetworkStatus(
          supported: true,
          wifiEnabled: true,
          connected: true,
          networkHandle: 'wifi-2',
        ),
      );
      expect(controller.linkChanges, 1);
      expect(controller.stabilityLabel, contains('1 cortes y 1 cambios'));
      expect(controller.observedConnectedDuration, Duration.zero);
    },
  );

  test(
    'pause is not a Wi-Fi cut; resuming resets the observation window',
    () async {
      await controller.start();
      now = now.add(const Duration(seconds: 30));
      await controller.pause();
      now = now.add(const Duration(minutes: 20));
      expect(controller.stabilityLabel, 'Observación pausada');
      await controller.start();
      expect(controller.disconnects, 0);
      expect(controller.observedConnectedDuration, Duration.zero);
      expect(controller.stabilityLabel, 'Observando enlace');
    },
  );

  test('a late refresh cannot overwrite a newer loss event', () async {
    await controller.start();
    final pending = Completer<WifiNetworkStatus>();
    service.reader = () => pending.future;
    final refreshing = controller.refresh();
    service.events.add(
      const WifiNetworkStatus(supported: true, wifiEnabled: false),
    );
    pending.complete(service.current);
    await refreshing;
    expect(controller.status.connected, false);
    expect(controller.disconnects, 1);
  });

  test(
    'late query after pause cannot resurrect a stale connected label',
    () async {
      final pending = Completer<WifiNetworkStatus>();
      service.reader = () => pending.future;
      final starting = controller.start();
      await controller.pause();
      pending.complete(service.current);
      await starting;
      expect(controller.lastUpdatedAt, isNull);
      expect(controller.stabilityLabel, 'Observación pausada');
    },
  );

  test(
    'permission or platform failure becomes an explicit diagnostic, not Wi-Fi off',
    () async {
      service.reader = () async =>
          throw PlatformException(code: 'NETWORK_OBSERVATION_FAILED');
      await controller.start();
      expect(controller.error, contains('No se pudo consultar'));
      expect(controller.status.supported, false);
      expect(log.entries.first.errorCode, 'NETWORK_OBSERVATION_FAILED');
    },
  );

  test(
    'targeted TCP failure preserves Wi-Fi evidence and original error',
    () async {
      await controller.start();
      final result = await controller.probeEndpoint(
        Uri.parse('ws://192.168.137.209:81/'),
        deviceLabel: 'ESP32',
      );
      expect(result['errorCode'], 'HOST_UNREACHABLE');
      expect(controller.status.connected, true);
      expect(controller.probing, false);
      expect(log.entries.first.technicalMessage, contains('EHOSTUNREACH'));
      expect(log.entries.first.humanMessage, contains('no puede alcanzar'));
      expect(
        log.entries.first.humanMessage,
        isNot(contains('ConnectException')),
      );
    },
  );

  test(
    'a paused probe cannot deliver a result into a resumed session',
    () async {
      await controller.start();
      final pending = Completer<Map<Object?, Object?>>();
      service.prober = () => pending.future;
      final probing = controller.probeEndpoint(
        Uri.parse('ws://192.168.137.209:81/'),
      );
      await controller.pause();
      await controller.start();
      pending.complete({'connected': true});
      expect((await probing)['errorCode'], 'PROBE_CANCELLED');
      expect(controller.probing, false);
    },
  );

  test(
    'a recovered snapshot restarts event observation after a read error',
    () async {
      service.reader = () async =>
          throw PlatformException(code: 'NETWORK_OBSERVATION_FAILED');
      await controller.start();
      service.reader = null;
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.status.connected, true);
      expect(service.events.hasListener, true);
    },
  );

  test(
    'unknown metrics and unsupported platforms never claim Wi-Fi connected',
    () async {
      service.current = const WifiNetworkStatus();
      await controller.start();
      expect(controller.status.supported, false);
      expect(controller.status.connected, false);
      expect(controller.status.signalLabel, 'No informada');
      final parsed = WifiNetworkStatus.fromMap({
        'supported': true,
        'wifiEnabled': true,
        'connected': true,
        'rssiDbm': -127,
        'linkSpeedMbps': -1,
      });
      expect(parsed.rssiDbm, isNull);
      expect(parsed.linkSpeedMbps, isNull);
      expect(parsed.internetValidated, isNull);
    },
  );
}
