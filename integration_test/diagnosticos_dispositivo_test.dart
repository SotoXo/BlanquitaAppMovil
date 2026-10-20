import 'package:blanquita/app/presentation/controller_ui_context.dart';
import 'dart:io';

import 'package:blanquita/app/app.dart';
import 'package:blanquita/core/diagnostics/connection_log.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This is a device UI regression, with isolated preferences and transports.
// It never connects to a robot or changes the installed app's saved settings.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editar visión y copiar diagnósticos sin errores de widgets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'appearance.reduce_motion': true,
      'connection.auto_reconnect': false,
      'vision.auto_reconnect': false,
      'control.haptics': false,
    });
    final settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await settings.load();
    final machine = MachineController(
      settings,
      channelFactory: (_) => throw const SocketException(
        'Connection refused',
        osError: OSError('Connection refused', 111),
      ),
    );
    final vision = VisionController(
      settings,
      service: RemoteVisionService(
        channelFactory: (_) => throw const SocketException(
          'Connection refused',
          osError: OSError('Connection refused', 111),
        ),
      ),
    );
    ConnectionLog.shared.clear();
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
    await tester.ensureVisible(find.text('Conexión visión'));
    await tester.tap(find.text('Conexión visión'));
    await tester.pumpAndSettle();

    await binding.convertFlutterSurfaceToImage();
    Future<void> screenshot(String name) async {
      await tester.pump();
      final bytes = await binding.takeScreenshot(name);
      await File('${Directory.systemTemp.path}/$name.png').writeAsBytes(bytes);
    }

    for (var cycle = 0; cycle < 3; cycle++) {
      await tester.ensureVisible(find.text('URL Vision Server'));
      await tester.tap(find.text('URL Vision Server'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'http://direccion-invalida',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Introduce una URL ws:// o wss:// válida.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byType(TextFormField),
        'ws://192.0.2.20:8765/',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Introduce una URL ws:// o wss:// válida.'),
        findsNothing,
      );
      if (cycle == 0) await screenshot('blanquita-vision-edit');
      if (cycle == 1) {
        await tester.tap(find.text('Cancelar'));
      } else {
        await tester.tap(find.text('Guardar'));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(settings.settings.websocketUrl, isEmpty);
    }
    expect(settings.settings.visionWebsocketUrl, 'ws://192.0.2.20:8765/');
    expect(vision.lastErrorCode, 'CONNECTION_REFUSED');
    expect(machine.state.isConnected, false);
    await screenshot('blanquita-vision-settings');

    await tester.ensureVisible(find.text('Abrir diagnósticos'));
    await tester.tap(find.text('Abrir diagnósticos'));
    await tester.pumpAndSettle();
    expect(find.text('ESP32 · CONTROL'), findsOneWidget);
    expect(find.text('Laptop · VISIÓN'), findsOneWidget);
    await screenshot('blanquita-diagnostics');
    await tester.ensureVisible(find.text('COPIAR BITÁCORA'));
    await tester.tap(find.text('COPIAR BITÁCORA'));
    await tester.pumpAndSettle();
    final clipboard = await Clipboard.getData('text/plain');
    expect(clipboard?.text, contains('BLANQUITA CONNECTION DIAGNOSTICS'));
    expect(clipboard?.text, contains('ERROR_CODE=CONNECTION_REFUSED'));
    expect(clipboard?.text, contains('Wi-Fi observado'));
    await screenshot('blanquita-log');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
