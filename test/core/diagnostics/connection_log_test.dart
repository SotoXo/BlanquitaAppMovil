import 'package:blanquita/core/diagnostics/connection_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bounded chronological export redacts credentials and query secrets',
    () {
      final log = ConnectionLog();
      for (var index = 0; index <= ConnectionLog.capacity; index++) {
        log.add(
          channel: ConnectionChannel.control,
          humanMessage: 'Evento $index',
          technicalMessage:
              'ws://user:private@robot:81/path?token=secret#fragment',
          endpoint: 'http://user:private@invalid:81/?token=secret',
        );
      }
      expect(log.entries.length, ConnectionLog.capacity);
      final text = log.export(
        control: {'Endpoint': 'ws://user:private@robot:81/?token=secret'},
      );
      expect(text, contains('BLANQUITA CONNECTION DIAGNOSTICS'));
      expect(text, isNot(contains('private')));
      expect(text, isNot(contains('secret')));
      expect(
        text.indexOf('Evento 1\n'),
        lessThan(text.indexOf('Evento 240\n')),
      );
      log.dispose();
    },
  );

  testWidgets(
    'recording a framework event during build does not notify the tree synchronously',
    (tester) async {
      final log = ConnectionLog();
      var notifyCount = 0;
      log.addListener(() => notifyCount++);
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: log,
            builder: (context, _) {
              if (log.entries.isEmpty) {
                log.add(
                  channel: ConnectionChannel.system,
                  humanMessage: 'Error de interfaz preservado',
                  errorCode: 'FLUTTER_FRAMEWORK_ERROR',
                );
                expect(notifyCount, 0);
              }
              return Text('${log.entries.length} eventos');
            },
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(notifyCount, 1);
      expect(find.text('1 eventos'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      log.dispose();
    },
  );
}
