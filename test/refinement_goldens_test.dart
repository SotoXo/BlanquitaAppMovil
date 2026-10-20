import 'package:blanquita/app/navigation/main_shell.dart';
import 'package:blanquita/features/settings/controller/app_settings.dart';
import 'package:blanquita/features/assistant/presentation/alfresi_panel.dart';
import 'package:blanquita/app/navigation/glass_navigation_bar.dart';
import 'package:blanquita/core/diagnostics/connection_log.dart';
import 'package:blanquita/core/network/wifi_network_controller.dart';
import 'package:blanquita/core/network/wifi_network_service.dart';
import 'package:blanquita/features/diagnostics/presentation/diagnostics_screen.dart';
import 'package:blanquita/features/settings/presentation/settings_screen.dart';
import 'package:blanquita/features/settings/presentation/theme_visual_screen.dart';
import 'package:blanquita/shared/widgets/blanquita/blanquita_modal.dart';
import 'package:blanquita/shared/widgets/blanquita/blanquita_lock_state.dart';
import 'package:blanquita/features/control/presentation/control_screen.dart';
import 'package:blanquita/features/vision/presentation/vision_screen.dart';
import 'package:blanquita/features/devices/presentation/devices_screen.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:blanquita/app/design/blanquita_design.dart';
import 'package:blanquita/app/navigation/blanquita_bottom_navigation.dart';
import 'package:blanquita/app/presentation/blanquita_splash.dart';
import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/dashboard/presentation/dashboard_screen.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/domain/vision_state.dart';
import 'package:blanquita/features/vision/domain/vision_status.dart';
import 'package:blanquita/shared/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const capture = bool.fromEnvironment('CAPTURAR_REFINAMIENTO');
const firstPass = bool.fromEnvironment('PRIMERA_ITERACION');
const frame = ValueKey('refinement-frame');
final fixedTime = DateTime(2026, 10, 20, 10, 42, 15);

/// Presentation fixtures only. These doubles never replace production controllers.
class VisualMachine extends MachineController {
  VisualMachine(super.settings);
  bool locked = false;
  @override
  MachineState get state => MachineState(
    connection: ConnectionPhase.connected,
    finalLimitActive: locked,
    plateDetected: false,
    gripper: GripperState.closed,
    lastStatus: locked ? 'Final de carrera activo' : 'READY confirmado',
    lastReceivedAt: fixedTime,
  );
  @override
  String get connectionStatusLabel => 'Conectado';
  @override
  bool get canStartMovement => !locked;
  @override
  bool get protocolReady => true;
  @override
  bool get transportOpen => true;
  @override
  String get phase => 'connected';
  @override
  List<MachineEvent> get events => [
    MachineEvent(
      timestamp: fixedTime,
      message: 'ESP32 conectado',
      level: MachineEventLevel.success,
    ),
  ];
}

class VisualVision extends VisionController {
  VisualVision(super.settings);
  @override
  VisionState get state => const VisionState(
    connection: VisionConnection.connected,
    status: VisionStatus(ready: true),
  );
  @override
  bool get transportOpen => true;
}

