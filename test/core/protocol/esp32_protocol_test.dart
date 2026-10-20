import 'package:blanquita/core/protocol/esp32_protocol.dart';
import 'package:blanquita/core/models/machine_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = Esp32MessageParser();

  for (final limit in FinalLimit.values) {
    for (final active in [false, true]) {
      test('strict directional sensor ${limit.protocolName}=$active', () {
        final message = parser.parse(
          'SENSOR:FC:${limit.protocolName}:${active ? 1 : 0}',
        );
        expect(message.type, Esp32MessageType.directionalLimitSensor);
        expect(message.finalLimit, limit);
        expect(message.booleanValue, active);
      });
    }
  }

  test('all four LIMITE events identify logical directions', () {
    final packets = {
      'LIMITE:FINAL_X_IZQUIERDA': FinalLimit.xIzquierda,
      'LIMITE:FINAL_X_DERECHA': FinalLimit.xDerecha,
      'LIMITE:FINAL_Z_ARRIBA': FinalLimit.zArriba,
      'LIMITE:FINAL_Z_ABAJO': FinalLimit.zAbajo,
    };
    for (final entry in packets.entries) {
      final message = parser.parse(entry.key);
      expect(message.type, Esp32MessageType.directionalLimitReached);
      expect(message.finalLimit, entry.value);
      expect(message.booleanValue, true);
    }
  });

  test('rejects malformed names, values, suffixes and GPIO identifiers', () {
    for (final packet in [
      'SENSOR:FC:X_IZQUIERDA:1',
      'SENSOR:FC:x_izq:1',
      'SENSOR:FC:X_IZQ:2',
      'SENSOR:FC:X_DER:true',
      'SENSOR:FC:Z_ARRIBA:',
      'SENSOR:FC:Z_ABAJO:01',
      'SENSOR:FC:18:1',
      'SENSOR:FC:X_IZQ:1:extra',
      'SENSOR:FC: X_IZQ:1',
      'LIMITE:FINAL_X_IZQ',
      'LIMITE:FINAL_Z_ARRIBA:1',
    ]) {
      expect(
        parser.parse(packet).type,
        Esp32MessageType.unknown,
        reason: packet,
      );
    }
  });

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
