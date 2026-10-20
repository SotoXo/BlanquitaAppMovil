import 'package:blanquita/app/theme/app_theme.dart';
import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/control/presentation/control_screen.dart';
import 'package:blanquita/features/control/widgets/hold_to_move_button.dart';
import 'package:blanquita/features/diagnostics/presentation/diagnostics_screen.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/final_limits_harness.dart';

Finder button(MovementDirection direction) => find.byWidgetPredicate(
  (widget) => widget is HoldToMoveButton && widget.movement == direction,
);

Widget app(
  FinalLimitsHarness h, {
  ThemeMode theme = ThemeMode.dark,
  Widget? child,
  VisionController? vision,
  double scale = 1,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<MachineController>.value(value: h.machine),
    ChangeNotifierProvider<SettingsController>.value(value: h.settings),
    if (vision != null)
      ChangeNotifierProvider<VisionController>.value(value: vision),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child ?? const Scaffold(body: ControlScreen()),
  ),
);

void main() {
  late FinalLimitsHarness h;
  setUp(() async {
    h = FinalLimitsHarness();
    await h.setup();
  });
  tearDown(() => h.close());

  for (final limit in FinalLimit.values) {
    testWidgets(
      '${limit.label} turns only its button red, locks accessibly and restores on release',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await h.connect();
        await tester.pumpWidget(app(h));
        h.reading(limit, true);
        await tester.pump();
        for (final direction in MovementDirection.values) {
          final widget = tester.widget<HoldToMoveButton>(button(direction));
          expect(widget.limitBlocked, direction == limit.direction);
          expect(widget.enabled, direction != limit.direction);
        }
        final locked = button(limit.direction);
        expect(
          find.descendant(
            of: locked,
            matching: find.byIcon(Icons.lock_rounded),
          ),
          findsOneWidget,
        );
        final widget = tester.widget<HoldToMoveButton>(locked);
        final arrow = tester.widget<Icon>(
          find.descendant(of: locked, matching: find.byIcon(widget.icon)),
        );
        expect(arrow.color, AppColors.danger);
        expect(
          find.bySemanticsLabel(
            '${widget.label}. Bloqueada por final de carrera.',
          ),
          findsOneWidget,
        );
        expect(find.text(limit.retreatMessage), findsOneWidget);
        await tester.tap(locked);
        expect(h.sent, isEmpty);
        h.reading(limit, false);
        await tester.pump();
        expect(tester.widget<HoldToMoveButton>(locked).enabled, true);
        expect(
          find.descendant(
            of: locked,
            matching: find.byIcon(Icons.lock_rounded),
          ),
          findsNothing,
        );
        expect(
          h.sent,
          isEmpty,
          reason: 'clearing a limit never moves on its own',
        );
        final gesture = await tester.startGesture(tester.getCenter(locked));
        expect(h.sent, [limit.direction.command]);
        await gesture.up();
        expect(h.sent, [limit.direction.command, 'x']);
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'STOP before LIMITE retains the pointer, blocks multitouch and sends x on up',
    (tester) async {
      await h.connect();
      await tester.pumpWidget(app(h));
      final first = await tester.startGesture(
        tester.getCenter(button(MovementDirection.xLeft)),
        pointer: 1,
      );
      await tester.pump();
      h.receive('STOP');
      h.receive('LIMITE:FINAL_X_IZQUIERDA');
      h.reading(FinalLimit.xIzquierda, true);
      await tester.pump();
      final second = await tester.startGesture(
        tester.getCenter(button(MovementDirection.xRight)),
        pointer: 2,
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(h.sent, ['a']);
      h.reading(FinalLimit.xIzquierda, false);
      await tester.pump();
      expect(h.sent, ['a']);
      await first.up();
      await tester.pump();
      expect(h.sent, ['a', 'x']);
      expect(h.machine.state.activeMovement, isNull);
      // The second finger was rejected and cannot start when the first lifts.
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.sent, ['a', 'x']);
      await second.up();
      final next = await tester.startGesture(
        tester.getCenter(button(MovementDirection.xRight)),
        pointer: 3,
      );
      expect(h.sent, ['a', 'x', 'd']);
      await next.up();
      expect(h.sent, ['a', 'x', 'd', 'x']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pointer cancel and widget removal each safely release after STOP',
    (tester) async {
      await h.connect();
      await tester.pumpWidget(app(h));
      final gesture = await tester.startGesture(
        tester.getCenter(button(MovementDirection.zUp)),
      );
      h.receive('STOP');
      await gesture.cancel();
      expect(h.sent, ['w', 'x']);
      await tester.pump();
      await tester.startGesture(
        tester.getCenter(button(MovementDirection.zUp)),
        pointer: 2,
      );
      h.receive('STOP');
      await tester.pumpWidget(const SizedBox());
      expect(h.sent, ['w', 'x', 'w', 'x']);
    },
  );

  testWidgets(
    'unknown sensors disable movement while central STOP and emergency remain usable',
    (tester) async {
      await h.connect(withReadings: false);
      await tester.pumpWidget(app(h));
      expect(
        tester
            .widgetList<HoldToMoveButton>(find.byType(HoldToMoveButton))
            .every((b) => !b.enabled),
        true,
      );
      expect(find.text('Sin datos'), findsNWidgets(4));
      await tester.tap(find.text('STOP'));
      await tester.ensureVisible(find.text('DETENER'));
      await tester.tap(find.text('DETENER'));
      expect(h.sent, ['x', 'z']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'diagnostics retain transport and Vision details alongside four unknown and incoherent readings',
    (tester) async {
      await h.connect(withReadings: false);
      final vision = VisionController(h.settings);
      await tester.pumpWidget(
        app(h, child: const DiagnosticsScreen(), vision: vision),
      );
      expect(find.text('Finales de carrera'), findsOneWidget);
      expect(find.text('Canal WebSocket ESP32'), findsOneWidget);
      for (final limit in FinalLimit.values) {
        expect(find.text(limit.label), findsOneWidget);
      }
      h.freeLimits();
      h.reading(FinalLimit.xIzquierda, true);
      h.reading(FinalLimit.xDerecha, true);
      await tester.pump();
      expect(
        find.textContaining('Fallo de sensores del eje X'),
        findsOneWidget,
      );
      expect(find.text('Vision Server'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vision.dispose();
    },
  );

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    for (final width in [320.0, 390.0]) {
      testWidgets(
        'control has no overflow at width $width, $theme and enlarged text',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 740));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await h.connect(withReadings: false);
          await tester.pumpWidget(app(h, theme: theme, scale: 1.3));
          expect(tester.takeException(), isNull);
          h.freeLimits();
          await tester.pump();
          expect(tester.takeException(), isNull);
          h.reading(FinalLimit.xIzquierda, true);
          h.reading(FinalLimit.xDerecha, true);
          h.reading(FinalLimit.zArriba, true);
          await tester.pump();
          await tester.ensureVisible(find.text('DETENER'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
