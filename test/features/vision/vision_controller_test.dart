import 'dart:async';
import 'dart:convert';

import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/diagnostics/connection_log.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/domain/vision_state.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/vision_test_channel.dart';

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
  late ConnectionLog connectionLog;
  final channels = <TestVisionChannel>[];
  final urls = <Uri>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'vision.websocket_url': 'ws://laptop.test:8765/',
      'vision.auto_reconnect': true,
      'vision.heartbeat_timeout_ms': 2000,
      'control.haptics': false,
    });
    settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await settings.load();
    now = DateTime.utc(2026, 10, 6, 10, 30);
    connectionLog = ConnectionLog();
    vision = VisionController(
      settings,
      connectionLog: connectionLog,
      now: () => now,
      tickInterval: const Duration(milliseconds: 5),
      reconnectBaseDelay: const Duration(milliseconds: 40),
      service: RemoteVisionService(
        channelFactory: (uri) {
          urls.add(uri);
          final channel = TestVisionChannel();
          channels.add(channel);
          return channel;
        },
      ),
    );
  });

  tearDown(() async {
    await vision.disconnect();
    vision.dispose();
    settings.dispose();
    connectionLog.dispose();
    for (final channel in channels) {
      await channel.incoming.close();
    }
    channels.clear();
    urls.clear();
  });

  test('transport connected and protocol ready are distinct', () async {
    await vision.connect();
    expect(vision.state.isConnected, true);
    expect(vision.state.ready, false);
    expect(vision.transportOpen, true);
    expect(vision.phase, 'waiting_ready');
    expect(vision.state.position, isNull);
    channels.last.receive('vision.status', now, {'ready': true});
    channels.last.receive('vision.heartbeat', now, {'ready': true});
    expect(vision.state.ready, false);
    expect(vision.phase, 'waiting_ready');
    channels.last.receive('vision.ready', now);
    expect(vision.state.ready, true);
    expect(vision.phase, 'connected');
    channels.last.receive('vision.status', now, {'ready': false});
    expect(vision.state.ready, false);
  });

  test(
    'heartbeat expiration starts after protocol READY, not while waiting for handshake',
    () async {
      await vision.connect();
      now = now.add(const Duration(seconds: 3));
      await settle();
      expect(vision.lastErrorCode, isNot('HEARTBEAT_TIMEOUT'));
      expect(vision.phase, 'waiting_ready');
      channels.last.receive('vision.ready', now);
      now = now.add(const Duration(seconds: 1));
      await settle();
      expect(vision.state.stale, false);
      now = now.add(const Duration(seconds: 2));
      await settle();
      expect(vision.state.stale, true);
      expect(vision.lastErrorCode, 'HEARTBEAT_TIMEOUT');
    },
  );

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
    expect(vision.state.lastHeartbeat, isNull);
    expect(vision.state.lastReport, same(report));
    expect(vision.diagnostics.any((item) => item.contains('ignorado')), true);
  });

  test(
    'heartbeat timeout is independent from report freshness and recovers',
    () async {
      await vision.connect();
      channels.last.receive('vision.ready', now);
      channels.last.receive('vision.heartbeat', now);
      channels.last.receive('vision.report', now, {'object': 'pieza'});
      now = now.add(const Duration(seconds: 3));
      await until(() => vision.state.stale);
      expect(vision.state.ready, false);
      expect(vision.state.reportStale, true);
      expect(vision.state.reportAge, const Duration(seconds: 3));
      channels.last.receive('vision.heartbeat', now);
      expect(vision.state.stale, false);
      expect(vision.state.ready, true);
      expect(vision.state.reportStale, true);
    },
  );

  test('reports cannot hide a missing heartbeat', () async {
    await vision.connect();
    channels.last.receive('vision.ready', now);
    now = now.add(const Duration(seconds: 3));
    channels.last.receive('vision.report', now, {'detected': true});
    await until(() => vision.state.stale);
    expect(vision.state.reportStale, false);
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
    channels.last.receive('vision.ready', now);
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
    'remote disconnect retries with increasing backoff and resets on ready',
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
      expect(
        vision.diagnostics.any((item) => item.contains('Reconexión en 80 ms')),
        true,
      );
      await until(() => channels.length == 3 && vision.state.isConnected);
      await channels.last.incoming.close();
      expect(
        vision.diagnostics.any((item) => item.contains('Reconexión en 160 ms')),
        true,
      );
      await until(() => channels.length == 4 && vision.state.isConnected);
      channels.last.receive('vision.ready', now);
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
    await settings.setVisionWebsocketUrl('ws://other-laptop.test:8765/');
    await until(() => channels.length == 2 && vision.state.isConnected);
    expect(urls.last.host, 'other-laptop.test');
    expect(channels.first.sink.closed, true);
    expect(vision.state.cameraName, isNull);
    expect(vision.state.lastHeartbeat, isNull);
  });

  test('lifecycle closes cleanly and resumes only a desired link', () async {
    await vision.connect();
    vision.handleAppInactive();
    await settle();
    expect(vision.state.ready, false);
    expect(channels.first.sink.closed, true);
    vision.handleAppResumed();
    await until(() => channels.length == 2 && vision.state.isConnected);
    await vision.disconnect();
    vision.handleAppInactive();
    vision.handleAppResumed();
    await settle();
    expect(channels.length, 2);
  });

  test('invalid or empty URL never creates a socket', () async {
    for (final url in [
      '',
      'http://laptop.test',
      'ws://',
      'ws://laptop.test/#fragment',
    ]) {
      await settings.setVisionWebsocketUrl(url);
      await vision.connect();
      expect(vision.state.connection, VisionConnection.error);
      expect(channels, isEmpty);
    }
  });

  test('cancelled pending handshake cannot resurrect old session', () async {
    vision.dispose();
    final handshake = Completer<void>();
    final pending = TestVisionChannel(handshake: handshake.future);
    channels.add(pending);
    vision = VisionController(
      settings,
      service: RemoteVisionService(channelFactory: (_) => pending),
    );
    final connecting = vision.connect();
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
      connectionTimeout: const Duration(milliseconds: 20),
      service: RemoteVisionService(channelFactory: (_) => pending),
    );
    await vision.connect();
    expect(vision.state.connection, VisionConnection.disconnected);
    expect(vision.state.error, contains('No fue posible establecer'));
    expect(vision.lastErrorCode, 'CONNECT_TIMEOUT');
    expect(vision.lastTechnicalError, contains('TimeoutException'));
    expect(pending.sink.closed, true);
    handshake.complete();
  });

  test(
    'open transport without vision.ready times out as protocol failure',
    () async {
      vision.dispose();
      await settings.setVisionAutoReconnect(false);
      vision = VisionController(
        settings,
        connectionLog: connectionLog,
        readyTimeout: const Duration(milliseconds: 30),
        service: RemoteVisionService(
          channelFactory: (_) {
            final channel = TestVisionChannel();
            channels.add(channel);
            return channel;
          },
        ),
      );
      final testing = vision.testConnection();
      await until(() => vision.transportOpen);
      channels.last.receive('vision.status', now, {'ready': true});
      channels.last.receive('vision.heartbeat', now, {'ready': true});
      expect(await testing, false);
      expect(vision.lastErrorCode, 'READY_TIMEOUT');
      expect(vision.transportOpen, false);
      expect(vision.lastTechnicalError, contains('transport=open'));
      expect(
        connectionLog.entries
            .firstWhere((entry) => entry.errorCode == 'READY_TIMEOUT')
            .phase,
        'waiting_ready',
      );
      await until(() => channels.last.sink.closed);
      expect(channels.last.sink.closed, true);
      expect(
        connectionLog.entries.any(
          (entry) => entry.errorCode == 'READY_TIMEOUT',
        ),
        true,
      );
    },
  );

  test(
    'testConnection succeeds only after protocol ready without movement',
    () async {
      final testing = vision.testConnection();
      await until(() => vision.transportOpen);
      channels.last.receive('vision.ready', now);
      expect(await testing, true);
      expect(
        channels.last.sink.sent.every(
          (packet) => jsonDecode(packet)['type'] == 'vision.ping',
        ),
        true,
      );
    },
  );

  test(
    'testConnection can be manually cancelled during pending handshake',
    () async {
      vision.dispose();
      final handshake = Completer<void>();
      final pending = TestVisionChannel(handshake: handshake.future);
      channels.add(pending);
      vision = VisionController(
        settings,
        service: RemoteVisionService(channelFactory: (_) => pending),
      );
      final testing = vision.testConnection();
      await vision.disconnect();
      expect(await testing.timeout(const Duration(milliseconds: 100)), false);
      handshake.complete();
      await settle();
      expect(vision.transportOpen, false);
    },
  );

  test('invalid endpoint test is false and opens no socket', () async {
    await settings.setVisionWebsocketUrl('ws://laptop:70000/');
    expect(await vision.testConnection(), false);
    expect(vision.lastErrorCode, 'INVALID_ENDPOINT');
    expect(channels, isEmpty);
  });

  test('new endpoint starts a session after manual disconnect', () async {
    await vision.disconnect();
    await settings.setVisionAutoReconnect(false);
    await settings.setVisionWebsocketUrl('ws://new-laptop.test:8765/');
    await until(() => vision.transportOpen);
    expect(urls.last.host, 'new-laptop.test');
    expect(vision.state.ready, false);
    await settings.setVisionWebsocketUrl('');
    await settle();
    expect(vision.transportOpen, false);
    expect(channels.length, 1);
  });

  test('endpoint change in background opens only after resume', () async {
    await settings.setVisionAutoReconnect(false);
    vision.handleAppInactive();
    await settings.setVisionWebsocketUrl('ws://new-laptop.test:8765/');
    await settle();
    expect(channels, isEmpty);
    vision.handleAppResumed();
    await until(() => vision.transportOpen);
    expect(urls.last.host, 'new-laptop.test');
  });

  test('closure failures are warnings and cannot prevent cleanup', () async {
    await vision.connect();
    channels.last.incoming.onCancel = () => throw StateError('cancel failed');
    channels.last.sink.closeError = StateError('socket close failed');
    await vision.disconnect();
    expect(vision.transportOpen, false);
    expect(channels.last.sink.closed, true);
    final warnings = connectionLog.entries.where(
      (entry) => entry.level == ConnectionLogLevel.warning,
    );
    expect(
      warnings.map((entry) => entry.errorCode),
      containsAll(['SUBSCRIPTION_CLOSE_FAILED', 'SOCKET_CLOSE_FAILED']),
    );
    expect(
      warnings.every((entry) => entry.technicalMessage.contains('StateError')),
      true,
    );
  });

  test(
    'heartbeat report and ping logging is sampled without losing state',
    () async {
      await vision.connect();
      channels.last.receive('vision.ready', now);
      for (var index = 0; index < 20; index++) {
        now = now.add(const Duration(milliseconds: 1));
        channels.last.receive('vision.heartbeat', now);
        channels.last.receive('vision.report', now, {
          'position': {'x': index},
        });
        vision.ping();
      }
      expect(vision.state.position!.x, 19);
      for (final event in [
        'RX vision.heartbeat',
        'RX vision.report',
        'TX vision.ping',
      ]) {
        expect(
          connectionLog.entries
              .where((entry) => entry.humanMessage == event)
              .length,
          1,
        );
      }
      now = now.add(const Duration(seconds: 11));
      channels.last.receive('vision.heartbeat', now);
      channels.last.receive('vision.report', now, {
        'position': {'x': 21},
      });
      vision.ping();
      for (final event in [
        'RX vision.heartbeat',
        'RX vision.report',
        'TX vision.ping',
      ]) {
        expect(
          connectionLog.entries
              .where((entry) => entry.humanMessage == event)
              .length,
          2,
        );
      }
    },
  );

  test(
    'READY received before handshake cannot skip transport validation',
    () async {
      vision.dispose();
      final handshake = Completer<void>();
      final pending = TestVisionChannel(handshake: handshake.future);
      channels.add(pending);
      vision = VisionController(
        settings,
        service: RemoteVisionService(channelFactory: (_) => pending),
      );
      final testing = vision.testConnection();
      pending.receive('vision.ready', now);
      expect(vision.state.ready, false);
      expect(vision.transportOpen, false);
      handshake.complete();
      expect(await testing, true);
      expect(vision.transportOpen, true);
    },
  );

  test(
    'background cancels a pending protocol test without reconnecting early',
    () async {
      final testing = vision.testConnection();
      await until(() => vision.transportOpen);
      vision.handleAppInactive();
      expect(await testing, false);
      expect(vision.phase, 'background');
      expect(vision.transportOpen, false);
      await settle();
      expect(channels.length, 1);
      vision.handleAppResumed();
      await until(() => channels.length == 2 && vision.transportOpen);
      expect(vision.state.ready, false);
    },
  );

  test(
    'transport failures remain isolated between vision and control',
    () async {
      await settings.setWebsocketUrl('ws://esp32.test:81/');
      await settings.setVisionAutoReconnect(false);
      final machineSocket = TestVisionChannel();
      final machine = MachineController(
        settings,
        channelFactory: (_) => machineSocket,
      );
      addTearDown(() async {
        machine.dispose();
        await machineSocket.incoming.close();
      });
      final machineConnecting = machine.connect();
      await until(() => machine.transportOpen);
      machineSocket.incoming.add('READY');
      await machineConnecting;
      await vision.connect();
      channels.last.receive('vision.ready', now);
      channels.last.incoming.addError(
        StateError('vision transport disconnected'),
      );
      expect(vision.transportOpen, false);
      expect(vision.lastErrorCode, 'TRANSPORT_ERROR');
      expect(machine.state.isConnected, true);
      await vision.disconnect();
      await vision.connect();
      channels.last.receive('vision.ready', now);
      machineSocket.incoming.addError(
        StateError('control transport disconnected'),
      );
      expect(machine.state.isConnected, false);
      expect(vision.transportOpen, true);
      expect(vision.state.ready, true);
    },
  );

  test(
    'heartbeat before vision.ready cannot reset reconnection backoff',
    () async {
      await vision.connect();
      await channels.last.incoming.close();
      await until(() => channels.length == 2 && vision.transportOpen);
      channels.last.receive('vision.heartbeat', now, {'ready': true});
      expect(vision.reconnectAttempts, 1);
      expect(vision.state.ready, false);
      channels.last.receive('vision.ready', now);
      expect(vision.reconnectAttempts, 0);
    },
  );

  test('Vision and Machine remain independent in both directions', () async {
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
    await connectingMachine;
    expect(machine.state.isConnected, true);
    expect(vision.state.isConnected, false);
    expect(machine.startMovement(MovementDirection.xRight), true);
    await vision.connect();
    channels.last.receive('vision.ready', now);
    channels.last.receive('vision.report', now, {
      'position': {'x': 145, 'z': 78},
    });
    vision.start();
    expect(machine.state.activeMovement, MovementDirection.xRight);
    now = now.add(const Duration(seconds: 3));
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
