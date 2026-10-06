import 'dart:async';

import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/network/esp32_discovery_service.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// These transport doubles exist only in tests; production always uses LAN/WS.
class _Discovery extends Esp32DiscoveryService {
  _Discovery(this.result);
  final Future<Uri?> Function() result;
  int calls = 0;
  int cancellations = 0;

  @override
  Future<Uri?> discover() {
    calls++;
    return result();
  }

  @override
  void cancel() => cancellations++;

  @override
  void dispose() => cancel();
}

class _Sink implements WebSocketSink {
  final commands = <dynamic>[];
  final _done = Completer<void>();

  @override
  void add(dynamic data) => commands.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;

  @override
  void addError(Object error, [StackTrace? stackTrace]) => throw error;

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }
}

class _Channel implements WebSocketChannel {
  final incoming = StreamController<dynamic>();

  @override
  final _Sink sink = _Sink();

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late SettingsController settings;
  late _Discovery discovery;
  late MachineController machine;
  final channels = <_Channel>[];
  final urls = <Uri>[];

  Future<void> setup({String? knownUrl, Uri? found, Duration? timeout}) async {
    SharedPreferences.setMockInitialValues({
      'connection.websocket_url': ?knownUrl,
      'connection.auto_reconnect': false,
      'control.haptics': false,
    });
    preferences = await SharedPreferences.getInstance();
    settings = SettingsController(SettingsRepository(preferences));
    await settings.load();
    discovery = _Discovery(() async => found);
    machine = MachineController(
      settings,
      discoveryService: discovery,
      readyTimeout: timeout ?? const Duration(seconds: 1),
      channelFactory: (uri) {
        urls.add(uri);
        final channel = _Channel();
        channels.add(channel);
        return channel;
      },
    );
  }

  tearDown(() async {
    machine.dispose();
    settings.dispose();
    for (final channel in channels) {
      await channel.incoming.close();
    }
    channels.clear();
    urls.clear();
  });

  test('DHCP has no fixed default; existing saved URL is retained', () async {
    await setup();
    expect(settings.settings.websocketUrl, isEmpty);
    expect(machine.deviceAddress, isNull);
    await settings.setWebsocketUrl('ws://192.168.4.1:81/');
    expect(
      SettingsRepository(preferences).load().websocketUrl,
      'ws://192.168.4.1:81/',
    );
    expect(MachineController.wifiName, 'CARTESIANO');
  });

  test(
    'known URL needs READY and sends no commands before validation',
    () async {
      await setup(knownUrl: 'ws://192.168.43.27:81/');
      final connection = machine.connect();
      final channel = channels.single;
      await Future<void>.delayed(Duration.zero);
      expect(machine.state.isConnected, isFalse);
      expect(machine.startMovement(MovementDirection.xLeft), isFalse);
      machine.openGripper();
      machine.startSequence();
      machine.stopNow();
      machine.emergencyStop();
      expect(channel.sink.commands, isEmpty);
      channel.incoming.add('READY');
      await connection;
      expect(machine.state.isConnected, isTrue);
      expect(discovery.calls, 0);
      expect(machine.deviceAddress, '192.168.43.27');
    },
  );

  test('failed known IP discovers and persists only after READY', () async {
    const known = 'ws://192.168.43.10:81/';
    final found = Uri.parse('ws://192.168.43.27:81/');
    await setup(knownUrl: known, found: found);
    final connection = machine.connect();
    channels.first.incoming.addError(StateError('connection lost'));
    await _until(() => channels.length == 2);
    expect(urls.map((uri) => uri.toString()), [known, found.toString()]);
    expect(discovery.calls, 1);
    expect(settings.settings.websocketUrl, known);
    expect(channels.last.sink.commands, isEmpty);
    channels.last.incoming.add('SENSOR:ESTADO:P=1,F=0');
    await Future<void>.delayed(Duration.zero);
    expect(machine.state.isConnected, isFalse);
    channels.last.incoming.add('READY');
    await connection;
    expect(settings.settings.websocketUrl, found.toString());
    expect(
      SettingsRepository(preferences).load().websocketUrl,
      found.toString(),
    );
    expect(machine.state.plateDetected, isTrue);
    expect(machine.state.finalLimitActive, isFalse);
  });

  test(
    'candidate without READY is rejected; manual URL remains usable',
    () async {
      final found = Uri.parse('ws://192.168.43.27:81/');
      await setup(found: found, timeout: const Duration(milliseconds: 20));
      await machine.connect();
      expect(machine.state.isConnected, isFalse);
      expect(machine.connectionStatusLabel, 'No encontrado');
      expect(settings.settings.websocketUrl, isEmpty);
      expect(channels.single.sink.commands, isEmpty);

      await settings.setWebsocketUrl('ws://192.168.43.99:81/');
      final retry = machine.reconnect();
      await _until(() => channels.length == 2);
      channels.last.incoming.add('READY');
      await retry;
      expect(machine.state.isConnected, isTrue);
      expect(urls.last.host, '192.168.43.99');
      expect(discovery.calls, 1);
    },
  );

