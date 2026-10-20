import 'package:blanquita/app/app.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/network/wifi_network_controller.dart';
import 'package:blanquita/core/network/wifi_network_service.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/control/widgets/hold_to_move_button.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/settings/presentation/endpoint_dialog.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/shared/widgets/wifi_network_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'features/vision/support/vision_test_channel.dart';

import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'dart:async';
import 'package:blanquita/core/models/esp32_device.dart';
import 'package:blanquita/core/network/esp32_discovery_service.dart';
import 'features/vision/support/vision_test_discovery.dart';

class _WidgetDiscovery extends Esp32DiscoveryService {
  _WidgetDiscovery(this.result);
  final Future<Uri?> Function() result;
  int calls = 0;
  @override
  Future<List<Esp32Device>> discoverDevices() async {
    calls++;
    await result();
    return [];
  }

  @override
  void cancel() {}
  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'Buscar dispositivos starts independent searches and preserves Vision on ESP32 failure',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'connection.auto_reconnect': false,
        'vision.auto_reconnect': false,
        'appearance.performance_mode': true,
        'appearance.reduce_motion': true,
      });
      final settings = SettingsController(
        SettingsRepository(await SharedPreferences.getInstance()),
      );
      await settings.load();
      final machineResult = Completer<Uri?>();
      final visionResult = Completer<Uri?>();
      final espDiscovery = _WidgetDiscovery(() => machineResult.future);
      final visionDiscovery = TestVisionDiscovery(() => visionResult.future);
      final machine = MachineController(
        settings,
        discoveryService: espDiscovery,
      );
      final channel = TestVisionChannel();
      final vision = VisionController(
        settings,
        discoveryService: visionDiscovery,
        tickInterval: const Duration(days: 1),
        service: RemoteVisionService(
          channelFactory: (_) {
            scheduleMicrotask(() => channel.establish(DateTime.now()));
            return channel;
          },
        ),
      );
      await tester.pumpWidget(
        BlanquitaApp(
          wifiController: _testWifiController(),
          settingsController: settings,
          machineController: machine,
          visionController: vision,
          autoConnect: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Buscar dispositivos'));
      await tester.tap(find.text('Buscar dispositivos'));
      await tester.pump();
      expect(espDiscovery.calls, 1);
      expect(visionDiscovery.calls, 1);
      expect(machine.isDiscovering, true);
      expect(vision.isDiscovering, true);
      visionResult.complete(Uri.parse('ws://192.168.137.115:8765/vision'));
      await tester.pump();
      expect(vision.state.ready, true);
      expect(machine.isDiscovering, true);
      machineResult.complete(null);
      await tester.pumpAndSettle();
      expect(machine.state.isConnected, false);
      expect(vision.state.isConnected, true);
      expect(find.text('Dirección detectada: 192.168.137.115'), findsOneWidget);
      expect(find.text('Discovery: Visor validado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => vision.disconnect());
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => channel.incoming.close());
    },
  );

  testWidgets('shows the four persistent navigation destinations', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsController(SettingsRepository(preferences));
    await settings.load();
    final machine = MachineController(settings);

    await tester.pumpWidget(
      BlanquitaApp(
        wifiController: _testWifiController(),
        settingsController: settings,
        machineController: machine,
        visionController: VisionController(settings),
        autoConnect: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BLANQUITA'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Control'), findsOneWidget);
    expect(find.text('Visión'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Estado no confirmado'), findsOneWidget);
    expect(find.text('Listo'), findsNothing);

    await tester.tap(find.text('Control'));
    await tester.pumpAndSettle();
    expect(find.text('Mando seguro'), findsOneWidget);

    await tester.tap(find.text('Visión'));
    await tester.pumpAndSettle();
    expect(find.text('Sin datos de visión'), findsOneWidget);
    expect(find.text('Laptop · Desconectada'), findsOneWidget);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir diagnósticos'), findsOneWidget);
    expect(
      find.text('Red local: hotspot o router · sin depender del SSID'),
      findsOneWidget,
    );
    expect(find.text('ESP32: Desconectado'), findsOneWidget);
    expect(find.text('Dirección: Sin dirección'), findsOneWidget);
    expect(find.text('Reconectar URL ESP32'), findsOneWidget);
    expect(find.text('Probar conexión ESP32'), findsOneWidget);
    expect(find.text('Buscar ESP32'), findsNothing);

    await tester.ensureVisible(find.text('WebSocket: Sin dirección guardada'));
    await tester.tap(find.text('WebSocket: Sin dirección guardada'));
    await tester.pumpAndSettle();
    expect(find.text('Dirección WebSocket'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('both endpoint dialogs survive repeated save cancel and back', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'appearance.performance_mode': true,
      'appearance.reduce_motion': true,
      'connection.auto_reconnect': false,
      'vision.auto_reconnect': false,
    });
    final settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await settings.load();
    // Settings reconnect on URL changes. Never open a real socket in this test.
    final machine = MachineController(
      settings,
      channelFactory: (_) => throw StateError('Canal de prueba cerrado'),
    );
    final vision = VisionController(
      settings,
      service: RemoteVisionService(
        channelFactory: (_) =>
            throw StateError('Canal visión de prueba cerrado'),
      ),
    );
    await tester.pumpWidget(
      BlanquitaApp(
        wifiController: _testWifiController(),
        settingsController: settings,
        machineController: machine,
        visionController: vision,
        autoConnect: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    Future<void> openMachine() async {
      final link = find.textContaining('WebSocket:');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
    }

    Future<void> openVision() async {
      final title = find.text('Conexión visión');
      await tester.ensureVisible(title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      final link = find.text('URL Vision Server');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
    }

    for (var cycle = 0; cycle < 4; cycle++) {
      await openMachine();
      await tester.enterText(find.byType(TextFormField), 'http://invalid');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Introduce una URL ws:// o wss:// válida.'),
        findsOneWidget,
      );
      expect(settings.settings.websocketUrl, isEmpty);
      await tester.tap(find.text('Cancelar'));
      // The field still exists during the reverse route animation.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      await openMachine();
      await tester.enterText(
        find.byType(TextFormField),
        '  ws://esp32.test:${81 + cycle}/  ',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pump(const Duration(milliseconds: 1));
      await settings.setShowWarnings(cycle.isEven);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(settings.settings.websocketUrl, 'ws://esp32.test:${81 + cycle}/');
      expect(settings.settings.visionWebsocketUrl, isEmpty);

      await openVision();
      await tester.enterText(
        find.byType(TextFormField),
        'ws://laptop.test:${8765 + cycle}/',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pump(const Duration(milliseconds: 1));
      await settings.setThemeMode(
        cycle.isEven ? ThemeMode.light : ThemeMode.dark,
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(
        settings.settings.visionWebsocketUrl,
        'ws://laptop.test:${8765 + cycle}/vision',
      );
      expect(settings.settings.websocketUrl, 'ws://esp32.test:${81 + cycle}/');

      // Close with Android-style back while the text field owns focus.
      await tester.ensureVisible(find.text('URL Vision Server'));
      await tester.tap(find.text('URL Vision Server'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextFormField));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('URL Vision Server'));
      await tester.tap(find.text('URL Vision Server'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(settings.settings.visionWebsocketUrl, isEmpty);

      await tester.ensureVisible(find.text('Conexión visión'));
      await tester.tap(find.text('Conexión visión'));
      await tester.pumpAndSettle();
      await openMachine();
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(settings.settings.websocketUrl, isEmpty);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('endpoint validation rejects bad schemes hosts spaces and ports', () {
    for (final invalid in [
      'http://host:81/',
      'ws://',
      'ws://some host:81/',
      'ws://host:0/',
      'ws://host:00/',
      'ws://host:65536/',
      'ws://host:abc/',
      'ws://host:81/#fragment',
      'ws://0.0.0.0:8765/',
      'ws://[::]:8765/',
    ]) {
      expect(EndpointDialog.validate(invalid), isNotNull, reason: invalid);
    }
    for (final valid in [
      '',
      '  ',
      ' ws://192.168.43.27:81/ ',
      'wss://laptop.test:8765/vision',
      'ws://laptop.test/',
      'wss://laptop.test/',
      'ws://[::1]:8765/',
    ]) {
      expect(EndpointDialog.validate(valid), isNull, reason: valid);
    }
    expect(
      EndpointDialog.validate('ws://0.0.0.0:8765/'),
      '0.0.0.0 / :: es una dirección de escucha. Escribe la IP real del dispositivo.',
    );
  });

  testWidgets('endpoint form scrolls with keyboard landscape and large text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(375, 812), const Size(812, 375)]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 160),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () => showDialog<String>(
                      context: context,
                      builder: (_) => const EndpointDialog(
                        title: 'URL Vision Server',
                        label: 'URL laptop',
                        initialValue: '',
                        hint: 'ws://192.168.43.100:8765/',
                      ),
                    ),
                    child: const Text('Editar'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'http://invalid');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'Wi-Fi panel presents observed states at large mobile text size',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'appearance.performance_mode': true,
      });
      final settings = SettingsController(
        SettingsRepository(await SharedPreferences.getInstance()),
      );
      await settings.load();
      const cases = {
        WifiNetworkStatus(): 'Consulta Wi-Fi no disponible',
        WifiNetworkStatus(supported: true): 'Wi-Fi desactivado',
        WifiNetworkStatus(supported: true, wifiEnabled: true):
            'Wi-Fi activado · sin conexión',
        WifiNetworkStatus(
          supported: true,
          wifiEnabled: true,
          connected: true,
          localIpv4: '192.168.137.24',
          rssiDbm: -56,
          linkSpeedMbps: 144,
          defaultRouteWifi: true,
          internetValidated: true,
        ): 'Wi-Fi conectado',
        WifiNetworkStatus(
          supported: true,
          wifiEnabled: true,
          connected: true,
          rssiDbm: -85,
          defaultRouteWifi: false,
          internetValidated: false,
        ): 'Wi-Fi conectado',
      };
      for (final scenario in cases.entries) {
        final wifi = WifiNetworkController(
          service: _TestWifiService(scenario.key),
          sampleInterval: const Duration(days: 1),
        );
        await wifi.start();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<WifiNetworkController>.value(value: wifi),
              ChangeNotifierProvider<SettingsController>.value(value: settings),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(child: WifiNetworkPanel()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(scenario.value), findsOneWidget);
        if (scenario.key.connected) {
          expect(find.text('Observando enlace'), findsOneWidget);
          expect(find.textContaining('IP del teléfono:'), findsOneWidget);
          expect(find.textContaining('Señal:'), findsOneWidget);
        }
        if (scenario.key.defaultRouteWifi == false) {
          expect(find.textContaining('Android usa otra red'), findsOneWidget);
          expect(
            find.textContaining(
              'La comunicación con dispositivos en la red local',
            ),
            findsOneWidget,
          );
        }
        await tester.ensureVisible(find.text('Actualizar Wi-Fi'));
        await tester.tap(find.text('Actualizar Wi-Fi'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        wifi.dispose();
      }
      settings.dispose();
    },
  );

  testWidgets('endpoint submit closes one route despite queued extra actions', (
    tester,
  ) async {
    final results = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        const Text('Página de ajustes'),
                        FilledButton(
                          onPressed: () async {
                            results.add(
                              await showDialog<String>(
                                context: context,
                                builder: (_) => const EndpointDialog(
                                  title: 'URL Vision Server',
                                  label: 'URL laptop',
                                  initialValue: 'ws://laptop.test:8765/',
                                  hint: 'ws://192.168.43.100:8765/',
                                ),
                              ),
                            );
                          },
                          child: const Text('Editar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('Abrir ajustes'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();
    for (final firstAction in ['keyboard', 'button']) {
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextFormField));
      final save = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
          .onPressed!;
      final cancel = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
          .onPressed!;
      if (firstAction == 'keyboard') {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else {
        save();
      }
      // Simulate taps already queued before the closing frame rebuilds.
      save();
      cancel();
      await tester.pumpAndSettle();
      expect(find.text('Página de ajustes'), findsOneWidget);
      expect(find.byType(EndpointDialog), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(results, ['ws://laptop.test:8765/', 'ws://laptop.test:8765/']);
  });

  testWidgets('held movement stops when its widget unmounts', (tester) async {
    SharedPreferences.setMockInitialValues({
      'connection.websocket_url': 'ws://esp32.test:81/',
      'esp32.laboratory_mode': true,
      'connection.auto_reconnect': false,
      'control.haptics': false,
      'appearance.reduce_motion': true,
    });
    final settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await settings.load();
    final channel = TestVisionChannel();
    final machine = MachineController(settings, channelFactory: (_) => channel);
    final visible = ValueNotifier(true);
    await tester.runAsync(() async {
      final connecting = machine.connect();
      await Future<void>.delayed(Duration.zero);
      channel.incoming.add('READY');
      for (final name in ['X_IZQ', 'X_DER', 'Z_ARRIBA', 'Z_ABAJO']) {
        channel.incoming.add('SENSOR:FC:$name:0');
      }
      await connecting;
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<MachineController>.value(value: machine),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, show, child) => show
                  ? Consumer<MachineController>(
                      builder: (context, machine, child) => Center(
                        child: SizedBox(
                          width: 100,
                          height: 90,
                          child: HoldToMoveButton(
                            movement: MovementDirection.xLeft,
                            icon: Icons.arrow_back,
                            label: 'Izquierda',
                            enabled: machine.canStartMovement,
                            active: machine.state.activeMovement != null,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToMoveButton)),
    );
    await tester.pump();
    expect(machine.state.activeMovement, MovementDirection.xLeft);
    visible.value = false;
    await tester.pump();
    expect(machine.state.activeMovement, isNull);
    expect(channel.sink.sent.last, 'x');
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    machine.dispose();
    settings.dispose();
    visible.dispose();
    await tester.runAsync(() => channel.incoming.close());
  });

  testWidgets('held movement is stopped during app disposal', (tester) async {
    SharedPreferences.setMockInitialValues({
      'connection.websocket_url': 'ws://esp32.test:81/',
      'esp32.laboratory_mode': true,
      'connection.auto_reconnect': false,
      'control.haptics': false,
      'appearance.reduce_motion': true,
    });
    final settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await settings.load();
    final channel = TestVisionChannel();
    final machine = MachineController(settings, channelFactory: (_) => channel);
    await tester.runAsync(() async {
      final connecting = machine.connect();
      await Future<void>.delayed(Duration.zero);
      channel.incoming.add('READY');
      for (final name in ['X_IZQ', 'X_DER', 'Z_ARRIBA', 'Z_ABAJO']) {
        channel.incoming.add('SENSOR:FC:$name:0');
      }
      await connecting;
    });
    await tester.pumpWidget(
      BlanquitaApp(
        wifiController: _testWifiController(),
        settingsController: settings,
        machineController: machine,
        visionController: VisionController(settings),
        autoConnect: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Control'));
    await tester.pumpAndSettle();
    final hold = find.byType(HoldToMoveButton).first;
    await tester.ensureVisible(hold);
    final gesture = await tester.startGesture(tester.getCenter(hold));
    await tester.pump();
    expect(machine.state.activeMovement, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(channel.sink.sent.last, 'x');
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.runAsync(() => channel.incoming.close());
  });

  testWidgets(
    'remote monitor and vision settings work on a narrow mobile screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'vision.websocket_url': 'ws://laptop.test:8765/vision',
        'appearance.performance_mode': true,
        'appearance.reduce_motion': true,
      });
      final settings = SettingsController(
        SettingsRepository(await SharedPreferences.getInstance()),
      );
      await settings.load();
      final machine = MachineController(settings);
      late TestVisionChannel channel;
      final now = DateTime.utc(2026, 10, 6, 10, 30);
      final vision = VisionController(
        settings,
        now: () => now,
        tickInterval: const Duration(days: 1),
        service: RemoteVisionService(
          channelFactory: (_) {
            channel = TestVisionChannel();
            scheduleMicrotask(() => channel.establish(now));
            return channel;
          },
        ),
      );
      // Real transport futures and timer cleanup run outside the widget fake clock.
      await tester.runAsync(() => vision.connect());
      channel.establish(now);
      channel.receive('vision.status', now, {
        'cameraName': 'USB laptop',
        'cameraStatus': 'operative',
        'calibrationStatus': 'valid',
        'detectorStatus': 'active',
        'fps': 24,
      });
      channel.receive('vision.report', now, {
        'detected': true,
        'object': 'pieza',
        'position': {'x': 145.2, 'z': 78.4},
        'confidence': .96,
      });
      await tester.pumpWidget(
        BlanquitaApp(
          wifiController: _testWifiController(),
          settingsController: settings,
          machineController: machine,
          visionController: vision,
          autoConnect: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(machine.state.isConnected, false);
      expect(vision.state.isConnected, true);
      await tester.tap(find.text('Visión'));
      await tester.pumpAndSettle();
      expect(find.text('Laptop · Vision Server listo'), findsOneWidget);
      expect(find.text('USB laptop'), findsOneWidget);
      expect(find.text('Sin datos de visión'), findsNothing);
      await tester.ensureVisible(find.text('Confianza'));
      await tester.pumpAndSettle();
      expect(find.text('145.20'), findsOneWidget);
      expect(find.text('78.40'), findsOneWidget);
      expect(find.text('96.0 %'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Conexión visión'));
      await tester.tap(find.text('Conexión visión'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('URL Vision Server'));
      await tester.tap(find.text('URL Vision Server'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'http://invalid');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Usa ws://HOST:PUERTO/vision sin query ni fragmento.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        settings.settings.visionWebsocketUrl,
        'ws://laptop.test:8765/vision',
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => vision.disconnect());
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => channel.incoming.close());
    },
  );
}

class _TestWifiService extends WifiNetworkService {
  _TestWifiService(this.status);

  final WifiNetworkStatus status;

  @override
  Future<WifiNetworkStatus> read() async => status;

  @override
  Stream<WifiNetworkStatus> watch() => const Stream.empty();
}

WifiNetworkController _testWifiController() =>
    WifiNetworkController(service: _TestWifiService(const WifiNetworkStatus()));
