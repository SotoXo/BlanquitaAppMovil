import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:blanquita/app/design/blanquita_design.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/shared/widgets/blanquita/blanquita_connection_feedback.dart';
import 'package:blanquita/shared/widgets/thinking_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capture = bool.fromEnvironment('CAPTURAR_UX_CONEXION');
const _frame = ValueKey('connection-ux-frame');

Future<void> _host(
  WidgetTester tester, {
  required Future<bool> Function() check,
  required Future<void> Function() cancel,
  required ValueNotifier<String> phase,
  bool reduce = true,
  Size size = const Size(375, 812),
  double scale = 1,
  Brightness brightness = Brightness.dark,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduce);
  SharedPreferences.setMockInitialValues({'appearance.reduce_motion': reduce});
  final settings = SettingsController(
    SettingsRepository(await SharedPreferences.getInstance()),
  );
  await settings.load();
  addTearDown(settings.dispose);
  if (_capture) {
    await tester.runAsync(() async {
      for (final (family, path) in [
        ('Outfit', 'assets/fonts/Outfit-Variable.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(path))).load();
      }
    });
  }
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: RepaintBoundary(
        key: _frame,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BlanquitaDesign.build(settings.settings, brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showConnectionFeedback(
                    context,
                    device: 'Visión',
                    check: check,
                    cancel: cancel,
                    error: () =>
                        'El servicio no respondió. Revisa la conexión de la laptop.',
                    progress: phase,
                    progressMessage: () => phase.value,
                  ),
                  child: const Text('Probar conexión'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Probar conexión'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _snapshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(image.image, tester.element(find.byKey(_frame)));
    }
  });
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_frame),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/evidencias/ux-conexion/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'real phases, long wait guidance and delayed cancellation stay consistent',
    (tester) async {
      final check = Completer<bool>();
      final closing = Completer<void>();
      final phase = ValueNotifier('Buscando el servidor en la red…');
      addTearDown(phase.dispose);
      await _host(
        tester,
        check: () => check.future,
        cancel: () => closing.future,
        phase: phase,
      );
      expect(find.text('Pensando…'), findsOneWidget);
      expect(find.text(phase.value), findsOneWidget);
      phase.value = 'La laptop respondió. Esperando confirmación…';
      await tester.pump();
      expect(find.text(phase.value), findsOneWidget);
      await _snapshot(tester, '01-pensando');
      await tester.pump(const Duration(seconds: 8));
      expect(find.textContaining('Está tardando más'), findsOneWidget);
      await _snapshot(tester, '02-espera-prolongada');
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      check.complete(true);
      await tester.pump();
      expect(find.text('Cancelando…'), findsNWidgets(2));
      expect(find.text('Conectado'), findsNothing);
      closing.complete();
      await tester.pumpAndSettle();
      expect(find.text('Conectado'), findsNothing);
      expect(find.text('Probar conexión'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('unexpected check failure offers recovery and retry', (
    tester,
  ) async {
    final phase = ValueNotifier('Conectando…');
    addTearDown(phase.dispose);
    var attempts = 0;
    await _host(
      tester,
      check: () async {
        attempts++;
        if (attempts == 1) throw StateError('transport unavailable');
        return true;
      },
      cancel: () async {},
      phase: phase,
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudo conectar'), findsOneWidget);
    expect(find.text('Diagnóstico'), findsOneWidget);
    await _snapshot(tester, '03-error-recuperable');
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Conectado'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'cancel failure stays recoverable without an unhandled exception',
    (tester) async {
      final pending = Completer<bool>();
      final phase = ValueNotifier('Esperando respuesta…');
      addTearDown(phase.dispose);
      await _host(
        tester,
        check: () => pending.future,
        cancel: () async => throw StateError('close failed'),
        phase: phase,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Revisa la conexión'), findsOneWidget);
      pending.complete(true);
      await tester.pump();
      expect(find.text('Conectado'), findsNothing);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('landscape at 200% text is scrollable in ${brightness.name}', (
      tester,
    ) async {
      final pending = Completer<bool>();
      final phase = ValueNotifier(
        'Esperando la confirmación del servicio de visión de la laptop…',
      );
      addTearDown(phase.dispose);
      await _host(
        tester,
        check: () => pending.future,
        cancel: () async {},
        phase: phase,
        size: const Size(812, 375),
        scale: 2,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancelar'));
      await _snapshot(tester, '04-horizontal-${brightness.name}');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      pending.complete(false);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('thinking animation stops when system motion is reduced', (
    tester,
  ) async {
    final pending = Completer<bool>();
    final phase = ValueNotifier('Esperando respuesta…');
    addTearDown(phase.dispose);
    await _host(
      tester,
      check: () => pending.future,
      cancel: () async {},
      phase: phase,
      reduce: false,
    );
    expect(find.byType(ThinkingIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    pending.complete(false);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
