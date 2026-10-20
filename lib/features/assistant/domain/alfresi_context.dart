import '../../../core/models/machine_state.dart';
import '../../vision/domain/vision_state.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../vision/controller/vision_controller.dart';

/// A read-only view of public state, never a second robot controller.
class AlfresiContext {
  const AlfresiContext({
    required this.machine,
    required this.vision,
    required this.manualLocked,
    required this.canMove,
    required this.transportOpen,
    required this.phase,
    required this.section,
  });
  factory AlfresiContext.read(
    MachineController machine,
    VisionController vision,
    String section,
  ) => AlfresiContext(
    machine: machine.state,
    vision: vision.state,
    manualLocked: machine.manualControlsLocked,
    canMove: machine.canStartMovement,
    transportOpen: machine.transportOpen,
    phase: machine.phase,
    section: section,
  );
  final MachineState machine;
  final VisionState vision;
  final bool manualLocked, canMove, transportOpen;
  final String phase, section;
  String? get lockReason {
    if (machine.finalLimitActive == true) {
      return 'Final de carrera activo. Movimiento bloqueado por seguridad.';
    }
    if (!machine.isConnected) {
      return transportOpen
          ? 'Esperando la confirmación READY del ESP32.'
          : machine.connection == ConnectionPhase.connecting
          ? 'Conexión con ESP32 en proceso.'
          : 'Sin conexión con el ESP32.';
    }
    if (machine.sequenceActive) {
      return 'Secuencia activa. El movimiento manual está bloqueado.';
    }
    if (manualLocked) return 'Control manual bloqueado por el usuario.';
    if (machine.activeMovement != null) return null;
    if (!canMove) {
      return 'Control temporalmente bloqueado por el sistema. Consulta el diagnóstico.';
    }
    return null;
  }

  Map<String, String> get evidence => {
    'Control': machine.isConnected
        ? 'Conectado · READY confirmado'
        : machine.connection.name,
    'Transporte ESP32': transportOpen ? 'Abierto' : 'Cerrado',
    'Visión': vision.ready
        ? 'Ready'
        : vision.stale
        ? 'Sin heartbeat reciente'
        : vision.connection.name,
    'Final de carrera': machine.finalLimitActive == null
        ? 'Sin datos'
        : machine.finalLimitActive!
        ? 'Activo'
        : 'Libre',
    'Secuencia': machine.sequence.name,
    'Bloqueo manual': manualLocked ? 'Activo' : 'Desactivado',
  };
}
