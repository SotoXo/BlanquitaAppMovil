import 'package:blanquita/core/models/machine_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/final_limits_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FinalLimitsHarness h;
  setUp(() async {
    h = FinalLimitsHarness();
    await h.setup();
  });
  tearDown(() => h.close());

  test(
    'all four fresh free readings are required, legacy data cannot arm motion',
    () async {
      await h.connect(withReadings: false);
      h.receive('SENSOR:ESTADO:P=1,F=0');
      expect(h.machine.canStartMovement, false);
      h.reading(FinalLimit.xIzquierda, false);
      h.reading(FinalLimit.xDerecha, false);
      h.reading(FinalLimit.zArriba, false);
      h.receive('SENSOR:FC:Z_ABAJO:2');
      expect(h.machine.canStartMovement, false);
      expect(h.machine.canStartSequence, false);
      h.reading(FinalLimit.zAbajo, false);
      expect(MovementDirection.values.every(h.machine.canMove), true);
      expect(h.machine.canStartSequence, true);
      expect(h.sent, isEmpty);
    },
  );

  for (final limit in FinalLimit.values) {
    test(
      '${limit.label} blocks only its own direction and legacy summary cannot override it',
      () async {
        await h.connect();
        h.reading(limit, true);
        h.receive('SENSOR:FINAL:1');
        for (final direction in MovementDirection.values) {
          expect(h.machine.canMove(direction), direction != limit.direction);
        }
        expect(h.machine.beginMovement(limit.direction), isNull);
        expect(h.sent, isEmpty);
        expect(h.machine.canStartSequence, false);
        h.reading(limit, false);
        expect(MovementDirection.values.every(h.machine.canMove), true);
        expect(h.machine.state.activeMovement, isNull);
      },
    );
  }

  test(
    'two limits on different axes leave both retreat directions available',
    () async {
      await h.connect();
      h.reading(FinalLimit.xIzquierda, true);
      h.reading(FinalLimit.zAbajo, true);
      expect(h.machine.canMove(MovementDirection.xLeft), false);
      expect(h.machine.canMove(MovementDirection.zDown), false);
      expect(h.machine.canMove(MovementDirection.xRight), true);
      expect(h.machine.canMove(MovementDirection.zUp), true);
    },
  );

  for (final axis in ['X', 'Z']) {
    test(
      'opposite limits on $axis block that axis and report a fault',
      () async {
        await h.connect();
        for (final limit in FinalLimit.values.where(
          (l) => l.direction.axis == axis,
        )) {
          h.reading(limit, true);
        }
        expect(h.machine.state.finalLimits.hasFault, true);
        expect(h.machine.state.lastStatus, contains('Fallo de sensores'));
        for (final direction in MovementDirection.values) {
          expect(h.machine.canMove(direction), direction.axis != axis);
        }
      },
    );
  }

  for (final stopFirst in [false, true]) {
    testWidgets(
      'limit during a hold, STOP first=$stopFirst, releases exactly once and retreats',
      (tester) async {
        await h.connect();
        final press = h.machine.beginMovement(MovementDirection.xLeft)!;
        await tester.pump(const Duration(milliseconds: 200));
        expect(h.sent, ['a', 'k']);
        if (stopFirst) h.receive('STOP');
        h.receive('LIMITE:FINAL_X_IZQUIERDA');
        h.reading(FinalLimit.xIzquierda, true);
        expect(h.machine.state.activeMovement, isNull);
        expect(h.machine.awaitingMovementRelease, true);
        expect(h.machine.state.sequence, SequencePhase.idle);
        await tester.pump(const Duration(seconds: 1));
        expect(h.sent, ['a', 'k']);
        expect(h.machine.beginMovement(MovementDirection.xRight), isNull);
        h.machine.releaseMovement(press);
        expect(h.sent, ['a', 'k', 'x']);
        final retreat = h.machine.beginMovement(MovementDirection.xRight)!;
        h.machine.releaseMovement(
          press,
        ); // Late or duplicate up from the old press.
        expect(h.sent, ['a', 'k', 'x', 'd']);
        expect(h.machine.state.activeMovement, MovementDirection.xRight);
        h.machine.releaseMovement(retreat);
        expect(h.sent.last, 'x');
      },
    );
  }

  testWidgets('freeing a limit while held never restarts motion or heartbeat', (
    tester,
  ) async {
    await h.connect();
    final press = h.machine.beginMovement(MovementDirection.zUp)!;
    h.reading(FinalLimit.zArriba, true);
    h.reading(FinalLimit.zArriba, false);
    await tester.pump(const Duration(seconds: 1));
    expect(h.sent, ['w']);
    expect(h.machine.canStartMovement, false);
    expect(h.machine.beginMovement(MovementDirection.zUp), isNull);
    h.machine.releaseMovement(press);
    expect(h.sent, ['w', 'x']);
    expect(h.machine.beginMovement(MovementDirection.zUp), isNotNull);
    h.machine.stopMovement();
  });

  testWidgets('an unrelated sensor does not stop retreat movement', (
    tester,
  ) async {
    await h.connect();
    h.machine.startMovement(MovementDirection.xRight);
    h.reading(FinalLimit.xIzquierda, true);
    await tester.pump(const Duration(milliseconds: 200));
    expect(h.machine.state.activeMovement, MovementDirection.xRight);
    expect(h.sent, ['d', 'k']);
    h.machine.stopMovement();
  });

  test(
    'STOP and emergency work with unknown sensors, manual lock and an axis fault',
    () async {
      await h.connect(withReadings: false);
      h.machine.setManualControlsLocked(true);
      h.machine.stopNow();
      h.machine.emergencyStop();
      h.freeLimits();
      h.reading(FinalLimit.xIzquierda, true);
      h.reading(FinalLimit.xDerecha, true);
      h.machine.stopNow();
      h.machine.emergencyStop();
      expect(h.sent, ['x', 'z', 'x', 'z']);
      expect(h.machine.canStartMovement, false);
      h.machine.setManualControlsLocked(false);
      expect(h.machine.canMove(MovementDirection.zUp), true);
      h.machine.startSequence();
      expect(h.sent, ['x', 'z', 'x', 'z']);
    },
  );

  test(
    'active sequence and active movement prevent concurrent commands',
    () async {
      await h.connect();
      final press = h.machine.beginMovement(MovementDirection.zDown)!;
      expect(h.machine.beginMovement(MovementDirection.xRight), isNull);
      h.machine.startSequence();
      expect(h.sent, ['s']);
      h.machine.releaseMovement(press);
      h.machine.startSequence();
      expect(h.sent, ['s', 'x', 'j']);
      expect(h.machine.canStartMovement, false);
      h.machine.emergencyStop();
    },
  );

  test(
    'reconnect invalidates every reading; old release cannot STOP the new socket',
    () async {
      await h.connect();
      final press = h.machine.beginMovement(MovementDirection.xLeft)!;
      h.receive('STOP');
      await h.machine.disconnect();
      expect(
        FinalLimit.values.every(
          (l) => h.machine.state.finalLimits[l] == LimitSwitchStatus.unknown,
        ),
        true,
      );
      await h.connect(withReadings: false);
      expect(h.machine.canStartMovement, false);
      h.freeLimits();
      expect(
        h.machine.canStartMovement,
        false,
        reason: 'old physical hold still needs release',
      );
      h.machine.releaseMovement(press);
      expect(h.sent, isEmpty);
      final next = h.machine.beginMovement(MovementDirection.xLeft)!;
      h.machine.releaseMovement(press);
      expect(h.sent, ['a']);
      h.machine.releaseMovement(next);
      expect(h.sent, ['a', 'x']);
    },
  );

  testWidgets(
    'inactive app stops heartbeat, clears sensors and cannot restart',
    (tester) async {
      await h.connect();
      final press = h.machine.beginMovement(MovementDirection.zDown)!;
      h.receive('STOP');
      h.machine.handleAppInactive();
      await tester.pump(const Duration(seconds: 1));
      expect(h.sent, ['s', 'x']);
      expect(h.machine.state.finalLimits.isComplete, false);
      expect(h.machine.canStartMovement, false);
      h.machine.releaseMovement(press);
      expect(h.sent, ['s', 'x']);
    },
  );

  test('unauthorized connection cannot move despite sensor messages', () async {
    final connecting = h.machine.connect();
    h.freeLimits();
    expect(h.machine.hasValidConnection, false);
    expect(h.machine.canStartMovement, false);
    h.machine.stopNow();
    h.machine.emergencyStop();
    for (final direction in MovementDirection.values) {
      expect(h.machine.startMovement(direction), false);
    }
    expect(h.sent, isEmpty);
    await h.machine.disconnect();
    await connecting;
  });

  test(
    'haptics occur only on free to active, deduplicate LIMITE and SENSOR',
    () async {
      await h.close();
      h = FinalLimitsHarness();
      await h.setup(haptics: true);
      final vibrations = <Object?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              vibrations.add(call.arguments);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await h.connect(withReadings: false);
      h.reading(FinalLimit.zArriba, true); // No known transition yet.
      expect(vibrations, isEmpty);
      h.freeLimits();
      h.receive('LIMITE:FINAL_X_IZQUIERDA');
      h.receive('LIMITE:FINAL_X_IZQUIERDA');
      h.reading(FinalLimit.xIzquierda, true);
      h.reading(FinalLimit.xIzquierda, true);
      expect(vibrations, ['HapticFeedbackType.heavyImpact']);
      h.reading(FinalLimit.xIzquierda, false);
      h.reading(FinalLimit.xIzquierda, true);
      expect(vibrations, hasLength(2));
      await h.settings.setHapticsEnabled(false);
      h.reading(FinalLimit.zAbajo, true);
      expect(vibrations, hasLength(2));
    },
  );
}
