import 'dart:async';
import 'dart:convert';
import 'package:blanquita/core/models/esp32_device.dart';
import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/network/esp32_discovery_service.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/vision/support/vision_test_channel.dart';
import '../../support/esp32_test_peer.dart';

Esp32Device device(String ip, [String id = testDeviceId]) => Esp32Device(
  deviceId: id,
  name: 'BLANQUITA',
  deviceType: Esp32Device.cartesianType,
  ip: ip,
);

class _Discovery extends Esp32DiscoveryService {
  Future<List<Esp32Device>> Function() result = () async => [];
  int calls = 0;
  @override
  Future<List<Esp32Device>> discoverDevices() {
    calls++;
    return result();
  }

  @override
  void cancel() {}
  @override
  void dispose() {}
}

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

class Harness {
  late SettingsController settings;
  late SharedPreferences preferences;
  late MachineController machine;
  final credentials = MemoryCredentials();
  final discovery = _Discovery();
  final channels = <TestVisionChannel>[];
  final urls = <Uri>[];
  final failedHosts = <String>{};
  Esp32TestPeer Function() peer = () => Esp32TestPeer();
  Future<void> setup({
    String url = 'ws://10.2.3.44:81/',
    bool lab = true,
    bool v2 = false,
    bool bound = true,
    Duration? timeout,
  }) async {
    SharedPreferences.setMockInitialValues({
      'connection.websocket_url': url,
      'esp32.laboratory_mode': lab,
      'connection.auto_reconnect': false,
      'control.haptics': false,
      if (v2) 'esp32.selected_device': jsonEncode(device('10.2.3.44').toJson()),
    });
    preferences = await SharedPreferences.getInstance();
    settings = SettingsController(SettingsRepository(preferences));
    await settings.load();
    if (v2 && bound) credentials.values[testDeviceId] = testSecret;
    machine = MachineController(
      settings,
      discoveryService: discovery,
      credentialStore: credentials,
      readyTimeout: timeout ?? const Duration(milliseconds: 200),
      channelFactory: (uri) {
        urls.add(uri);
        final channel = v2 ? peer() : TestVisionChannel();
        channels.add(channel);
        if (failedHosts.contains(uri.host)) {
          scheduleMicrotask(
            () => channel.incoming.addError(StateError('old IP')),
          );
        }
        return channel;
      },
    );
    addTearDown(() async {
      machine.dispose();
      settings.dispose();
      for (final channel in channels) {
        await channel.incoming.close();
      }
    });
  }

