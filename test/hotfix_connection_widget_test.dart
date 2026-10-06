import 'dart:async';

import 'package:blanquita/app/app.dart';
import 'package:blanquita/app/navigation/main_shell.dart';
import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/network/esp32_discovery_service.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/settings/controller/app_settings.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/vision/support/vision_test_channel.dart';
import 'features/vision/support/vision_test_discovery.dart';

class _Discovery extends Esp32DiscoveryService {
  Future<Uri?> Function() result = () async => null;
  int calls = 0;
  @override
  Future<Uri?> discover() {
    calls++;
    return result();
  }

  @override
  void cancel() {}
  @override
  void dispose() {}
}

class _DelayedRepository extends SettingsRepository {
  _DelayedRepository(super.preferences, this.barrier);
  final Completer<void> barrier;
  @override
  Future<void> save(AppSettings settings) async {
    await barrier.future;
    await super.save(settings);
  }
}

class _Fixture {
  late SettingsController settings;
  late MachineController machine;
  late VisionController vision;
  final espDiscovery = _Discovery();
  late TestVisionDiscovery visionDiscovery;
  Future<Uri?> Function() findVision = () async => null;
  final channels = <TestVisionChannel>[];
  final espUrls = <Uri>[];
  final visionUrls = <Uri>[];
  final failedHosts = <String>{};

  Future<void> load({
    String esp = '',
    String visor = '',
    bool retry = false,
    Completer<void>? saveBarrier,
  }) async {
    SharedPreferences.setMockInitialValues({
      'connection.websocket_url': esp,
      'vision.websocket_url': visor,
      'connection.auto_reconnect': retry,
      'vision.auto_reconnect': retry,
      'control.haptics': false,
      'appearance.performance_mode': true,
      'appearance.reduce_motion': true,
    });
    final preferences = await SharedPreferences.getInstance();
    settings = SettingsController(
      saveBarrier == null
          ? SettingsRepository(preferences)
          : _DelayedRepository(preferences, saveBarrier),
    );
    await settings.load();
    visionDiscovery = TestVisionDiscovery(() => findVision());
    machine = MachineController(
      settings,
      discoveryService: espDiscovery,
      channelFactory: (uri) => open(uri, false),
    );
    vision = VisionController(
      settings,
      discoveryService: visionDiscovery,
      tickInterval: const Duration(days: 1),
      service: RemoteVisionService(channelFactory: (uri) => open(uri, true)),
    );
  }

  TestVisionChannel open(Uri uri, bool visor) {
    (visor ? visionUrls : espUrls).add(uri);
    final channel = TestVisionChannel();
    channels.add(channel);
    scheduleMicrotask(() {
      if (failedHosts.contains(uri.host)) {
        channel.incoming.addError(StateError('DHCP changed'));
      } else if (visor) {
        channel.receive('vision.ready', DateTime.now());
      } else {
        channel.incoming.add('READY');
      }
    });
    return channel;
  }

  Widget app({bool autoConnect = false}) => BlanquitaApp(
    settingsController: settings,
    machineController: machine,
    visionController: vision,
    autoConnect: autoConnect,
  );

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future.wait(channels.map((c) => c.incoming.close())),
    );
  }
}

