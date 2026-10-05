import 'package:blanquita/app/app.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
    expect(find.text('Cámara no configurada'), findsOneWidget);

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
}
