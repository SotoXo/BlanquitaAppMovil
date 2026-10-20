import 'dart:async';
import 'package:blanquita/app/design/blanquita_design.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/domain/vision_state.dart';
import 'package:blanquita/features/vision/domain/vision_status.dart';
import 'package:blanquita/features/vision/presentation/vision_overview.dart';
import 'package:blanquita/shared/widgets/thinking_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Presentation fixture; protocol and transport have their own integration tests.
class _RecoveryVision extends VisionController {
  _RecoveryVision(super.settings);
  final response = Completer<void>();
  var attempts = 0;
  bool pending = false;
  VisionState current = const VisionState(
    connection: VisionConnection.error,
    error: 'La laptop no respondió. Comprueba la red.',
  );
  @override
  VisionState get state => current;
  @override
  bool get isConnecting => pending;
  @override
  VisionNetworkPhase get networkPhase => pending
      ? VisionNetworkPhase.waitingReady
      : current.ready
      ? VisionNetworkPhase.ready
      : VisionNetworkPhase.error;
  @override
  Future<void> reconnect() async {
    attempts++;
    pending = true;
    current = const VisionState(connection: VisionConnection.connecting);
    notifyListeners();
    await response.future;
    pending = false;
    current = const VisionState(
      connection: VisionConnection.connected,
      status: VisionStatus(ready: true),
    );
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'vision errors and recovery remain visible with assistant disabled',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ui.assistantEnabled': false,
        'appearance.reduce_motion': true,
      });
      final settings = SettingsController(
        SettingsRepository(await SharedPreferences.getInstance()),
      );
      await settings.load();
      final vision = _RecoveryVision(settings);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider<VisionController>.value(value: vision),
          ],
          child: MaterialApp(
            theme: BlanquitaDesign.build(settings.settings, Brightness.dark),
            home: const Scaffold(body: VisionOverview()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('La laptop no respondió. Comprueba la red.').hitTestable(),
        findsWidgets,
      );
      await tester.tap(find.text('Reintentar conexión'));
      await tester.pumpAndSettle();
      expect(vision.attempts, 1);
      expect(find.text('Conectando con Visión'), findsOneWidget);
      expect(find.byType(ThinkingIndicator), findsWidgets);
      expect(find.text('Conectado'), findsNothing);
      vision.response.complete();
      await tester.pumpAndSettle();
      expect(find.text('Conectado'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar conexión'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vision.dispose();
      settings.dispose();
    },
  );
}
