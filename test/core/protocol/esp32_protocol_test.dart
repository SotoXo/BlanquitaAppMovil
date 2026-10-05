import 'package:blanquita/core/protocol/esp32_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = Esp32MessageParser();

  test('existing command payloads remain unchanged', () {
    expect(Esp32Command.values.map((command) => command.payload), [
      'a',
      'd',
      'w',
      's',
      'x',
      'k',
      'q',
      'e',
      'j',
      'z',
      '+',
      '-',
    ]);
  });

  test('existing safety messages remain unchanged', () {
    expect(parser.parse('READY').type, Esp32MessageType.ready);
    expect(parser.parse('STOP').type, Esp32MessageType.stopped);
    expect(parser.parse('STOP_TIMEOUT').type, Esp32MessageType.stopTimeout);
    expect(parser.parse('CANCELADO').type, Esp32MessageType.cancelled);
  });

  group('Esp32MessageParser', () {
    test('accepts both sequence-start variants', () {
      expect(
        parser.parse('SECUENCIA:INICIADA').type,
        Esp32MessageType.sequenceStarted,
      );
      expect(
        parser.parse('SECUENCIA_INICIADA').type,
        Esp32MessageType.sequenceStarted,
      );
    });

    test('parses a sequence step without exposing protocol formatting', () {
      final message = parser.parse('SECUENCIA:4:X_DERECHA');

      expect(message.type, Esp32MessageType.sequenceStep);
      expect(message.sequenceStep, 4);
      expect(message.detail, 'X derecha');
    });

    test('parses individual sensor messages', () {
      final plate = parser.parse('SENSOR:PLATO:1');
      final limit = parser.parse('SENSOR:FINAL:0');

      expect(plate.type, Esp32MessageType.plateSensor);
      expect(plate.booleanValue, isTrue);
      expect(limit.type, Esp32MessageType.finalLimitSensor);
      expect(limit.booleanValue, isFalse);
    });

    test('parses the combined sensor snapshot', () {
      final message = parser.parse('SENSOR:ESTADO:P=1,F=0');

      expect(message.type, Esp32MessageType.sensorSnapshot);
      expect(message.plateDetected, isTrue);
      expect(message.finalLimitActive, isFalse);
    });

    test('keeps unknown packets observable for diagnostics', () {
      final message = parser.parse('FUTURO:NUEVO');

      expect(message.type, Esp32MessageType.unknown);
      expect(message.raw, 'FUTURO:NUEVO');
    });
  });
}
