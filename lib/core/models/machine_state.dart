enum ConnectionPhase { disconnected, connecting, connected, error }

enum MovementDirection { xLeft, xRight, zUp, zDown }

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
    this.finalLimitActive,
    this.lastStatus = 'Sistema listo para conectar',
    this.lastMessage,
    this.lastCommand,
    this.lastReceivedAt,
    this.lastSensorPacket,
    this.connectionError,
  });

  final ConnectionPhase connection;
  final MovementDirection? activeMovement;
  final GripperState gripper;
  final SequencePhase sequence;
  final int? sequenceStep;
  final String? sequenceStepLabel;
  final bool? plateDetected;
  final bool? finalLimitActive;
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
          ? this.finalLimitActive
          : finalLimitActive as bool?,
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
