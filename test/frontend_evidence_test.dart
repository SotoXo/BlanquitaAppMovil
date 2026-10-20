import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:blanquita/app/app.dart';
import 'package:blanquita/core/network/wifi_network_controller.dart';
import 'package:blanquita/core/network/wifi_network_service.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/assistant/presentation/alfresi_avatar.dart';
import 'package:blanquita/features/assistant/domain/alfresi_message.dart';
import 'package:blanquita/features/control/presentation/control_screen.dart';
import 'package:blanquita/features/dashboard/presentation/dashboard_screen.dart';
import 'package:blanquita/features/settings/controller/app_settings.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/settings/presentation/settings_screen.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/presentation/vision_screen.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'package:blanquita/shared/widgets/blanquita/blanquita_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/vision/support/vision_test_channel.dart';

const _capture = bool.fromEnvironment('GENERAR_EVIDENCIAS');
const _boundary = ValueKey('flutter-evidence');

Future<void> snapshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/evidencias/ui/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

class _Fixture {
  late SettingsController settings;
  late MachineController machine;
  late VisionController vision;
  final control = TestVisionChannel();
  final camera = TestVisionChannel();
  late WifiNetworkController wifi;
  Future<void> load() async {
    SharedPreferences.setMockInitialValues({
      'connection.websocket_url': 'ws://esp32.test:81/',
      'vision.websocket_url': 'ws://laptop.test:8765/',
      'connection.auto_reconnect': false,
      'vision.auto_reconnect': false,
      'ui.visualTheme': 'original',
      'control.haptics': false,
      'appearance.reduce_motion': true,
    });
    settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await settings.load();
    machine = MachineController(settings, channelFactory: (_) => control);
    vision = VisionController(
      settings,
      service: RemoteVisionService(channelFactory: (_) => camera),
      tickInterval: const Duration(days: 1),
    );
    wifi = WifiNetworkController(
      service: WifiNetworkService(platformSupported: false),
      sampleInterval: const Duration(days: 1),
    );
  }

  Widget app() => RepaintBoundary(
    key: _boundary,
    child: BlanquitaApp(
      settingsController: settings,
      machineController: machine,
      visionController: vision,
      wifiController: wifi,
      autoConnect: false,
    ),
  );
  Future<void> connect(WidgetTester tester) async {
    await tester.runAsync(() async {
      final connecting = machine.connect();
      await vision.connect();
      await Future<void>.delayed(Duration.zero);
      control.incoming.add('READY');
      camera.receive('vision.ready', DateTime.now(), {'ready': true});
      await connecting;
    });
    await tester.pumpAndSettle();
    expect(machine.protocolReady && vision.state.ready, true);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    unawaited(control.incoming.close());
    unawaited(camera.incoming.close());
  }
}