  test('disconnect cancels discovery and ignores a late candidate', () async {
    await setup();
    final reply = Completer<Uri?>();
    discovery = _Discovery(() => reply.future);
    machine.dispose();
    machine = MachineController(
      settings,
      discoveryService: discovery,
      channelFactory: (uri) => throw StateError('must not connect'),
    );
    final connection = machine.connect();
    expect(machine.isDiscovering, isTrue);
    await machine.disconnect();
    reply.complete(Uri.parse('ws://192.168.43.27:81/'));
    await connection;
    expect(machine.state.connection, ConnectionPhase.disconnected);
    expect(machine.isDiscovering, isFalse);
    expect(settings.settings.websocketUrl, isEmpty);
    expect(discovery.cancellations, greaterThan(0));
  });

  test(
    'explicit search stops movement and starts with UDP instead of old URL',
    () async {
      await setup(
        knownUrl: 'ws://192.168.43.10:81/',
        found: Uri.parse('ws://192.168.43.27:81/'),
      );
      final connection = machine.connect();
      final oldChannel = channels.single;
      oldChannel.incoming.add('READY');
      await connection;
      machine.startMovement(MovementDirection.xLeft);
      final search = machine.searchEsp32();
      await _until(() => channels.length == 2);
      expect(oldChannel.sink.commands, ['a', 'x']);
      expect(discovery.calls, 1);
      expect(urls.last.host, '192.168.43.27');
      expect(machine.state.isConnected, isFalse);
      expect(channels.last.sink.commands, isEmpty);
      channels.last.incoming.add('READY');
      await search;
      expect(machine.state.isConnected, isTrue);
    },
  );

  test(
    'disconnect overrides a pending explicit search before it starts',
    () async {
      await setup(found: Uri.parse('ws://192.168.43.27:81/'));
      final search = machine.searchEsp32();
      await machine.disconnect();
      await search;
      expect(discovery.calls, 0);
      expect(channels, isEmpty);
      expect(machine.state.connection, ConnectionPhase.disconnected);
    },
  );

  test(
    'automatic reconnect retries known IP then discovers changed DHCP IP',
    () async {
      await setup(
        knownUrl: 'ws://192.168.43.10:81/',
        found: Uri.parse('ws://192.168.43.27:81/'),
      );
      await settings.setAutoReconnect(true);
      final firstConnection = machine.connect();
      channels.single.incoming.add('READY');
      await firstConnection;
      channels.first.incoming.addError(StateError('ESP32 restarted'));
      await _until(() => channels.length == 2);
      expect(urls[1].host, '192.168.43.10');
      channels[1].incoming.addError(StateError('old IP unavailable'));
      await _until(() => channels.length == 3);
      channels.last.incoming.add('READY');
      await _until(
        () =>
            preferences.getString('connection.websocket_url') ==
            'ws://192.168.43.27:81/',
      );
      expect(machine.state.isConnected, isTrue);
      expect(discovery.calls, 1);
    },
  );

  test(
    'movement heartbeat, lifecycle STOP and final limit stay enforced',
    () async {
      await setup(knownUrl: 'ws://192.168.43.27:81/');
      final connection = machine.connect();
      final channel = channels.single;
      channel.incoming.add('READY');
      await connection;
      expect(machine.startMovement(MovementDirection.xLeft), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 225));
      expect(channel.sink.commands, ['a', 'k']);
      expect(
        MachineController.heartbeatInterval,
        const Duration(milliseconds: 200),
      );
      machine.handleAppInactive();
      expect(channel.sink.commands.last, 'x');
      await Future<void>.delayed(const Duration(milliseconds: 225));
      expect(channel.sink.commands, ['a', 'k', 'x']);
      expect(machine.startMovement(MovementDirection.zUp), isFalse);
      await settings.setAutoReconnect(true);
      machine.handleAppResumed();
      await _until(() => channels.length == 2);
      final resumedChannel = channels.last;
      resumedChannel.incoming.add('READY');
      await _until(() => machine.state.isConnected);
      expect(machine.startMovement(MovementDirection.zUp), isTrue);
      resumedChannel.incoming.add('SENSOR:FINAL:1');
      await Future<void>.delayed(Duration.zero);
      expect(machine.state.activeMovement, isNull);
      expect(machine.startMovement(MovementDirection.xRight), isFalse);
      expect(machine.canStartSequence, isFalse);
      machine.emergencyStop();
      expect(resumedChannel.sink.commands.last, 'z');
    },
  );
}
