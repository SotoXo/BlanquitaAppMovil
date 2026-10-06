import 'package:blanquita/app/app.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/vision/support/vision_test_channel.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'dart:async';
import 'package:blanquita/core/network/esp32_discovery_service.dart';
import 'features/vision/support/vision_test_discovery.dart';

class _WidgetDiscovery extends Esp32DiscoveryService {
  _WidgetDiscovery(this.result);
  final Future<Uri?> Function() result;
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
            scheduleMicrotask(
              () => channel.receive('vision.ready', DateTime.now()),
            );
            return channel;
          },
        ),
      );
      await tester.pumpWidget(
        BlanquitaApp(
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
      visionResult.complete(Uri.parse('ws://192.168.137.115:8765/'));
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
      await vision.disconnect();
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
    expect(find.text('Red esperada: CARTESIANO'), findsOneWidget);
    expect(find.text('ESP32: Desconectado'), findsOneWidget);
    expect(find.text('Dirección: Sin dirección'), findsOneWidget);
    expect(find.text('Buscar ESP32'), findsOneWidget);

    await tester.tap(find.text('WebSocket: Sin dirección guardada'));
    await tester.pumpAndSettle();
    expect(find.text('Dirección WebSocket'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'remote monitor and vision settings work on a narrow mobile screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'vision.websocket_url': 'ws://laptop.test:8765/',
        'appearance.performance_mode': true,
        'appearance.reduce_motion': true,
      });
      final settings = SettingsController(
        SettingsRepository(await SharedPreferences.getInstance()),
      );
      await settings.load();
      final machine = MachineController(settings);
      final channel = TestVisionChannel();
      final now = DateTime.utc(2026, 10, 6, 10, 30);
      final vision = VisionController(
        settings,
        now: () => now,
        tickInterval: const Duration(days: 1),
        service: RemoteVisionService(
          channelFactory: (_) {
            scheduleMicrotask(() => channel.receive('vision.ready', now));
            return channel;
          },
        ),
      );
      // Real transport futures and timer cleanup run outside the widget fake clock.
      await tester.runAsync(() => vision.connect());
      channel.receive('vision.ready', now);
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
      expect(find.text('Laptop · Conectada'), findsOneWidget);
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
        find.text('Introduce una URL ws:// o wss:// válida.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(settings.settings.visionWebsocketUrl, 'ws://laptop.test:8765/');
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => vision.disconnect());
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => channel.incoming.close());
    },
  );
}