Future<void> captureScreen(
  WidgetTester tester,
  String name,
  Widget screen, {
  Size viewport = const Size(390, 844),
  double textScale = 1,
  bool golden = true,
  bool motion = false,
  Future<void> Function(WidgetTester, SettingsController)? inspect,
  BlanquitaVisualTheme visualTheme = BlanquitaVisualTheme.hamburger,
}) async {
  if (motion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({
    'ui.visualTheme': visualTheme.name,
    'appearance.reduce_motion': !motion,
    'connection.websocket_url': 'ws://esp32.test:81/',
    'vision.websocket_url': 'ws://laptop.test:8765/',
  });
  final settings = SettingsController(
    SettingsRepository(await SharedPreferences.getInstance()),
  );
  await settings.load();
  final machine = VisualMachine(settings);
  final vision = VisualVision(settings);
  final wifi = WifiNetworkController(
    service: WifiNetworkService(platformSupported: false),
  );
  await tester.runAsync(() async {
    for (final (family, path) in [
      ('Outfit', 'assets/fonts/Outfit-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      (
        'packages/cupertino_icons/CupertinoIcons',
        'packages/cupertino_icons/assets/CupertinoIcons.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<MachineController>.value(value: machine),
        ChangeNotifierProvider<VisionController>.value(value: vision),
        ChangeNotifierProvider<WifiNetworkController>.value(value: wifi),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BlanquitaDesign.build(settings.settings, Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: frame,
          child: AppBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: screen,
              bottomNavigationBar:
                  ![
                    '02-inicio',
                    '03-dispositivos',
                    '05-control',
                    '06-vision',
                    '08-ajustes',
                  ].contains(name)
                  ? null
                  : visualTheme == BlanquitaVisualTheme.original
                  ? GlassNavigationBar(index: 0, onSelected: (_) {})
                  : BlanquitaBottomNavigation(
                      index: switch (name) {
                        '03-dispositivos' => 4,
                        '05-control' => 1,
                        '06-vision' => 2,
                        '08-ajustes' => 3,
                        _ => 0,
                      },
                      onSelected: (_) {},
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/alfresi/referencia_frutilla.png'),
      tester.element(find.byKey(frame)),
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/alfresi/fondo_hamburguesa.png'),
      tester.element(find.byKey(frame)),
    ),
  );
  if (inspect != null) await inspect(tester, settings);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  if (capture && golden) {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(frame),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = firstPass
          ? 'docs/evidencias/ui-final/iteracion-1'
          : 'docs/evidencias/ui-final';
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }
  if (!firstPass && golden) {
    await expectLater(
      find.byKey(frame),
      matchesGoldenFile('goldens/hamburguesa/$name.png'),
    );
  }
  await tester.pumpWidget(const SizedBox());
  machine.dispose();
  vision.dispose();
  wifi.dispose();
  settings.dispose();
}

class VisualLog extends ConnectionLog {
  @override
  List<ConnectionLogEntry> get entries => [
    ConnectionLogEntry(
      timestamp: fixedTime,
      channel: ConnectionChannel.control,
      level: ConnectionLogLevel.success,
      humanMessage: 'ESP32 conectado',
      technicalMessage: 'READY recibido',
      phase: 'connected',
    ),
    ConnectionLogEntry(
      timestamp: fixedTime.subtract(const Duration(seconds: 1)),
      channel: ConnectionChannel.vision,
      level: ConnectionLogLevel.success,
      humanMessage: 'Visión disponible',
      technicalMessage: 'vision.ready confirmado',
      phase: 'ready',
    ),
  ];
}

void main() {
  testWidgets(
    'theme preview applies explicitly and keeps route, controllers, connections and log',
    (tester) async {
      await captureScreen(
        tester,
        'apply',
        const ThemeVisualScreen(),
        golden: false,
        inspect: (tester, settings) async {
          final element = tester.element(find.byKey(frame));
          final machine = element.read<MachineController>();
          final vision = element.read<VisionController>();
          final route = ModalRoute.of(element);
          final events = ConnectionLog.shared.entries.length;
          for (final (label, theme) in [
            ('Original', BlanquitaVisualTheme.original),
            ('Hamburguesa', BlanquitaVisualTheme.hamburger),
            ('Original', BlanquitaVisualTheme.original),
          ]) {
            final before = settings.settings.visualTheme;
            await tester.tap(find.text(label));
            await tester.pump();
            expect(settings.settings.visualTheme, before);
            await tester.tap(find.text('Aplicar tema'));
            await tester.pumpAndSettle();
            expect(settings.settings.visualTheme, theme);
            expect(element.read<MachineController>(), same(machine));
            expect(element.read<VisionController>(), same(vision));
            expect(machine.state.isConnected, isTrue);
            expect(vision.state.ready, isTrue);
            expect(ModalRoute.of(element), same(route));
            expect(ConnectionLog.shared.entries.length, events);
          }
        },
      );
    },
  );

  testWidgets('rain animates and Reduce Motion stops decorative frames', (
    tester,
  ) async {
    await captureScreen(
      tester,
      'motion',
      const SizedBox(),
      golden: false,
      motion: true,
      inspect: (tester, settings) async {
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        await tester.runAsync(() => settings.setReduceMotion(true));
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  });

  testWidgets(
    'golden ALFRESI abierto',
    (tester) => captureScreen(
      tester,
      '14-alfresi-abierto',
      const Center(child: AlfresiPanel(section: 'Inicio')),
    ),
  );
  testWidgets(
    'golden Inicio Original',
    (tester) => captureScreen(
      tester,
      '02-inicio-original',
      const MainShell(),
      visualTheme: BlanquitaVisualTheme.original,
    ),
  );

  testWidgets(
    'golden Diagnósticos',
    (tester) => captureScreen(
      tester,
      '07-diagnosticos',
      DiagnosticsScreen(initialView: 2, journal: VisualLog()),
    ),
  );
  testWidgets(
    'golden Ajustes',
    (tester) => captureScreen(tester, '08-ajustes', const SettingsScreen()),
  );
  testWidgets(
    'golden Tema Visual',
    (tester) =>
        captureScreen(tester, '09-tema-visual', const ThemeVisualScreen()),
  );
  for (final (type, name, title, message) in [
    (
      BlanquitaModalType.error,
      '10-modal-error',
      'No se pudo conectar',
      'La comunicación no pudo completarse. Revisa los detalles del diagnóstico.',
    ),
    (
      BlanquitaModalType.success,
      '11-modal-success',
      'ESP32 conectado',
      'El dispositivo confirmó READY. El control está disponible.',
    ),
    (
      BlanquitaModalType.loading,
      '12-modal-waiting',
      'Esperando confirmación',
      'Estamos esperando la respuesta READY del dispositivo.',
    ),
  ]) {
    testWidgets(
      'golden $name',
      (tester) => captureScreen(
        tester,
        name,
        Center(
          child: BlanquitaModal(
            type: type,
            title: title,
            message: message,
            actions: [
              if (type == BlanquitaModalType.error)
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Ver diagnóstico'),
                ),
              FilledButton(
                onPressed: () {},
                child: Text(
                  type == BlanquitaModalType.loading
                      ? 'Cancelar'
                      : type == BlanquitaModalType.error
                      ? 'Reintentar'
                      : 'Continuar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  testWidgets(
    'golden Bloqueo',
    (tester) => captureScreen(
      tester,
      '13-control-bloqueado',
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BlanquitaLockState(
            reason:
                'Final de carrera activo. Movimiento bloqueado por seguridad.',
            critical: true,
            onDiagnostic: () {},
          ),
        ),
      ),
    ),
  );

  for (final (size, scale) in [
    (const Size(360, 800), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(412, 915), 1.0),
    (const Size(800, 1100), 1.0),
    (const Size(844, 390), 1.0),
    (const Size(360, 800), 2.0),
    (const Size(844, 390), 2.0),
  ]) {
    testWidgets(
      'new views responsive ${size.width}x${size.height} text $scale',
      (tester) async {
        for (final view in [
          const BlanquitaSplash(),
          const DevicesScreen(),
          const BindingScreen(),
          const ThemeVisualScreen(),
          const Center(
            child: BlanquitaModal(
              type: BlanquitaModalType.error,
              title: 'No se pudo conectar',
              message: 'Revisa el diagnóstico.',
            ),
          ),
        ]) {
          await captureScreen(
            tester,
            'responsive',
            view,
            viewport: size,
            textScale: scale,
            golden: false,
          );
        }
      },
    );
  }
  testWidgets(
    'golden Control',
    (tester) => captureScreen(tester, '05-control', const ControlScreen()),
  );
  testWidgets(
    'golden Visión',
    (tester) => captureScreen(tester, '06-vision', const VisionScreen()),
  );
  testWidgets(
    'golden Splash',
    (tester) => captureScreen(tester, '01-splash', const BlanquitaSplash()),
  );
  testWidgets(
    'golden Dispositivos',
    (tester) => captureScreen(tester, '03-dispositivos', const DevicesScreen()),
  );
  testWidgets(
    'golden Vinculación',
    (tester) => captureScreen(tester, '04-vinculacion', const BindingScreen()),
  );
  testWidgets(
    'golden Inicio',
    (tester) => captureScreen(tester, '02-inicio', const DashboardScreen()),
  );
}
