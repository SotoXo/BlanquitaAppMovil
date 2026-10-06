import 'dart:async';

import 'package:blanquita/core/models/machine_state.dart';

import 'dart:io';

import 'package:blanquita/core/diagnostics/connection_log.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';

import '../../features/vision/support/vision_test_channel.dart';

import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// These transport doubles exist only in tests; production always uses LAN/WS.
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
  final transport = Completer<void>();
  _Channel({bool open = true}) {
    if (open) transport.complete();
  }
  @override
  int? get closeCode => 1000;
  @override
  String? get closeReason => null;

  @override
  final _Sink sink = _Sink();

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  Future<void> get ready => transport.future;

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
  late MachineController machine;
  late ConnectionLog log;
  final channels = <_Channel>[];
  final urls = <Uri>[];

  Future<void> setup({
    String url = 'ws://192.168.43.27:81/',
    Duration timeout = const Duration(milliseconds: 80),
    WebSocketChannel Function(Uri)? factory,
  }) async {
    SharedPreferences.setMockInitialValues({
      'connection.websocket_url': url,
      'connection.auto_reconnect': false,
      'control.haptics': false,
      'vision.auto_reconnect': false,
      'vision.websocket_url': 'ws://laptop.test:8765/',
    });
    preferences = await SharedPreferences.getInstance();
    settings = SettingsController(SettingsRepository(preferences));
    await settings.load();
    log = ConnectionLog();
    machine = MachineController(
      settings,
      connectionLog: log,
      readyTimeout: timeout,
      transportTimeout: timeout,
      reconnectBaseDelay: const Duration(milliseconds: 20),
      channelFactory:
          factory ??
          (uri) {
            urls.add(uri);
            final channel = _Channel();
            channels.add(channel);
            return channel;
          },
    );
  }

  Future<_Channel> online() async {
    final connected = machine.connect();
    await _until(() => channels.isNotEmpty);
    final channel = channels.last;
    channel.incoming.add('READY');
    await connected;
    return channel;
  }

  tearDown(() async {
    machine.dispose();
    settings.dispose();
    for (final channel in channels) {
      await channel.incoming.close();
    }
    channels.clear();
    urls.clear();
    log.dispose();
  });

  for (final url in [
    '',
    'http://robot:81/',
    'ws://',
    'ws://robot:99999/',
    'ws://user:password@robot:81/',
    'ws://robot:81/#secret',
  ]) {
    test('rejects invalid endpoint $url without opening transport', () async {
      await setup(url: url);
      await machine.connect();
      expect(channels, isEmpty);
      expect(machine.lastErrorCode, 'INVALID_ENDPOINT');
      expect(machine.canStartMovement, false);
    });
  }

  test('open transport alone never enables physical commands', () async {
    await setup();
    final connected = machine.connect();
    await _until(() => machine.transportOpen);
    expect(machine.phase, 'waiting_ready');
    expect(machine.state.isConnected, false);
    expect(machine.startMovement(MovementDirection.xLeft), false);
    machine.openGripper();
    machine.startSequence();
    machine.stopNow();
    machine.emergencyStop();
    expect(channels.single.sink.commands, isEmpty);
    channels.single.incoming.add('SENSOR:ESTADO:P=1,F=0');
    await Future<void>.delayed(Duration.zero);
    expect(machine.state.isConnected, false);
    channels.single.incoming.add('READY');
    await connected;
    expect(machine.state.isConnected, true);
    expect(machine.phase, 'connected');
    expect(machine.state.plateDetected, true);
    expect(log.entries.any((e) => e.phase == 'websocket_open'), true);
    expect(log.entries.any((e) => e.phase == 'waiting_ready'), true);
  });

  test(
    'READY timeout preserves configured endpoint and explains protocol failure',
    () async {
      await setup();
      await machine.connect();
      expect(machine.lastErrorCode, 'READY_TIMEOUT');
      expect(machine.lastTechnicalError, contains('transport=open'));
      expect(machine.state.connection, ConnectionPhase.error);
      expect(settings.settings.websocketUrl, 'ws://192.168.43.27:81/');
      expect(channels.single.sink.commands, isEmpty);
    },
  );

  test('transport timeout is different from missing READY', () async {
    await setup(
      factory: (_) {
        final channel = _Channel(open: false);
        channels.add(channel);
        return channel;
      },
    );
    await machine.connect();
    expect(machine.lastErrorCode, 'CONNECT_TIMEOUT');
    expect(machine.transportOpen, false);
    expect(log.entries.any((e) => e.phase == 'waiting_ready'), false);
  });

  test(
    'early READY never bypasses pending transport and manual cancellation',
    () async {
      await setup(
        factory: (_) {
          final channel = _Channel(open: false);
          channels.add(channel);
          return channel;
        },
      );
      final pending = machine.connect();
      channels.single.incoming.add('READY');
      await Future<void>.delayed(Duration.zero);
      expect(machine.state.isConnected, false);
      await machine.disconnect();
      channels.single.transport.complete();
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(machine.state.isConnected, false);
    },
  );

  test('connection refused classifies original transport error', () async {
    await setup(
      factory: (_) => throw const SocketException(
        'Connection refused',
        osError: OSError('Connection refused', 111),
      ),
    );
    await machine.connect();
    expect(machine.lastErrorCode, 'CONNECTION_REFUSED');
    expect(machine.lastTechnicalError, contains('SocketException'));
    expect(machine.state.connectionError, isNot(contains('SocketException')));
  });

  test(
    'remote close stops movement, invalidates sensors and blocks control',
    () async {
      await setup();
      final channel = await online();
      machine.startMovement(MovementDirection.xLeft);
      await channel.incoming.close();
      expect(machine.lastErrorCode, 'REMOTE_CLOSED');
      expect(machine.state.activeMovement, isNull);
      expect(machine.canStartMovement, false);
      expect(machine.transportOpen, false);
    },
  );

  test(
    'manual disconnect cancels pending validation and ignores late READY',
    () async {
      await setup();
      final connecting = machine.connect();
      await _until(() => machine.transportOpen);
      await machine.disconnect();
      channels.single.incoming.add('READY');
      await connecting;
      await Future<void>.delayed(Duration.zero);
      expect(machine.state.connection, ConnectionPhase.disconnected);
      expect(machine.canStartMovement, false);
    },
  );

  test(
    'reconnect repeats saved endpoint and only succeeds with new READY',
    () async {
      await setup();
      final old = await online();
      machine.startMovement(MovementDirection.xLeft);
      final retry = machine.reconnect();
      await _until(() => channels.length == 2);
      expect(old.sink.commands, ['a', 'x']);
      old.incoming.add('READY');
      expect(machine.state.isConnected, false);
      channels.last.incoming.add('READY');
      await retry;
      expect(machine.state.isConnected, true);
      expect(
        urls.map((uri) => uri.toString()),
        everyElement(settings.settings.websocketUrl),
      );
    },
  );

  test(
    'URL changed persists and restarts control only; old session ignored',
    () async {
      await setup();
      final old = await online();
      await settings.setWebsocketUrl('ws://192.168.43.99:81/');
      await _until(() => channels.length == 2);
      old.incoming.add('READY');
      await Future<void>.delayed(Duration.zero);
      expect(machine.state.isConnected, false);
      expect(urls.last.host, '192.168.43.99');
      expect(
        SettingsRepository(preferences).load().websocketUrl,
        settings.settings.websocketUrl,
      );
      expect(settings.settings.visionWebsocketUrl, 'ws://laptop.test:8765/');
      channels.last.incoming.add('READY');
      await _until(() => machine.state.isConnected);
    },
  );

  test(
    'control endpoint edited in background connects on resume even with automatic retries off',
    () async {
      await setup();
      await online();
      machine.handleAppInactive();
      await settings.setWebsocketUrl('ws://192.168.43.99:81/');
      await Future<void>.delayed(Duration.zero);
      expect(channels.length, 1);
      machine.handleAppResumed();
      await _until(() => channels.length == 2);
      expect(urls.last.host, '192.168.43.99');
      channels.last.incoming.add('READY');
      await _until(() => machine.state.isConnected);
    },
  );

  test('automatic reconnect is cancelled by manual disconnect', () async {
    await setup();
    await settings.setAutoReconnect(true);
    final first = await online();
    first.incoming.addError(StateError('lost'));
    await _until(() => machine.reconnectAttempts == 1);
    await machine.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(channels.length, 1);
    expect(machine.reconnectAttempts, 0);
  });

  test('automatic reconnect validates same saved URL again', () async {
    await setup();
    await settings.setAutoReconnect(true);
    final first = await online();
    first.incoming.addError(StateError('lost'));
    await _until(() => channels.length == 2);
    expect(urls.last, urls.first);
    expect(machine.state.isConnected, false);
    channels.last.incoming.add('READY');
    await _until(() => machine.state.isConnected);
    expect(machine.reconnectAttempts, 0);
  });

  test(
    'probe sends no physical commands and reuses validated connection',
    () async {
      await setup();
      final probing = machine.testConnection();
      await _until(() => machine.transportOpen);
      expect(machine.startMovement(MovementDirection.zUp), false);
      channels.single.incoming.add('READY');
      expect(await probing, true);
      expect(await machine.testConnection(), true);
      expect(channels.length, 1);
      expect(channels.single.sink.commands, isEmpty);
    },
  );

  test(
    'movement heartbeat, lifecycle STOP, resume and final limit stay enforced',
    () async {
      await setup();
      final channel = await online();
      expect(machine.startMovement(MovementDirection.xLeft), true);
      await Future<void>.delayed(const Duration(milliseconds: 225));
      expect(channel.sink.commands, ['a', 'k']);
      machine.handleAppInactive();
      expect(channel.sink.commands.last, 'x');
      expect(machine.startMovement(MovementDirection.zUp), false);
      await Future<void>.delayed(const Duration(milliseconds: 225));
      expect(channel.sink.commands, ['a', 'k', 'x']);
      machine.handleAppResumed();
      expect(machine.startMovement(MovementDirection.zUp), true);
      channel.incoming.add('SENSOR:FINAL:1');
      await Future<void>.delayed(Duration.zero);
      expect(machine.state.activeMovement, isNull);
      expect(machine.canStartSequence, false);
      machine.emergencyStop();
      expect(channel.sink.commands.last, 'z');
    },
  );

  test('vision failure leaves manual control and STOP available', () async {
    await setup();
    await online();
    final vision = VisionController(
      settings,
      service: RemoteVisionService(
        channelFactory: (_) => throw StateError('vision lost'),
      ),
    );
    await vision.connect();
    expect(machine.state.isConnected, true);
    expect(machine.startMovement(MovementDirection.xRight), true);
    machine.stopNow();
    expect(channels.single.sink.commands.last, 'x');
    vision.dispose();
  });

  test('control failure leaves validated vision session available', () async {
    await setup();
    final control = await online();
    final visionChannel = TestVisionChannel();
    final vision = VisionController(
      settings,
      service: RemoteVisionService(channelFactory: (_) => visionChannel),
    );
    await vision.connect();
    visionChannel.receive('vision.ready', DateTime.now());
    await _until(() => vision.state.ready);
    control.incoming.addError(StateError('control lost'));
    await _until(() => !machine.state.isConnected);
    expect(vision.state.ready, true);
    expect(vision.transportOpen, true);
    vision.dispose();
    await visionChannel.incoming.close();
  });
}
