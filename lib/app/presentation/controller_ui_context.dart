import '../../core/models/esp32_device.dart';
import '../../core/websocket/machine_controller.dart';
import '../../features/vision/controller/vision_controller.dart';
import '../../features/vision/domain/vision_state.dart';

/// Read-only compatibility for presentation after importing Soto's controllers.
/// Unknown diagnostic data stays null; no protocol/state is reimplemented here.
extension MachinePresentation on MachineController {
  String get progressMessage => isDiscovering
      ? 'Buscando el ESP32 en tu red Wi-Fi…'
      : switch (linkPhase) {
          Esp32LinkPhase.connecting => 'Abriendo la conexión con el ESP32…',
          Esp32LinkPhase.identityVerified =>
            'Identidad confirmada. Preparando el acceso seguro…',
          Esp32LinkPhase.authenticating =>
            'Verificando la autorización del dispositivo…',
          Esp32LinkPhase.authorized =>
            'El ESP32 confirmó el acceso. Comprobando el enlace…',
          Esp32LinkPhase.laboratory =>
            'El ESP32 respondió en modo laboratorio.',
          _ => 'Preparando la conexión con el ESP32…',
        };
  bool get protocolReady => hasValidConnection;
  bool get transportOpen => [
    Esp32LinkPhase.identityVerified,
    Esp32LinkPhase.authenticating,
    Esp32LinkPhase.authorized,
    Esp32LinkPhase.laboratory,
  ].contains(linkPhase);
  String get phase => linkPhase.name;
  String? get lastErrorCode => null;
  String? get lastTechnicalError => lastError;
  int? get reconnectAttempts => null;
  Future<bool> testConnection() async {
    await connect();
    return hasValidConnection;
  }
}

extension VisionPresentation on VisionController {
  String get progressMessage => isDiscovering
      ? 'Buscando el servidor de visión en tu red local…'
      : switch (networkPhase) {
          VisionNetworkPhase.discovered =>
            'Encontramos la laptop. Preparando la conexión…',
          VisionNetworkPhase.connecting =>
            'Abriendo la conexión con la laptop…',
          VisionNetworkPhase.socketConnected ||
          VisionNetworkPhase.waitingHello =>
            'La laptop respondió. Verificando el servicio de visión…',
          VisionNetworkPhase.waitingReady =>
            'Esperando que el servicio de visión confirme que está listo…',
          VisionNetworkPhase.waitingHeartbeat =>
            'Comprobando que la visión sigue respondiendo…',
          VisionNetworkPhase.ready =>
            'El servicio de visión confirmó que está listo.',
          VisionNetworkPhase.reconnecting =>
            'Intentando recuperar la conexión de visión…',
          _ => 'Preparando la conexión de visión…',
        };
  String get phase => networkPhase.name;
  bool get transportOpen => [
    VisionNetworkPhase.socketConnected,
    VisionNetworkPhase.waitingHello,
    VisionNetworkPhase.waitingReady,
    VisionNetworkPhase.waitingHeartbeat,
    VisionNetworkPhase.ready,
  ].contains(networkPhase);
  String? get lastErrorCode => lastFailure?.category;
  String? get lastTechnicalError => lastFailure?.toString();
  String? get lastCommand => null;
  Future<bool> testConnection() async {
    await connect();
    return state.ready;
  }
}
