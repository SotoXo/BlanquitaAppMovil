enum Esp32Command {
  moveLeft('a', 'Mover X a la izquierda'),
  moveRight('d', 'Mover X a la derecha'),
  moveUp('w', 'Subir Z'),
  moveDown('s', 'Bajar Z'),
  stop('x', 'Detener movimiento'),
  heartbeat('k', 'Heartbeat'),
  openGripper('q', 'Abrir pinza'),
  closeGripper('e', 'Cerrar pinza'),
  startSequence('j', 'Iniciar secuencia'),
  emergencyStop('z', 'Parada de emergencia'),
  faster('+', 'Más rápido'),
  slower('-', 'Más lento');

  const Esp32Command(this.payload, this.label);

  final String payload;
  final String label;
}

enum Esp32MessageType {
  ready,
  movementStarted,
  stopped,
  stopTimeout,
  cancelled,
  gripperOpen,
  gripperClosed,
  sequenceStarted,
  sequenceStep,
  sequenceCompleted,
  plateSensor,
  finalLimitSensor,
  sensorSnapshot,
  finalLimitError,
  sequenceActiveError,
  acknowledgement,
  unknown,
}

class Esp32Message {
  const Esp32Message({
    required this.type,
    required this.raw,
    this.booleanValue,
    this.sequenceStep,
    this.detail,
    this.plateDetected,
    this.finalLimitActive,
  });

  final Esp32MessageType type;
  final String raw;
  final bool? booleanValue;
  final int? sequenceStep;
  final String? detail;
  final bool? plateDetected;
  final bool? finalLimitActive;
}

class Esp32MessageParser {
  const Esp32MessageParser();

  Esp32Message parse(Object? data) {
    final raw = data?.toString().trim() ?? '';

    switch (raw) {
      case 'READY':
        return Esp32Message(type: Esp32MessageType.ready, raw: raw);
      case 'ACK':
        return Esp32Message(type: Esp32MessageType.acknowledgement, raw: raw);
      case 'MOVIMIENTO_INICIADO':
        return Esp32Message(type: Esp32MessageType.movementStarted, raw: raw);
      case 'STOP':
        return Esp32Message(type: Esp32MessageType.stopped, raw: raw);
      case 'STOP_TIMEOUT':
        return Esp32Message(type: Esp32MessageType.stopTimeout, raw: raw);
      case 'CANCELADO':
        return Esp32Message(type: Esp32MessageType.cancelled, raw: raw);
      case 'PINZA:ABIERTA':
        return Esp32Message(type: Esp32MessageType.gripperOpen, raw: raw);
      case 'PINZA:CERRADA':
        return Esp32Message(type: Esp32MessageType.gripperClosed, raw: raw);
      case 'SECUENCIA:INICIADA':
      case 'SECUENCIA_INICIADA':
        return Esp32Message(type: Esp32MessageType.sequenceStarted, raw: raw);
      case 'SECUENCIA:COMPLETADA':
        return Esp32Message(type: Esp32MessageType.sequenceCompleted, raw: raw);
      case 'ERROR:FINAL_CARRERA':
        return Esp32Message(type: Esp32MessageType.finalLimitError, raw: raw);
      case 'ERROR:SECUENCIA_ACTIVA':
        return Esp32Message(
          type: Esp32MessageType.sequenceActiveError,
          raw: raw,
        );
    }

    final plateMatch = RegExp(r'^SENSOR:PLATO:([01])$').firstMatch(raw);
    if (plateMatch != null) {
      return Esp32Message(
        type: Esp32MessageType.plateSensor,
        raw: raw,
        booleanValue: plateMatch.group(1) == '1',
      );
    }

    final finalMatch = RegExp(r'^SENSOR:FINAL:([01])$').firstMatch(raw);
    if (finalMatch != null) {
      return Esp32Message(
        type: Esp32MessageType.finalLimitSensor,
        raw: raw,
        booleanValue: finalMatch.group(1) == '1',
      );
    }

    final snapshotMatch = RegExp(
      r'^SENSOR:ESTADO:P=([01]),\s*F=([01])$',
    ).firstMatch(raw);
    if (snapshotMatch != null) {
      return Esp32Message(
        type: Esp32MessageType.sensorSnapshot,
        raw: raw,
        plateDetected: snapshotMatch.group(1) == '1',
        finalLimitActive: snapshotMatch.group(2) == '1',
      );
    }

    final sequenceMatch = RegExp(r'^SECUENCIA:(\d+):(.+)$').firstMatch(raw);
    if (sequenceMatch != null) {
      final detail = sequenceMatch.group(2)!.replaceAll('_', ' ');
      return Esp32Message(
        type: Esp32MessageType.sequenceStep,
        raw: raw,
        sequenceStep: int.tryParse(sequenceMatch.group(1)!),
        detail: _sentenceCase(detail),
      );
    }

    return Esp32Message(type: Esp32MessageType.unknown, raw: raw);
  }

  String _sentenceCase(String value) {
    final normalized = value.toLowerCase();
    if (normalized.isEmpty) return normalized;
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }
}
