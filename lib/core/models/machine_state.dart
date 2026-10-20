enum ConnectionPhase { disconnected, connecting, connected, error }

enum MovementDirection { xLeft, xRight, zUp, zDown }

enum LimitSwitchStatus {
  unknown('Sin datos'),
  free('Libre'),
  active('Activado');

  const LimitSwitchStatus(this.label);
  final String label;
}

enum FinalLimit {
  xIzquierda('X_IZQ', 'X izquierda', MovementDirection.xLeft),
  xDerecha('X_DER', 'X derecha', MovementDirection.xRight),
  zArriba('Z_ARRIBA', 'Z superior', MovementDirection.zUp),
  zAbajo('Z_ABAJO', 'Z inferior', MovementDirection.zDown);

  const FinalLimit(this.protocolName, this.label, this.direction);
  final String protocolName;
  final String label;
  final MovementDirection direction;

  String get retreatMessage => switch (this) {
    FinalLimit.xIzquierda =>
      'Límite izquierdo alcanzado. Suelta el botón y mueve el cartesiano hacia la derecha para retirarte.',
    FinalLimit.xDerecha =>
      'Límite derecho alcanzado. Suelta el botón y mueve el cartesiano hacia la izquierda para retirarte.',
    FinalLimit.zArriba =>
      'Límite superior alcanzado. Suelta el botón y baja el cartesiano para retirarte.',
    FinalLimit.zAbajo =>
      'Límite inferior alcanzado. Suelta el botón y sube el cartesiano para retirarte.',
  };
}

/// Readings belong only to the current socket; unknown never permits motion.
class FinalLimitsState {
  const FinalLimitsState({
    this.xIzquierda = LimitSwitchStatus.unknown,
    this.xDerecha = LimitSwitchStatus.unknown,
    this.zArriba = LimitSwitchStatus.unknown,
    this.zAbajo = LimitSwitchStatus.unknown,
  });

  final LimitSwitchStatus xIzquierda;
  final LimitSwitchStatus xDerecha;
  final LimitSwitchStatus zArriba;
  final LimitSwitchStatus zAbajo;

  LimitSwitchStatus operator [](FinalLimit limit) => switch (limit) {
    FinalLimit.xIzquierda => xIzquierda,
    FinalLimit.xDerecha => xDerecha,
    FinalLimit.zArriba => zArriba,
    FinalLimit.zAbajo => zAbajo,
  };

  bool get isComplete => FinalLimit.values.every(
    (limit) => this[limit] != LimitSwitchStatus.unknown,
  );
  bool get anyActive =>
      FinalLimit.values.any((limit) => this[limit] == LimitSwitchStatus.active);
  bool get xFault =>
      xIzquierda == LimitSwitchStatus.active &&
      xDerecha == LimitSwitchStatus.active;
  bool get zFault =>
      zArriba == LimitSwitchStatus.active && zAbajo == LimitSwitchStatus.active;
  bool get hasFault => xFault || zFault;
  bool axisFault(MovementDirection direction) =>
      direction.axis == 'X' ? xFault : zFault;
  bool blocks(MovementDirection direction) =>
      axisFault(direction) ||
      this[FinalLimit.values.firstWhere((l) => l.direction == direction)] ==
          LimitSwitchStatus.active;

  FinalLimitsState withReading(FinalLimit limit, LimitSwitchStatus value) =>
      FinalLimitsState(
        xIzquierda: limit == FinalLimit.xIzquierda ? value : xIzquierda,
        xDerecha: limit == FinalLimit.xDerecha ? value : xDerecha,
        zArriba: limit == FinalLimit.zArriba ? value : zArriba,
        zAbajo: limit == FinalLimit.zAbajo ? value : zAbajo,
      );
}

enum GripperState { unknown, opening, open, closing, closed }

enum SequencePhase { idle, requested, running, completed, cancelled, error }

extension MovementDirectionX on MovementDirection {
  String get command => switch (this) {
    MovementDirection.xLeft => 'a',
    MovementDirection.xRight => 'd',
    MovementDirection.zUp => 'w',
    MovementDirection.zDown => 's',
  };

  String get axis => switch (this) {
    MovementDirection.xLeft || MovementDirection.xRight => 'X',
    MovementDirection.zUp || MovementDirection.zDown => 'Z',
  };