void main() {
  testWidgets(
    'startup waits through inactivity and starts both discoveries on resume',
    (tester) async {
      final f = _Fixture();
      await f.load();
      await tester.pumpWidget(f.app(autoConnect: true));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 1));
      expect(f.espDiscovery.calls, 0);
      expect(f.visionDiscovery.calls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(f.espDiscovery.calls, 1);
      expect(f.visionDiscovery.calls, 1);
      await f.close(tester);
    },
  );

  testWidgets(
    'old discoveries cancelled by lifecycle cannot overwrite newer validated endpoints',
    (tester) async {
      final f = _Fixture();
      await f.load(retry: true);
      final oldEsp = Completer<Uri?>();
      final oldVision = Completer<Uri?>();
      f.espDiscovery.result = () => oldEsp.future;
      f.findVision = () => oldVision.future;
      await tester.pumpWidget(f.app(autoConnect: true));
      await tester.pump(const Duration(milliseconds: 450));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      f.espDiscovery.result = () async => Uri.parse('ws://192.168.137.209:81/');
      f.findVision = () async => Uri.parse('ws://192.168.137.115:8765/');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      oldEsp.complete(Uri.parse('ws://10.0.28.209:81/'));
      oldVision.complete(Uri.parse('ws://10.0.28.115:8765/'));
      await tester.pumpAndSettle();
      expect(f.espUrls.map((u) => u.host), ['192.168.137.209']);
      expect(f.visionUrls.map((u) => u.host), ['192.168.137.115']);
      expect(f.settings.settings.websocketUrl, 'ws://192.168.137.209:81/');
      expect(
        f.settings.settings.visionWebsocketUrl,
        'ws://192.168.137.115:8765/',
      );
      expect(f.machine.state.isConnected, true);
      expect(f.vision.state.ready, true);
      expect(tester.takeException(), isNull);
      await f.close(tester);
    },
  );

  testWidgets(
    'Buscar dispositivos uses UDP first for both; Vision failure leaves manual ESP32 control working',
    (tester) async {
      final f = _Fixture();
      await f.load(
        esp: 'ws://10.0.28.209:81/',
        visor: 'ws://10.0.28.115:8765/',
      );
      f.espDiscovery.result = () async => Uri.parse('ws://192.168.137.209:81/');
      f.findVision = () async => Uri.parse('ws://192.168.137.115:8765/');
      f.failedHosts.add('192.168.137.115');
      await tester.pumpWidget(f.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Buscar dispositivos'));
      await tester.tap(find.text('Buscar dispositivos'));
      await tester.pumpAndSettle();
      expect(f.espUrls.map((u) => u.host), ['192.168.137.209']);
      expect(f.visionUrls.map((u) => u.host), ['192.168.137.115']);
      expect(f.espDiscovery.calls, 1);
      expect(f.visionDiscovery.calls, 1);
      expect(f.vision.state.isConnected, false);
      expect(f.settings.settings.visionWebsocketUrl, 'ws://10.0.28.115:8765/');
      expect(f.machine.startMovement(MovementDirection.zUp), true);
      expect(f.channels.first.sink.sent, ['w']);
      f.machine.stopMovement();
      expect(f.channels.first.sink.sent, ['w', 'x']);
      expect(tester.takeException(), isNull);
      await f.close(tester);
    },
  );

  for (final visor in [false, true]) {
    testWidgets(
      'manual disconnect wins over ${visor ? 'Vision' : 'ESP32'} URL persistence in progress',
      (tester) async {
        final barrier = Completer<void>();
        final f = _Fixture();
        await f.load(saveBarrier: barrier);
        await tester.pumpWidget(f.app());
        await tester.pumpAndSettle();
        final saving = visor
            ? f.vision.saveEndpointAndReconnect('ws://192.168.137.115:8765/')
            : f.machine.saveEndpointAndReconnect('ws://192.168.137.209:81/');
        await tester.pump();
        if (visor) {
          await f.vision.disconnect();
        } else {
          await f.machine.disconnect();
        }
        barrier.complete();
        await saving;
        await tester.pumpAndSettle();
        expect(f.channels, isEmpty);
        expect(f.espDiscovery.calls, 0);
        expect(f.visionDiscovery.calls, 0);
        expect(f.machine.state.isConnected, false);
        expect(f.vision.state.isConnected, false);
        expect(tester.takeException(), isNull);
        await f.close(tester);
      },
    );
    testWidgets(
      'guardar URL ${visor ? 'Vision' : 'ESP32'} keeps MaterialApp and Navigator mounted without _dependents.isEmpty',
      (tester) async {
        final f = _Fixture();
        await f.load();
        await tester.pumpWidget(f.app());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();
        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        final shell = tester.state(find.byType(MainShell));
        if (visor) {
          await tester.ensureVisible(find.text('Conexión visión'));
          await tester.tap(find.text('Conexión visión'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('URL Vision Server'));
          await tester.tap(find.text('URL Vision Server'));
        } else {
          await tester.tap(find.text('WebSocket: Sin dirección guardada'));
        }
        await tester.pumpAndSettle();
        final url = visor
            ? 'ws://192.168.137.115:8765/'
            : 'ws://192.168.137.209:81/';
        await tester.enterText(find.byType(TextField), url);
        await tester.tap(find.text('Guardar'));
        // Nothing may be persisted while the dialog overlay still exists.
        await tester.pump();
        expect(
          visor
              ? f.settings.settings.visionWebsocketUrl
              : f.settings.settings.websocketUrl,
          isEmpty,
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason:
              'URL save must not trigger _dependents.isEmpty or disposed controllers',
        );
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          visor
              ? f.settings.settings.visionWebsocketUrl
              : f.settings.settings.websocketUrl,
          url,
        );
        expect(
          visor ? f.vision.state.isConnected : f.machine.state.isConnected,
          true,
        );
        expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), same(app));
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        expect(navigator.mounted, true);
        expect(tester.state(find.byType(MainShell)), same(shell));
        final context = tester.element(find.byType(MainShell));
        expect(context.read<MachineController>(), same(f.machine));
        expect(context.read<VisionController>(), same(f.vision));
        expect(context.read<SettingsController>(), same(f.settings));
        await f.close(tester);
      },
    );
  }

  testWidgets('only theme changes rebuild MaterialApp', (tester) async {
    final f = _Fixture();
    await f.load();
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final navigator = tester.state(find.byType(Navigator));
    final shell = tester.state(find.byType(MainShell));
    await f.settings.setVisionHeartbeatTimeout(const Duration(seconds: 10));
    await f.settings.setVisionMinimumConfidence(.7);
    await f.settings.setAutoReconnect(true);
    await f.settings.setVisionAutoReconnect(true);
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), same(app));
    await f.settings.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(tester.state(find.byType(Navigator)), same(navigator));
    expect(tester.state(find.byType(MainShell)), same(shell));
    expect(tester.takeException(), isNull);
    await f.close(tester);
  });

  testWidgets(
    'startup with both URLs empty discovers both independently and persists validated endpoints',
    (tester) async {
      final f = _Fixture();
      await f.load();
      final esp = Completer<Uri?>();
      final visor = Completer<Uri?>();
      f.espDiscovery.result = () => esp.future;
      f.findVision = () => visor.future;
      await tester.pumpWidget(f.app(autoConnect: true));
      await tester.pump(const Duration(milliseconds: 450));
      expect(f.espDiscovery.calls, 1);
      expect(f.visionDiscovery.calls, 1);
      expect(f.machine.isDiscovering, true);
      expect(f.vision.isDiscovering, true);
      esp.complete(Uri.parse('ws://192.168.137.209:81/'));
      await tester.pump();
      expect(f.machine.state.isConnected, true);
      expect(f.vision.isDiscovering, true);
      visor.complete(Uri.parse('ws://192.168.137.115:8765/'));
      await tester.pumpAndSettle();
      expect(f.settings.settings.websocketUrl, 'ws://192.168.137.209:81/');
      expect(
        f.settings.settings.visionWebsocketUrl,
        'ws://192.168.137.115:8765/',
      );
      expect(f.vision.state.ready, true);
      expect(tester.takeException(), isNull);
      await f.close(tester);
    },
  );

  testWidgets(
    'startup obsolete ESP32 and Vision URLs recover through discovery without user action',
    (tester) async {
      final f = _Fixture();
      await f.load(
        esp: 'ws://10.0.28.209:81/',
        visor: 'ws://10.0.28.115:8765/',
      );
      f.failedHosts.addAll(['10.0.28.209', '10.0.28.115']);
      f.espDiscovery.result = () async => Uri.parse('ws://192.168.137.209:81/');
      f.findVision = () async => Uri.parse('ws://192.168.137.115:8765/');
      await tester.pumpWidget(f.app(autoConnect: true));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(f.espUrls.map((u) => u.host), ['10.0.28.209', '192.168.137.209']);
      expect(f.visionUrls.map((u) => u.host), [
        '10.0.28.115',
        '192.168.137.115',
      ]);
      expect(f.machine.state.isConnected, true);
      expect(f.vision.state.ready, true);
      expect(f.settings.settings.websocketUrl, 'ws://192.168.137.209:81/');
      expect(
        f.settings.settings.visionWebsocketUrl,
        'ws://192.168.137.115:8765/',
      );
      expect(tester.takeException(), isNull);
      await f.close(tester);
    },
  );

  testWidgets(
    'resumed after DHCP change stops manual movement and recovers both with stable providers',
    (tester) async {
      final f = _Fixture();
      await f.load(
        esp: 'ws://10.0.28.209:81/',
        visor: 'ws://10.0.28.115:8765/',
        retry: true,
      );
      await tester.pumpWidget(f.app(autoConnect: true));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final navigator = tester.state(find.byType(Navigator));
      final shell = tester.state(find.byType(MainShell));
      expect(f.machine.startMovement(MovementDirection.xLeft), true);
      final oldEspChannel = f.channels.first;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(f.machine.state.activeMovement, isNull);
      expect(oldEspChannel.sink.sent, ['a', 'x']);
      await tester.pump(const Duration(milliseconds: 600));
      expect(oldEspChannel.sink.sent, [
        'a',
        'x',
      ], reason: 'inactive must stop the 200 ms heartbeat');
      for (final pair in [
        ['192.168.137.209', '192.168.137.115'],
        ['10.42.193.209', '10.42.193.115'],
        ['172.20.10.209', '172.20.10.115'],
      ]) {
        f.failedHosts.addAll([
          Uri.parse(f.settings.settings.websocketUrl).host,
          Uri.parse(f.settings.settings.visionWebsocketUrl).host,
        ]);
        f.espDiscovery.result = () async => Uri.parse('ws://${pair[0]}:81/');
        f.findVision = () async => Uri.parse('ws://${pair[1]}:8765/');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(f.machine.state.isConnected, true);
        expect(f.vision.state.ready, true);
        expect(f.settings.settings.websocketUrl, 'ws://${pair[0]}:81/');
        expect(f.settings.settings.visionWebsocketUrl, 'ws://${pair[1]}:8765/');
        expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), same(app));
        expect(tester.state(find.byType(Navigator)), same(navigator));
        expect(tester.state(find.byType(MainShell)), same(shell));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
      }
      await f.machine.disconnect();
      await f.vision.disconnect();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 30));
      expect(f.espDiscovery.calls, 3);
      expect(f.visionDiscovery.calls, 3);
      expect(f.machine.state.isConnected, false);
      expect(f.vision.state.isConnected, false);
      expect(tester.takeException(), isNull);
      await f.close(tester);
    },
  );
}
