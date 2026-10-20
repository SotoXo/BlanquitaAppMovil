import 'dart:async';
import 'dart:convert';
import 'package:blanquita/app/design/blanquita_design.dart';
import 'package:blanquita/core/models/esp32_device.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/settings/presentation/esp32_identity_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/esp32_test_peer.dart';

class _PairingFixture {
  late SettingsController settings;
  late MachineController machine;
  final credentials = MemoryCredentials();
  final peers = <Esp32TestPeer>[];

  Future<void> load() async {
    SharedPreferences.setMockInitialValues({
      'esp32.selected_device': jsonEncode(
        const Esp32Device(
          deviceId: testDeviceId,
          name: 'BLANQUITA',
          deviceType: Esp32Device.cartesianType,
          ip: '192.168.1.40',
        ).toJson(),
      ),
      'appearance.reduce_motion': true,
      'connection.auto_reconnect': false,
      'control.haptics': false,
    });
    settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await settings.load();
    machine = MachineController(
      settings,
      credentialStore: credentials,
      channelFactory: (_) {
        final peer = Esp32TestPeer();
        peers.add(peer);
        return peer;
      },
    );
  }

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: machine),
        ],
        child: MaterialApp(
          theme: BlanquitaDesign.build(settings.settings, Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Esp32IdentityPanel(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Vincular'));
    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField), testSecret);
    await tester.tap(find.text('Vincular').last);
    await tester.pumpAndSettle();
  }

  Future<void> until(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 60 && !condition(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(condition(), isTrue);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    machine.dispose();
    settings.dispose();
    for (final peer in peers) {
      await tester.runAsync(() => peer.incoming.close());
    }
  }
}

void main() {
  testWidgets('pairing reports success only after secure storage completes', (
    tester,
  ) async {
    final f = _PairingFixture();
    await f.load();
    final writing = Completer<void>();
    f.credentials.writeBarrier = writing;
    await f.show(tester);
    await f.submit(tester);
    await f.until(tester, () => f.peers.isNotEmpty && f.peers.last.authorized);
    expect(find.text('Conectando con ESP32'), findsOneWidget);
    expect(find.text('Conectado'), findsNothing);
    writing.complete();
    await f.until(tester, () => f.machine.hasValidConnection);
    await tester.pumpAndSettle();
    expect(find.text('Conectado'), findsOneWidget);
    expect(f.credentials.values[testDeviceId], testSecret);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await f.close(tester);
  });

  testWidgets(
    'pairing storage failure provides retry instead of false success',
    (tester) async {
      final f = _PairingFixture();
      await f.load();
      f.credentials.failWrites = true;
      await f.show(tester);
      await f.submit(tester);
      await f.until(tester, () => f.machine.lastError != null);
      await tester.pumpAndSettle();
      expect(find.text('No se pudo conectar'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(f.machine.hasValidConnection, isFalse);
      expect(f.credentials.values, isEmpty);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await f.close(tester);
    },
  );

  testWidgets(
    'cancelling pairing during storage discards the late credential',
    (tester) async {
      final f = _PairingFixture();
      await f.load();
      final writing = Completer<void>();
      f.credentials.writeBarrier = writing;
      await f.show(tester);
      await f.submit(tester);
      await f.until(
        tester,
        () => f.peers.isNotEmpty && f.peers.last.authorized,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      writing.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conectado'), findsNothing);
      expect(f.credentials.values, isEmpty);
      expect(f.machine.hasValidConnection, isFalse);
      expect(tester.takeException(), isNull);
      await f.close(tester);
    },
  );
}
