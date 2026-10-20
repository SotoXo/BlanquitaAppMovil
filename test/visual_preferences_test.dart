import 'package:blanquita/app/app.dart';
import 'package:blanquita/app/design/blanquita_design.dart';
import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/network/wifi_network_controller.dart';
import 'package:blanquita/core/network/wifi_network_service.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/assistant/domain/alfresi_context.dart';
import 'package:blanquita/features/assistant/domain/alfresi_message.dart';
import 'package:blanquita/features/assistant/services/alfresi_rules.dart';
import 'package:blanquita/features/settings/controller/app_settings.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/domain/vision_state.dart';
import 'package:blanquita/features/vision/domain/vision_status.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/vision/support/vision_test_channel.dart';

AlfresiContext contextFor({
  MachineState machine = const MachineState(),
  VisionState vision = const VisionState(),
  bool canMove = false,
  bool locked = false,
  bool transportOpen = false,
}) => AlfresiContext(
  machine: machine,
  vision: vision,
  manualLocked: locked,
  canMove: canMove,
  transportOpen: transportOpen,
  phase: 'test',
  section: 'Control',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'visual settings persist independently from theme brightness and endpoints',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );
      final settings = SettingsController(repository);
      await settings.load();
      expect(settings.settings.visualTheme, BlanquitaVisualTheme.hamburger);
      await settings.setVisualTheme(BlanquitaVisualTheme.original);
      await settings.setVisualTheme(BlanquitaVisualTheme.hamburger);
      await settings.setThemeMode(ThemeMode.light);
      await settings.setFont(BlanquitaFont.system);
      await settings.setTextSize(BlanquitaTextSize.large);
      await settings.setDensity(BlanquitaDensity.compact);
      await settings.setCustomAccent(0xFFE5C69A);
      await settings.setShadowsEnabled(false);
      await settings.setAssistantTips(false);
      await settings.setAssistantAlerts(false);
      await settings.setAssistantTechnical(false);
      await settings.setAssistantAnimations(false);
      final reloaded = repository.load();
      expect(reloaded.visualTheme, BlanquitaVisualTheme.hamburger);
      expect(reloaded.themeMode, ThemeMode.light);
      expect(reloaded.font, BlanquitaFont.system);
      expect(reloaded.textSize, BlanquitaTextSize.large);
      expect(reloaded.density, BlanquitaDensity.compact);
      expect(reloaded.customAccent, 0xFFE5C69A);
      expect(reloaded.shadowsEnabled, false);
      expect(
        reloaded.assistantTips ||
            reloaded.assistantAlerts ||
            reloaded.assistantTechnical ||
            reloaded.assistantAnimations,
        false,
      );
      expect(reloaded.websocketUrl, isEmpty);
      expect(reloaded.visionWebsocketUrl, isEmpty);
      await settings.setVisualTheme(BlanquitaVisualTheme.original);
      expect(repository.load().visualTheme, BlanquitaVisualTheme.original);
      settings.dispose();
    },
  );
  test(
    'text preference composes with system accessibility; density keeps 48px targets',
    () {
      const system = TextScaler.linear(2);
      expect(const BlanquitaTextScaler(system, 1.2).scale(16), 38.4);
      for (final density in BlanquitaDensity.values) {
        final theme = BlanquitaDesign.build(
          AppSettings(density: density),
          Brightness.dark,
        );
        expect(
          theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
          greaterThanOrEqualTo(48),
        );
      }
    },
  );
  test('ALFRESI normal uses confirmed sensors and both ready connections', () {
    final message = AlfresiRules.explain(
      contextFor(
        machine: const MachineState(
          connection: ConnectionPhase.connected,
          finalLimitActive: false,
        ),
        vision: const VisionState(
          connection: VisionConnection.connected,
          status: VisionStatus(ready: true),
        ),
        canMove: true,
      ),
    );
    expect(message.mood, AlfresiMood.success);
    expect(message.body, contains('Final de carrera libre'));
  });
  test('ALFRESI errors retain evidence without guessing causes', () {
    final message = AlfresiRules.explain(
      contextFor(
        machine: const MachineState(
          connectionError: 'El destino rechazó la conexión.',
        ),
      ),
    );
    expect(message.mood, AlfresiMood.error);
    expect(message.body, 'El destino rechazó la conexión.');
    expect(message.body, isNot(contains('IP incorrecta')));
  });
  test(
    'ALFRESI final limit has priority over errors and never suggests movement',
    () {
      final message = AlfresiRules.explain(
        contextFor(
          machine: const MachineState(
            finalLimitActive: true,
            connectionError: 'error',
          ),
        ),
      );
      expect(message.mood, AlfresiMood.error);
      expect(message.title, 'Movimiento bloqueado por seguridad');
      expect(message.body.toLowerCase(), isNot(contains('mueve')));
    },
  );
  test('ALFRESI unknown safety never claims all clear; vision independent', () {
    final c = contextFor(
      machine: const MachineState(connection: ConnectionPhase.connected),
      canMove: true,
    );
    expect(
      AlfresiRules.explain(c).title,
      'El control del robot está disponible',
    );
    expect(c.evidence['Final de carrera'], 'Sin datos');
    final pending = contextFor(transportOpen: true);
    expect(AlfresiRules.explain(pending).mood, AlfresiMood.thinking);
    expect(pending.lockReason, contains('READY'));
  });

  testWidgets(
    'Original ↔ Hamburguesa preserves real connected controllers, route and sockets',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'connection.websocket_url': 'ws://esp32.test:81/',
        'vision.websocket_url': 'ws://laptop.test:8765/',
        'connection.auto_reconnect': false,
        'vision.auto_reconnect': false,
        'control.haptics': false,
        'ui.visualTheme': 'original',
      });
      final settings = SettingsController(
        SettingsRepository(await SharedPreferences.getInstance()),
      );
      await settings.load();
      final controlChannel = TestVisionChannel();
      final visionChannel = TestVisionChannel();
      var controlOpens = 0, visionOpens = 0;
      final machine = MachineController(
        settings,
        channelFactory: (_) {
          controlOpens++;
          return controlChannel;
        },
      );
      final vision = VisionController(
        settings,
        service: RemoteVisionService(
          channelFactory: (_) {
            visionOpens++;
            return visionChannel;
          },
        ),
      );
      final wifi = WifiNetworkController(
        service: WifiNetworkService(platformSupported: false),
      );
      await tester.pumpWidget(
        BlanquitaApp(
          settingsController: settings,
          machineController: machine,
          visionController: vision,
          wifiController: wifi,
          autoConnect: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final connecting = machine.connect();
        await vision.connect();
        await Future<void>.delayed(Duration.zero);
        controlChannel.incoming.add('READY');
        visionChannel.receive('vision.ready', DateTime.now(), {'ready': true});
        await connecting;
      });
      await tester.pumpAndSettle();
      expect(machine.state.isConnected && vision.state.ready, true);
      await tester.tap(find.text('Control').last);
      await tester.pumpAndSettle();
      final beforeCommands = List.of(controlChannel.sink.sent);
      for (final theme in [
        BlanquitaVisualTheme.hamburger,
        BlanquitaVisualTheme.original,
      ]) {
        await tester.runAsync(() => settings.setVisualTheme(theme));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(machine.state.isConnected && vision.state.ready, true);
        await tester.pumpAndSettle();
        expect(find.text('Mando seguro'), findsOneWidget);
        final element = tester.element(find.text('Mando seguro'));
        expect(element.read<MachineController>(), same(machine));
        expect(element.read<VisionController>(), same(vision));
        expect(element.read<WifiNetworkController>(), same(wifi));
        expect(controlChannel.sink.closed || visionChannel.sink.closed, false);
        expect(controlChannel.sink.sent, beforeCommands);
      }
      expect(controlOpens, 1);
      expect(visionOpens, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => controlChannel.incoming.close());
      await tester.runAsync(() => visionChannel.incoming.close());
    },
  );
}
