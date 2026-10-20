import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/domain/vision_state.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/vision_test_channel.dart';
import 'support/vision_test_discovery.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 15));
Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition did not settle');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsController settings;
  late VisionController vision;
  late DateTime now;
  final channels = <TestVisionChannel>[];
  final urls = <Uri>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'vision.websocket_url': 'ws://laptop.test:8765/vision',
      'vision.auto_reconnect': true,
      'vision.heartbeat_timeout_ms': 6000,
      'control.haptics': false,
    });
    settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await settings.load();
    now = DateTime.utc(2026, 10, 6, 10, 30);
    vision = VisionController(
      settings,
      discoveryService: TestVisionDiscovery(),
      now: () => now,
      tickInterval: const Duration(milliseconds: 5),
      reconnectBaseDelay: const Duration(milliseconds: 40),
      service: RemoteVisionService(
        channelFactory: (uri) {
          urls.add(uri);
          final channel = TestVisionChannel();
          channels.add(channel);
          scheduleMicrotask(() => channel.establish(now));
          return channel;
        },
      ),
    );
  });

  tearDown(() async {
    await vision.disconnect();
    vision.dispose();
    settings.dispose();
    for (final channel in channels) {
      await channel.incoming.close();
    }
    channels.clear();
    urls.clear();
  });

  test('transport connected and protocol ready are distinct', () async {
    await vision.connect();
    expect(vision.state.isConnected, true);
    expect(vision.state.ready, true);
    expect(vision.state.position, isNull);
    channels.last.establish(now);
    expect(vision.state.ready, true);
    channels.last.receive('vision.status', now, {'ready': false});
    expect(vision.state.ready, false);
  });

  test('partial telemetry merges without invented values', () async {
    await vision.connect();
    channels.last.receive('vision.status', now, {
      'cameraName': 'USB',
      'cameraStatus': 'operative',
    });
    channels.last.receive('vision.status', now, {
      'fps': 30,
      'detectorStatus': 'active',
    });
    expect(vision.state.cameraName, 'USB');
    expect(vision.state.fps, 30);
    expect(vision.state.calibrationStatus, isNull);
    channels.last.receive('calibration.status', now, {'status': 'valid'});
    channels.last.receive('camera.status', now, {'status': 'disconnected'});
    expect(vision.state.calibrationStatus, 'valid');
    expect(vision.state.cameraStatus, 'disconnected');
  });

  test('report without position clears preceding coordinates', () async {
    await vision.connect();
    channels.last.receive('vision.report', now, {
      'detected': true,
      'position': {'x': 145.2, 'z': 78.4},
      'confidence': .96,
    });
    expect(vision.state.position!.x, 145.2);
    now = now.add(const Duration(milliseconds: 1));
    channels.last.receive('vision.report', now, {'detected': false});
    expect(vision.state.position, isNull);
    expect(vision.state.lastReport!.confidence, isNull);
  });

  test('invalid and unknown messages preserve report and heartbeat', () async {
    await vision.connect();
    channels.last.receive('vision.report', now, {'object': 'pieza'});
    final report = vision.state.lastReport;
    channels.last.incoming.add('{invalid');
    expect(vision.state.error, isNotNull);
    expect(vision.state.lastReport, same(report));
    channels.last.receive('motor.move', now, {'command': 'd'});
    expect(vision.state.lastHeartbeat, now);
    expect(vision.state.lastReport, same(report));
    expect(vision.diagnostics.any((item) => item.contains('ignorado')), true);
  });

  test(
    'heartbeat timeout is independent from report freshness and recovers',
    () async {
      await vision.connect();
      channels.last.establish(now);
      channels.last.receive('vision.heartbeat', now);
      channels.last.receive('vision.report', now, {'object': 'pieza'});
      now = now.add(const Duration(seconds: 7));
      await until(() => vision.state.stale);
      expect(vision.state.ready, false);
      expect(vision.state.stale, true);
      await until(() => channels.length == 2 && vision.state.isConnected);
      expect(vision.state.lastReport, isNull);
      channels.last.receive('vision.heartbeat', now);
      expect(vision.state.stale, false);
      expect(vision.state.ready, true);
      expect(vision.state.reportStale, false);
    },
  );

  test('reports cannot hide a missing heartbeat', () async {
    await vision.connect();
    now = now.add(const Duration(seconds: 7));
    channels.last.receive('vision.report', now, {'detected': true});
    await until(() => vision.state.stale);
    expect(vision.state.reportStale, true);
  });

  test(
    'out of order and duplicate reports do not overwrite newest position',
    () async {
      await vision.connect();
      channels.last.receive('vision.report', now, {
        'position': {'x': 9},
      });
      channels.last.receive(
        'vision.report',
        now.subtract(const Duration(seconds: 2)),
        {
          'position': {'x': 2},
        },
      );
      channels.last.receive('vision.report', now, {
        'position': {'x': 3},
      });
      expect(vision.state.position!.x, 9);
    },
  );

  test(
    'only vision commands are emitted and ping measures round trip',
    () async {
      await vision.connect();
      vision.start();
      vision.stop();
      vision.ping();
      final packets = channels.last.sink.sent
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .toList();
      expect(packets.map((item) => item['type']), [
        'vision.ping',
        'vision.start',
        'vision.stop',
        'vision.ping',
      ]);
      expect(packets.map((item) => item['messageId']).toSet().length, 4);
      for (final packet in packets) {
        expect(packet['protocol'], 'blanquita-vision');
        expect(packet['version'], 1);
        expect(packet['payload'], isEmpty);
      }
      now = now.add(const Duration(milliseconds: 24));
      channels.last.receive('vision.heartbeat', now, {
        'replyTo': packets.last['messageId'],
      });
      expect(vision.state.latency, 24);
    },
  );

  test('manual disconnect cancels reconnect and clears readiness', () async {
    await vision.connect();
    channels.last.establish(now);
    await vision.disconnect();
    expect(vision.state.connection, VisionConnection.disconnected);
    expect(vision.state.ready, false);
    expect(channels.last.sink.closed, true);
    vision.start();
    vision.stop();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(channels.length, 1);
    expect(channels.last.sink.sent.length, 1);
  });

  test(
    'remote disconnect retries and successful ready resets backoff',
    () async {
      await vision.connect();
      await channels.last.incoming.close();
      expect(vision.state.connection, VisionConnection.reconnecting);
      expect(
        vision.diagnostics.any((item) => item.contains('Reconexión en 40 ms')),
        true,
      );
      await until(() => channels.length == 2 && vision.state.isConnected);
      await channels.last.incoming.close();
      expect(vision.diagnostics.first.contains('Reconexión en 40 ms'), true);
      await until(() => channels.length == 3 && vision.state.isConnected);
      await channels.last.incoming.close();
      expect(vision.diagnostics.first.contains('Reconexión en 40 ms'), true);
      await until(() => channels.length == 4 && vision.state.isConnected);
      channels.last.establish(now);
      expect(vision.reconnectAttempts, 0);
    },
  );

  test('disabled reconnect and manual cancellation stop retries', () async {
    await vision.connect();
    await channels.last.incoming.close();
    await settings.setVisionAutoReconnect(false);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(channels.length, 1);
    expect(vision.state.connection, VisionConnection.disconnected);
    await settings.setVisionAutoReconnect(true);
    expect(vision.state.connection, VisionConnection.reconnecting);
    await vision.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(channels.length, 1);
  });

  test('endpoint change replaces session without reusing telemetry', () async {
    await vision.connect();
    channels.last.receive('vision.status', now, {'cameraName': 'Old USB'});
    await settings.setVisionWebsocketUrl('ws://other-laptop.test:8765/vision');
    await until(() => channels.length == 2 && vision.state.isConnected);
    expect(urls.last.host, 'other-laptop.test');
    expect(channels.first.sink.closed, true);
    expect(vision.state.cameraName, isNull);
    expect(vision.state.lastHeartbeat, now);
  });

  test('lifecycle closes cleanly and resumes only a desired link', () async {
    await vision.connect();
    vision.handleAppInactive();
    await settle();
    expect(vision.state.ready, false);
    expect(vision.networkPhase, VisionNetworkPhase.disconnected);
    expect(channels.first.sink.closed, true);
    vision.handleAppResumed();
    await until(() => channels.length == 2 && vision.state.isConnected);
    await vision.disconnect();
    vision.handleAppInactive();
    vision.handleAppResumed();
    await settle();
    expect(channels.length, 2);
  });

  test('hello then ready then a new heartbeat are all required', () async {
    vision.dispose();
    final channel = TestVisionChannel();
    channels.add(channel);
    vision = VisionController(
      settings,
      discoveryService: TestVisionDiscovery(),
      service: RemoteVisionService(channelFactory: (_) => channel),
    );
    final connecting = vision.connect();
    await until(() => vision.networkPhase == VisionNetworkPhase.waitingHello);
    channel.receive('vision.ready', now);
    expect(vision.state.isConnected, false);
    expect(vision.lastFailure!.category, 'Orden de protocolo inválido');
    channel.receive('vision.hello', now);
    channel.receive('vision.heartbeat', now);
    channel.receive('vision.ready', now);
    expect(vision.networkPhase, VisionNetworkPhase.waitingHeartbeat);
    expect(vision.state.isConnected, false);
    channel.receive('vision.heartbeat', now);
    await connecting;
    expect(vision.state.ready, true);
  });

  test('simultaneous connect calls open exactly one socket', () async {
    await Future.wait([vision.connect(), vision.connect(), vision.connect()]);
    expect(channels.length, 1);
    expect(vision.connectionAttempt, 1);
    expect(urls.single.toString(), 'ws://laptop.test:8765/vision');
    await vision.reconnect();
    expect(urls.length, 2);
    expect(urls.last.path, '/vision');
    expect(channels.first.sink.closed, true);
  });

  test('new attempt waits for cancellation of the old session', () async {
    vision.dispose();
    final closeGate = Completer<void>();
    final openingGate = Completer<void>();
    var opens = 0;
    vision = VisionController(
      settings,
      discoveryService: TestVisionDiscovery(),
      service: RemoteVisionService(
        channelFactory: (uri) {
          ++opens;
          final channel = opens == 1
              ? TestVisionChannel(
                  handshake: openingGate.future,
                  sink: TestVisionSink(closeDelay: closeGate.future),
                )
              : TestVisionChannel();
          channels.add(channel);
          if (opens > 1) scheduleMicrotask(() => channel.establish(now));
          return channel;
        },
      ),
    );
    final first = vision.connect();
    await until(() => opens == 1);
    final replacement = vision.saveEndpointAndReconnect('ws://new-host:8765/');
    await settle();
    expect(opens, 1);
    expect(channels.first.sink.closed, true);
    closeGate.complete();
    openingGate.complete();
    await Future.wait([first, replacement]);
    expect(opens, 2);
    expect(vision.connectionWebsocketUrl, 'ws://new-host:8765/vision');
  });

  test(
    'default heartbeat is fresh before 6s and stale exactly at 6s',
    () async {
      await settings.setVisionAutoReconnect(false);
      await vision.connect();
      now = now.add(const Duration(milliseconds: 5999));
      await settle();
      expect(vision.state.ready, true);
      now = now.add(const Duration(milliseconds: 1));
      await until(() => vision.state.stale);
      expect(vision.state.isConnected, false);
      expect(vision.lastFailure!.category, 'Heartbeat timeout posterior');
    },
  );

  test(
    'diagnostic mode preserves original HTTP failure and disables retry',
    () async {
      vision.dispose();
      vision = VisionController(
        settings,
        reconnectBaseDelay: const Duration(milliseconds: 5),
        discoveryService: TestVisionDiscovery(),
        service: RemoteVisionService(
          channelFactory: (_) =>
              throw WebSocketException('original handshake failure', 404),
        ),
      );
      vision.setDiagnosticMode(true);
      await vision.connect();
      await settle();
      expect(vision.connectionAttempt, 1);
      expect(vision.firstFailure!.type, 'WebSocketException');
      expect(vision.firstFailure!.httpStatus, 404);
      expect(vision.firstFailure!.uri, 'ws://laptop.test:8765/vision');
      expect(
        vision.firstFailure!.message,
        contains('original handshake failure'),
      );
      expect(vision.firstFailure!.stack.toString(), isNotEmpty);
      expect(vision.state.error, contains('original handshake failure'));
      expect(vision.state.connection, VisionConnection.disconnected);
      vision.handleAppInactive();
      vision.handleAppResumed();
      await settle();
      expect(vision.connectionAttempt, 1);
    },
  );

  test(
    'invalid or empty URL discovers without opening an invalid socket',
    () async {
      await settings.setVisionAutoReconnect(false);
      for (final url in [
        '',
        'http://laptop.test',
        'ws://',
        'ws://laptop.test/#fragment',
      ]) {
        if (url.isNotEmpty) {
          expect(
            () => settings.setVisionWebsocketUrl(url),
            throwsFormatException,
          );
          continue;
        }
        await settings.setVisionWebsocketUrl(url);
        await vision.connect();
        expect(vision.state.connection, VisionConnection.disconnected);
        expect(channels, isEmpty);
      }
    },
  );

  test('cancelled pending handshake cannot resurrect old session', () async {
    vision.dispose();
    final handshake = Completer<void>();
    final pending = TestVisionChannel(handshake: handshake.future);
    channels.add(pending);
    vision = VisionController(
      settings,
      discoveryService: TestVisionDiscovery(),
      service: RemoteVisionService(channelFactory: (_) => pending),
    );
    final connecting = vision.connect();
    await until(() => vision.connectionAttempt == 1);
    await vision.disconnect();
    handshake.complete();
    await connecting;
    expect(vision.state.isConnected, false);
    expect(pending.sink.closed, true);
  });

  test('handshake timeout fails safely with retry disabled', () async {
    vision.dispose();
    await settings.setVisionAutoReconnect(false);
    final handshake = Completer<void>();
    final pending = TestVisionChannel(handshake: handshake.future);
    channels.add(pending);
    vision = VisionController(
      settings,
      discoveryService: TestVisionDiscovery(),
      connectionTimeout: const Duration(milliseconds: 20),
      service: RemoteVisionService(channelFactory: (_) => pending),
    );
    await vision.connect();
    expect(vision.state.connection, VisionConnection.disconnected);
    expect(vision.state.error, contains('Timeout TCP/upgrade'));
    expect(pending.sink.closed, true);
    handshake.complete();
  });

  test('Vision and Machine remain independent in both directions', () async {
    await settings.setEsp32LaboratoryMode(true);
    await settings.setWebsocketUrl('ws://esp32.test:81/');
    final machineSocket = TestVisionChannel();
    final machine = MachineController(
      settings,
      channelFactory: (_) => machineSocket,
    );
    addTearDown(() async {
      machine.dispose();
      await machineSocket.incoming.close();
    });
    final connectingMachine = machine.connect();
    await until(() => machine.state.connection == ConnectionPhase.connecting);
    await settle();
    machineSocket.incoming.add('READY');
    for (final name in ['X_IZQ', 'X_DER', 'Z_ARRIBA', 'Z_ABAJO']) {
      machineSocket.incoming.add('SENSOR:FC:$name:0');
    }
    await connectingMachine;
    expect(machine.state.isConnected, true);
    expect(vision.state.isConnected, false);
    expect(machine.startMovement(MovementDirection.xRight), true);
    await vision.connect();
    channels.last.receive('vision.report', now, {
      'position': {'x': 145, 'z': 78},
    });
    vision.start();
    expect(machine.state.activeMovement, MovementDirection.xRight);
    now = now.add(const Duration(seconds: 7));
    await until(() => vision.state.stale);
    await until(() => machineSocket.sink.sent.contains('k'));
    expect(machine.state.activeMovement, MovementDirection.xRight);
    await vision.disconnect();
    expect(machine.state.activeMovement, MovementDirection.xRight);
    expect(machineSocket.sink.sent.where((item) => item == 'x'), isEmpty);
    await vision.connect();
    await machine.disconnect();
    expect(vision.state.isConnected, true);
    expect(machine.state.isConnected, false);
    expect(machineSocket.sink.sent.any((item) => item.startsWith('{')), false);
    expect(channels.last.sink.sent.every((item) => item.startsWith('{')), true);
  });
}