  Future<void> connectLegacy() async {
    final connecting = machine.connect();
    await until(() => channels.isNotEmpty);
    channels.last.incoming.add('READY');
    await connecting;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('manual disconnect cancels pairing before a socket can open', () async {
    final h = Harness();
    await h.setup(v2: true, bound: false);
    final pairing = h.machine.pairSelected(testSecret);
    await h.machine.disconnect();
    expect(await pairing, false);
    expect(h.channels, isEmpty);
    expect(h.credentials.values, isEmpty);
  });
  test(
    'pairing blocks movement until secure persistence and cancellation removes pending key',
    () async {
      final h = Harness();
      await h.setup(v2: true, bound: false);
      h.credentials.writeBarrier = Completer<void>();
      final pairing = h.machine.pairSelected(testSecret);
      await until(() => h.machine.isAuthorized);
      expect(h.machine.canStartMovement, false);
      expect(h.machine.startMovement(MovementDirection.xLeft), false);
      await h.machine.disconnect();
      h.credentials.writeBarrier!.complete();
      expect(await pairing, false);
      expect(h.credentials.values, isEmpty);
      expect(h.machine.hasValidConnection, false);
    },
  );
  test('laboratory is off initially; saved URL cannot authorize', () async {
    final h = Harness();
    await h.setup(lab: false);
    await h.machine.connect();
    expect(h.channels, isEmpty);
    expect(h.machine.canStartMovement, false);
  });
  test(
    'manual old firmware requires READY and stays unauthenticated without UDP',
    () async {
      final h = Harness();
      await h.setup(url: 'ws://172.20.10.7:81/');
      final connecting = h.machine.connect();
      expect(h.machine.startMovement(MovementDirection.xLeft), false);
      h.machine.openGripper();
      h.machine.closeGripper();
      h.machine.startSequence();
      h.machine.stopNow();
      h.machine.emergencyStop();
      h.machine.requestFaster();
      expect(h.channels.single.sink.sent, isEmpty);
      h.channels.single.incoming.add('ACK');
      expect(h.machine.state.isConnected, false);
      h.channels.single.incoming.add('READY');
      await connecting;
      expect(h.machine.hasValidConnection, true);
      expect(h.machine.isAuthorized, false);
      expect(h.machine.authenticationLabel, contains('sin autenticación'));
      expect(h.discovery.calls, 0);
      expect(h.machine.deviceAddress, '172.20.10.7');
    },
  );
  test(
    'same-IP auto reconnect needs fresh READY and never resumes movement',
    () async {
      final h = Harness();
      await h.setup();
      await h.settings.setAutoReconnect(true);
      await h.connectLegacy();
      h.machine.startMovement(MovementDirection.xLeft);
      h.channels.first.incoming.addError(StateError('lost'));
      expect(h.channels.first.sink.sent, ['a', 'x']);
      expect(h.machine.state.activeMovement, isNull);
      expect(h.machine.canStartMovement, false);
      await until(() => h.channels.length == 2);
      expect(h.urls[1], h.urls[0]);
      expect(h.machine.hasValidConnection, false);
      h.channels.last.incoming.add('READY');
      await until(() => h.machine.hasValidConnection);
      expect(h.channels.last.sink.sent, isEmpty);
    },
  );
  test(
    'heartbeat 200ms, STOP, pinza, speed, sequence and emergency preserve bytes',
    () async {
      final h = Harness();
      await h.setup();
      await h.connectLegacy();
      h.machine.startMovement(MovementDirection.zUp);
      await Future<void>.delayed(const Duration(milliseconds: 225));
      expect(h.channels.single.sink.sent, ['w', 'k']);
      expect(
        MachineController.heartbeatInterval,
        const Duration(milliseconds: 200),
      );
      h.machine.stopMovement();
      h.machine.openGripper();
      h.machine.closeGripper();
      h.machine.requestFaster();
      h.machine.requestSlower();
      h.machine.startSequence();
      h.machine.emergencyStop();
      expect(h.channels.single.sink.sent, [
        'w',
        'k',
        'x',
        'q',
        'e',
        '+',
        '-',
        'j',
        'z',
      ]);
    },
  );
  test(
    'sensor snapshot and final limit still block movement and sequence',
    () async {
      final h = Harness();
      await h.setup();
      await h.connectLegacy();
      h.channels.single.incoming.add('SENSOR:ESTADO:P=1,F=0');
      expect(h.machine.state.plateDetected, true);
      h.machine.startMovement(MovementDirection.xRight);
      h.channels.single.incoming.add('SENSOR:FINAL:1');
      expect(h.machine.state.finalLimitActive, true);
      expect(h.machine.state.activeMovement, isNull);
      expect(h.machine.canStartSequence, false);
      expect(h.machine.canStartMovement, false);
    },
  );
  test(
    'handshake timeout rejects READY absence without replacing URL',
    () async {
      final h = Harness();
      await h.setup(timeout: const Duration(milliseconds: 20));
      await h.machine.connect();
      expect(h.machine.state.connection, ConnectionPhase.error);
      expect(h.machine.lastError, contains('Timeout'));
      expect(h.settings.settings.websocketUrl, 'ws://10.2.3.44:81/');
      expect(h.machine.canStartMovement, false);
    },
  );
  test(
    'legacy IP failure never controls unbound discovery candidates',
    () async {
      final h = Harness();
      await h.setup();
      h.failedHosts.add('10.2.3.44');
      h.discovery.result = () async => [device('10.2.3.99', 'other')];
      await h.machine.connect();
      expect(h.urls, hasLength(1));
      expect(h.machine.devices, hasLength(1));
      expect(h.settings.settings.websocketUrl, 'ws://10.2.3.44:81/');
      expect(h.machine.hasValidConnection, false);
    },
  );
  test(
    'discovery lists all candidates and requires explicit selection and binding',
    () async {
      final h = Harness();
      await h.setup(url: '', lab: false);
      h.discovery.result = () async => [
        device('10.1.1.2'),
        device('10.1.1.3', 'other'),
      ];
      await h.machine.searchEsp32();
      expect(h.machine.devices, hasLength(2));
      expect(h.channels, isEmpty);
      expect(h.machine.selectedDevice, isNull);
      expect(h.machine.linkPhase, Esp32LinkPhase.found);
      await h.machine.selectDevice(h.machine.devices.first);
      await h.machine.connect();
      expect(h.machine.selectedDevice!.deviceId, testDeviceId);
      expect(h.machine.laboratoryEnabled, false);
      expect(h.channels, isEmpty);
      expect(h.machine.hasValidConnection, false);
    },
  );
  test(
    'pair verifies before persisting secret separately and unpair removes it',
    () async {
      final h = Harness();
      await h.setup(v2: true, bound: false);
      final phases = <Esp32LinkPhase>[];
      h.machine.addListener(() => phases.add(h.machine.linkPhase));
      expect(await h.machine.pairSelected(testSecret), true);
      expect(h.machine.isAuthorized, true);
      expect(
        phases,
        containsAllInOrder([
          Esp32LinkPhase.identityVerified,
          Esp32LinkPhase.authenticating,
          Esp32LinkPhase.authorized,
        ]),
      );
      expect(h.credentials.values[testDeviceId], testSecret);
      expect(
        SettingsRepository(h.preferences).load().selectedEsp32!.deviceId,
        testDeviceId,
      );
      expect(
        h.preferences.getKeys().map((k) => h.preferences.get(k)).toString(),
        isNot(contains(testSecret)),
      );
      h.machine.startMovement(MovementDirection.xLeft);
      h.machine.stopNow();
      expect((h.channels.single as Esp32TestPeer).commands, ['a', 'x']);
      await h.machine.unpair();
      expect(h.credentials.values, isEmpty);
      expect(SettingsRepository(h.preferences).load().selectedEsp32, isNull);
    },
  );
  test(
    'secure storage failure cannot enable controls or report binding success',
    () async {
      final h = Harness();
      await h.setup(v2: true, bound: false);
      h.credentials.failWrites = true;
      expect(await h.machine.pairSelected(testSecret), false);
      expect(h.machine.hasValidConnection, false);
      expect(h.credentials.values, isEmpty);
    },
  );
  test(
    'persisted identity and credential authorize a recreated controller',
    () async {
      final h = Harness();
      await h.setup(v2: true);
      h.machine.dispose();
      h.machine = MachineController(
        h.settings,
        discoveryService: h.discovery,
        credentialStore: h.credentials,
        channelFactory: (_) {
          final p = Esp32TestPeer();
          h.channels.add(p);
          return p;
        },
      );
      await h.machine.connect();
      expect(h.machine.isAuthorized, true);
      expect(h.machine.selectedDevice!.deviceId, testDeviceId);
    },
  );
  test(
    'DHCP recovery chooses only bound ID among multiple ESP32 and updates address after proof',
    () async {
      final h = Harness();
      await h.setup(v2: true);
      h.failedHosts.add('10.2.3.44');
      h.discovery.result = () async => [
        device('172.20.10.8', 'foreign'),
        device('172.20.10.9'),
      ];
      await h.machine.connect();
      expect(h.urls.map((u) => u.host), ['10.2.3.44', '172.20.10.9']);
      expect(h.machine.isAuthorized, true);
      expect(h.settings.settings.websocketUrl, 'ws://172.20.10.9:81/');
      expect(h.settings.settings.selectedEsp32!.ip, '172.20.10.9');
    },
  );
  test(
    'duplicate IDs at different addresses never choose the first responder',
    () async {
      final h = Harness();
      await h.setup(v2: true, url: '');
      h.discovery.result = () async => [device('10.1.1.2'), device('10.1.1.3')];
      await h.machine.connect();
      expect(h.channels, isEmpty);
      expect(h.machine.lastError, contains('duplicado'));
    },
  );
  for (final variant in [
    'wrong identity',
    'wrong key',
    'forged proof',
    'busy client',
    'old READY',
    'timeout',
  ]) {
    test(
      'V2 rejects $variant without physical commands or legacy downgrade',
      () async {
        final h = Harness();
        await h.setup(v2: true, timeout: const Duration(milliseconds: 25));
        h.peer = () => Esp32TestPeer(
          deviceId: variant == 'wrong identity' ? 'other' : testDeviceId,
          secret: variant == 'wrong key' ? 'f' * 64 : testSecret,
          badProof: variant == 'forged proof',
          busy: variant == 'busy client',
          reply: variant != 'old READY' && variant != 'timeout',
        );
        final connecting = h.machine.connect();
        await until(() => h.channels.isNotEmpty);
        if (variant == 'old READY') h.channels.single.incoming.add('READY');
        await connecting;
        expect(h.machine.isAuthorized, false);
        expect(h.machine.canStartMovement, false);
        expect((h.channels.single as Esp32TestPeer).commands, isEmpty);
        expect(h.machine.laboratoryEnabled, false);
      },
    );
  }
  test(
    'signed sensors work; replay invalidates session and attempts signed STOP',
    () async {
      final h = Harness();
      await h.setup(v2: true);
      await h.machine.connect();
      final p = h.channels.single as Esp32TestPeer;
      p.event('SENSOR:ESTADO:P=1,F=0');
      expect(h.machine.state.plateDetected, true);
      h.machine.startMovement(MovementDirection.xLeft);
      p.event('SENSOR:PLATO:0');
      expect(h.machine.state.plateDetected, false);
      p.incoming.add(p.eventFrame('SENSOR:PLATO:0', seq: 2));
      expect(h.machine.isAuthorized, false);
      expect(p.commands, ['a', 'x']);
    },
  );
  test(
    'cancel discovery ignores late candidate and never persists its address',
    () async {
      final h = Harness();
      await h.setup(v2: true, url: '');
      final reply = Completer<List<Esp32Device>>();
      h.discovery.result = () => reply.future;
      final connecting = h.machine.connect();
      await until(() => h.machine.isDiscovering);
      h.machine.cancelSearch();
      reply.complete([device('192.168.8.22')]);
      await connecting;
      expect(h.channels, isEmpty);
      expect(h.machine.isDiscovering, false);
      expect(h.machine.state.connection, ConnectionPhase.disconnected);
      expect(h.settings.settings.websocketUrl, isEmpty);
    },
  );
  test(
    'hotspot to router retains ID, stops movement and reauthorizes on each LAN',
    () async {
      final h = Harness();
      await h.setup(v2: true);
      await h.settings.setAutoReconnect(true);
      await h.machine.connect();
      for (final ip in ['172.20.10.8', '192.168.50.63', '10.42.2.19']) {
        final previous = h.channels.last as Esp32TestPeer;
        h.machine.startMovement(MovementDirection.zDown);
        h.machine.handleAppInactive();
        expect(previous.commands, ['s', 'x']);
        expect(h.machine.canStartMovement, false);
        h.failedHosts.add(Uri.parse(h.settings.settings.websocketUrl).host);
        h.discovery.result = () async => [
          device(ip),
          device('10.0.0.99', 'foreign'),
        ];
        h.machine.handleAppResumed();
        await until(() => h.settings.settings.selectedEsp32!.ip == ip);
        expect(h.machine.isAuthorized, true);
        expect(h.machine.state.activeMovement, isNull);
        expect(h.machine.selectedDevice!.deviceId, testDeviceId);
      }
    },
  );
}