  String get label => switch (this) {
    MovementDirection.xLeft => 'X hacia la izquierda',
    MovementDirection.xRight => 'X hacia la derecha',
    MovementDirection.zUp => 'Z hacia arriba',
    MovementDirection.zDown => 'Z hacia abajo',
  };
}

class MachineEvent {
  const MachineEvent({
    required this.timestamp,
    required this.message,
    this.level = MachineEventLevel.info,
  });

  final DateTime timestamp;
  final String message;
  final MachineEventLevel level;
}

enum MachineEventLevel { info, success, warning, critical }

class MachineState {
  const MachineState({
    this.connection = ConnectionPhase.disconnected,
    this.activeMovement,
    this.gripper = GripperState.unknown,
    this.sequence = SequencePhase.idle,
    this.sequenceStep,
    this.sequenceStepLabel,
    this.plateDetected,
    bool? finalLimitActive,
    this.finalLimits = const FinalLimitsState(),
    this.lastStatus = 'Sistema listo para conectar',
    this.lastMessage,
    this.lastCommand,
    this.lastReceivedAt,
    this.lastSensorPacket,
    this.connectionError,
  }) : _legacyFinalLimitActive = finalLimitActive;

  final ConnectionPhase connection;
  final MovementDirection? activeMovement;
  final GripperState gripper;
  final SequencePhase sequence;
  final int? sequenceStep;
  final String? sequenceStepLabel;
  final bool? plateDetected;
  final bool? _legacyFinalLimitActive;
  final FinalLimitsState finalLimits;
  // Compatibility summary for the dashboard and older sensor packets.
  bool? get finalLimitActive => finalLimits.anyActive
      ? true
      : finalLimits.isComplete
      ? false
      : _legacyFinalLimitActive;
  final String lastStatus;
  final String? lastMessage;
  final String? lastCommand;
  final DateTime? lastReceivedAt;
  final String? lastSensorPacket;
  final String? connectionError;

  bool get isConnected => connection == ConnectionPhase.connected;
  bool get sequenceActive =>
      sequence == SequencePhase.requested || sequence == SequencePhase.running;

  MachineState copyWith({
    ConnectionPhase? connection,
    Object? activeMovement = _unset,
    GripperState? gripper,
    SequencePhase? sequence,
    Object? sequenceStep = _unset,
    Object? sequenceStepLabel = _unset,
    Object? plateDetected = _unset,
    Object? finalLimitActive = _unset,
    FinalLimitsState? finalLimits,
    String? lastStatus,
    Object? lastMessage = _unset,
    Object? lastCommand = _unset,
    Object? lastReceivedAt = _unset,
    Object? lastSensorPacket = _unset,
    Object? connectionError = _unset,
  }) {
    return MachineState(
      connection: connection ?? this.connection,
      activeMovement: identical(activeMovement, _unset)
          ? this.activeMovement
          : activeMovement as MovementDirection?,
      gripper: gripper ?? this.gripper,
      sequence: sequence ?? this.sequence,
      sequenceStep: identical(sequenceStep, _unset)
          ? this.sequenceStep
          : sequenceStep as int?,
      sequenceStepLabel: identical(sequenceStepLabel, _unset)
          ? this.sequenceStepLabel
          : sequenceStepLabel as String?,
      plateDetected: identical(plateDetected, _unset)
          ? this.plateDetected
          : plateDetected as bool?,
      finalLimitActive: identical(finalLimitActive, _unset)
          ? _legacyFinalLimitActive
          : finalLimitActive as bool?,
      finalLimits: finalLimits ?? this.finalLimits,
      lastStatus: lastStatus ?? this.lastStatus,
      lastMessage: identical(lastMessage, _unset)
          ? this.lastMessage
          : lastMessage as String?,
      lastCommand: identical(lastCommand, _unset)
          ? this.lastCommand
          : lastCommand as String?,
      lastReceivedAt: identical(lastReceivedAt, _unset)
          ? this.lastReceivedAt
          : lastReceivedAt as DateTime?,
      lastSensorPacket: identical(lastSensorPacket, _unset)
          ? this.lastSensorPacket
          : lastSensorPacket as String?,
      connectionError: identical(connectionError, _unset)
          ? this.connectionError
          : connectionError as String?,
    );
  }
}

const Object _unset = Object();