void main() {
  testWidgets(
    'real Flutter renders all required screens, modal states and assistant',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final font = FontLoader('Outfit')
        ..addFont(rootBundle.load('assets/fonts/Outfit-Variable.ttf'));
      await tester.runAsync(() async {
        await font.load();
        final material = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons')
          ..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          );
        await material.load();
        await cupertino.load();
      });
      final f = _Fixture();
      await tester.runAsync(() => f.load());
      await tester.pumpWidget(f.app());
      await tester.pumpAndSettle();
      await snapshot(tester, '01-inicio-original');
      await tester.runAsync(
        () => f.settings.setVisualTheme(BlanquitaVisualTheme.hamburger),
      );
      await tester.pumpAndSettle();
      await snapshot(tester, '02-inicio-hamburguesa');
      await snapshot(tester, '12-alfresi-cerrado');
      await tester.tap(find.byTooltip('Abrir ALFRESI').first);
      await tester.pumpAndSettle();
      expect(find.text('¿Por qué?'), findsOneWidget);
      await snapshot(tester, '13-alfresi-abierto');
      await tester.tap(find.byTooltip('Cerrar ALFRESI'));
      await tester.pumpAndSettle();
      await f.connect(tester);
      await tester.tap(find.text('Control').last);
      await tester.pumpAndSettle();
      expect(find.text('DETENCIÓN INMEDIATA').hitTestable(), findsOneWidget);
      await snapshot(tester, '03-control-hamburguesa');
      await tester.tap(find.text('Visión').last);
      await tester.pumpAndSettle();
      await snapshot(tester, '04-vision-hamburguesa');
      await tester.tap(find.text('Ajustes').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-original')));
      await tester.pumpAndSettle();
      expect(f.settings.settings.visualTheme, BlanquitaVisualTheme.original);
      await tester.tap(find.byKey(const ValueKey('theme-hamburger')));
      await tester.pumpAndSettle();
      expect(f.settings.settings.visualTheme, BlanquitaVisualTheme.hamburger);
      await snapshot(tester, '05-ajustes-hamburguesa');
      await snapshot(tester, '11-selector-tema');
      await tester.ensureVisible(find.text('Probar conexión ESP32'));
      await tester.tap(find.text('Probar conexión ESP32'));
      await tester.pumpAndSettle();
      expect(find.text('Conectado'), findsOneWidget);
      await snapshot(tester, '15-modal-prueba-conexion');
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Abrir diagnósticos'));
      await tester.tap(find.text('Abrir diagnósticos'));
      await tester.pumpAndSettle();
      await snapshot(tester, '06-diagnosticos-hamburguesa');
      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();
      expect(find.text('COPIAR BITÁCORA'), findsOneWidget);
      await snapshot(tester, '14-diagnosticos-logs');
      await tester.pageBack();
      await tester.pumpAndSettle();
      for (final (type, name, title, message) in [
        (
          BlanquitaModalType.success,
          '07-modal-exito',
          'Conectado',
          'ESP32 confirmó READY. La conexión está disponible.',
        ),
        (
          BlanquitaModalType.error,
          '08-modal-error',
          'No se pudo conectar',
          'El dispositivo no confirmó READY. Consulta el diagnóstico para revisar la fase observada.',
        ),
        (
          BlanquitaModalType.loading,
          '09-modal-proceso',
          'Procesando',
          'Estamos esperando la respuesta del dispositivo.',
        ),
      ]) {
        final context = tester.element(find.byType(SettingsScreen));
        unawaited(
          BlanquitaModal.show<void>(
            context,
            type: type,
            title: title,
            message: message,
            actions: (context) => [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(title), findsOneWidget);
        await snapshot(tester, name);
        await tester.tap(find.text('Cerrar'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Control').last);
      await tester.pumpAndSettle();
      f.machine.setManualControlsLocked(true);
      await tester.pumpAndSettle();
      expect(find.text('Control bloqueado'), findsOneWidget);
      await snapshot(tester, '10-bloqueo');
      expect(tester.takeException(), isNull);
      await f.close(tester);
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(800, 1024),
    const Size(844, 390),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'responsive ${size.width}×${size.height}, text ${textScale * 100}%',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(() {
            tester.platformDispatcher.clearTextScaleFactorTestValue();
            return tester.binding.setSurfaceSize(null);
          });
          final previousError = FlutterError.onError;
          FlutterError.onError = (details) {
            debugPrint(details.toString());
            previousError?.call(details);
          };
          addTearDown(() => FlutterError.onError = previousError);
          final f = _Fixture();
          await tester.runAsync(() => f.load());
          await tester.runAsync(
            () => f.settings.setVisualTheme(BlanquitaVisualTheme.hamburger),
          );
          await tester.runAsync(
            () => f.settings.setDensity(BlanquitaDensity.large),
          );
          await tester.runAsync(
            () => f.settings.setTextSize(BlanquitaTextSize.large),
          );
          await tester.pumpWidget(f.app());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final (label, screen) in [
            ('Inicio', DashboardScreen),
            ('Control', ControlScreen),
            ('Visión', VisionScreen),
            ('Ajustes', SettingsScreen),
          ]) {
            if (label != 'Inicio') {
              await tester.tap(find.byKey(ValueKey('nav-$label')));
              await tester.pumpAndSettle();
            }
            final scroll = find
                .descendant(
                  of: find.byType(screen),
                  matching: find.byType(SingleChildScrollView),
                )
                .first;
            final scrollable = tester.state<ScrollableState>(
              find
                  .descendant(of: scroll, matching: find.byType(Scrollable))
                  .first,
            );
            final max = scrollable.position.maxScrollExtent;
            for (double position = 0; position <= max + 200; position += 250) {
              scrollable.position.jumpTo(position.clamp(0, max));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$label at scroll $position',
              );
            }
            if (label == 'Ajustes') {
              await tester.ensureVisible(find.text('Abrir diagnósticos'));
              await tester.tap(find.text('Abrir diagnósticos'));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await tester.pageBack();
              await tester.pumpAndSettle();
            }
          }
          await snapshot(
            tester,
            'responsive-${size.width.toInt()}-${size.height.toInt()}-${(textScale * 100).toInt()}',
          );
          await f.close(tester);
        },
      );
    }
  }

  testWidgets('render local ALFRESI assets for all moods', (tester) async {
    for (final mood in AlfresiMood.values) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: _boundary,
          child: CustomPaint(
            painter: AlfresiAvatarPainter(mood),
            child: const SizedBox(width: 256, height: 256),
          ),
        ),
      );
      await tester.pump();
      if (_capture) {
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          AlfresiAvatarPainter(
            mood,
          ).paint(Canvas(recorder), const Size(256, 256));
          final image = await recorder.endRecording().toImage(256, 256);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('assets/alfresi/alfresi_${mood.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
