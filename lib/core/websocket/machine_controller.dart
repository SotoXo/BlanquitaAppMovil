import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../features/settings/controller/settings_controller.dart';
import '../haptics/haptics_service.dart';
import '../models/machine_state.dart';
import '../network/esp32_discovery_service.dart';
import '../protocol/esp32_protocol.dart';

class MachineController extends ChangeNotifier {
  MachineController(
    this._settings, {
    Esp32DiscoveryService? discoveryService,
    WebSocketChannel Function(Uri)? channelFactory,
    Duration? readyTimeout,
  }) : _haptics = HapticsService(_settings),
       _discovery = discoveryService ?? Esp32DiscoveryService(),
       _channelFactory = channelFactory ?? WebSocketChannel.connect,
       _readyTimeout = readyTimeout ?? handshakeTimeout;

  static const wifiName = 'CARTESIANO';
  static const heartbeatInterval = Duration(milliseconds: 200);
  static const handshakeTimeout = Duration(seconds: 5);
  static const maxEvents = 80;

  final SettingsController _settings;
  final HapticsService _haptics;
  final Esp32DiscoveryService _discovery;
  final WebSocketChannel Function(Uri) _channelFactory;
  final Duration _readyTimeout;
  final Esp32MessageParser _parser = const Esp32MessageParser();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _connectionTimer;
  Timer? _reconnectTimer;
  Completer<bool>? _pendingHandshake;
  int _socketGeneration = 0;
  bool _isDiscovering = false;
  String? _connectionWebsocketUrl;

  MachineState _state = const MachineState();
  final List<MachineEvent> _events = [];
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;
  bool _manualDisconnect = false;
  bool _inactive = false;
  bool _manualControlsLocked = false;
  bool _disposed = false;

  MachineState get state => _state;
  List<MachineEvent> get events => List.unmodifiable(_events);
  bool get manualControlsLocked => _manualControlsLocked;
  String get settingsWebsocketUrl => _settings.settings.websocketUrl;
  bool get isDiscovering => _isDiscovering;
  bool get isConnecting => _state.connection == ConnectionPhase.connecting;
  String? get connectionWebsocketUrl =>
      _connectionWebsocketUrl ??
      (settingsWebsocketUrl.isEmpty ? null : settingsWebsocketUrl);
  String? get deviceAddress =>
      Uri.tryParse(connectionWebsocketUrl ?? '')?.host.isNotEmpty == true
      ? Uri.parse(connectionWebsocketUrl!).host
      : null;
  String get connectionStatusLabel => _state.isConnected
      ? 'Conectado'
      : _isDiscovering
      ? 'Buscando'
      : isConnecting
      ? 'Conectando'
      : _state.connection == ConnectionPhase.error
      ? 'No encontrado'
      : 'Desconectado';

  bool get canStartMovement =>
      _state.isConnected &&
      !_state.sequenceActive &&
      _state.activeMovement == null &&
      _state.finalLimitActive != true &&
      !_manualControlsLocked;

  bool get canUseAuxiliaryControls =>
      _state.isConnected &&
      !_state.sequenceActive &&
      _state.activeMovement == null;

  bool get canStartSequence =>
      _state.isConnected &&
      !_state.sequenceActive &&
      _state.activeMovement == null &&
      _state.finalLimitActive != true;

  Future<void> connect() async {
    if (_disposed || _inactive || isConnecting || _state.isConnected) return;
    await _connectFlow();
  }

  Future<void> saveEndpointAndReconnect(String value) async {
    if (_disposed) return;
    final closing = disconnect(reason: 'Actualizando dirección del ESP32…');
    final generation = _connectionGeneration;
    await closing;
    if (!_isCurrent(generation)) return;
    await _settings.setWebsocketUrl(value);
    // A manual disconnect or lifecycle change while saving takes precedence.
    if (_isCurrent(generation)) await connect();
  }

  Future<void> searchEsp32() async {
    if (_disposed || _inactive || isConnecting) return;
    final closing = disconnect(reason: 'Preparando búsqueda del ESP32…');
    final generation = _connectionGeneration;
    await closing;
    if (_isCurrent(generation)) await _connectFlow(discoveryFirst: true);
  }

  Future<void> _connectFlow({bool discoveryFirst = false}) async {
    final generation = ++_connectionGeneration;
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _discovery.cancel();
    _closeSocket();
    _stopHeartbeat();
    _isDiscovering = false;
    _connectionWebsocketUrl = null;

    _state = _state.copyWith(
      connection: ConnectionPhase.connecting,
      activeMovement: null,
      sequence: SequencePhase.idle,
      sequenceStep: null,
      sequenceStepLabel: null,
      plateDetected: null,
      finalLimitActive: null,
      lastSensorPacket: null,
      lastStatus: 'Conectando al ESP32…',
      connectionError: null,
    );
    notifyListeners();

    final knownUrl = _settings.settings.websocketUrl;
    if (!discoveryFirst && knownUrl.isNotEmpty) {
      final knownUri = Uri.tryParse(knownUrl);
      if (knownUri != null &&
          (knownUri.scheme == 'ws' || knownUri.scheme == 'wss') &&
          knownUri.host.isNotEmpty) {
        if (await _attemptWebsocket(knownUri, generation)) return;
      } else {
        _addEvent(
          'La dirección guardada no es válida',
          MachineEventLevel.warning,
        );
      }
    }
    if (!_isCurrent(generation)) return;

    _isDiscovering = true;
    _state = _state.copyWith(lastStatus: 'Buscando ESP32 en $wifiName…');
    _addEvent('Buscando ESP32 por UDP');
    notifyListeners();
    if (!_isCurrent(generation)) return;
    Uri? candidate;
    try {
      candidate = await _discovery.discover();
    } catch (_) {
      _addEvent('No se pudo buscar en la red local', MachineEventLevel.warning);
    }
    if (!_isCurrent(generation)) return;
    _isDiscovering = false;
    if (candidate != null) {
      _addEvent('Candidato encontrado: ${candidate.host}');
      if (await _attemptWebsocket(candidate, generation)) {
        if (_isCurrent(generation) && _state.isConnected) {
          try {
            await _settings.setWebsocketUrl(candidate.toString());
          } catch (_) {
            if (_isCurrent(generation)) {
              _addEvent(
                'Conectado; no se pudo guardar la dirección',
                MachineEventLevel.warning,
              );
              notifyListeners();
            }
          }
        }
        return;
      }
    }
    if (!_isCurrent(generation)) return;
    _setDisconnected(
      'ESP32 no encontrado. Conecta a $wifiName o configura la URL manual.',
      isError: true,
    );
    if (!_manualDisconnect && _settings.settings.autoReconnect) {
      _scheduleReconnect();
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _connectionGeneration;

  Future<bool> _attemptWebsocket(Uri uri, int generation) async {
    if (!_isCurrent(generation)) return false;
    _closeSocket();
    final socketGeneration = _socketGeneration;
    final handshake = Completer<bool>();
    _pendingHandshake = handshake;
    _connectionWebsocketUrl = uri.toString();
    _state = _state.copyWith(
      lastStatus: 'Esperando READY del ESP32…',
      plateDetected: null,
      finalLimitActive: null,
      lastSensorPacket: null,
      sequence: SequencePhase.idle,
      sequenceStep: null,
      sequenceStepLabel: null,
    );
    _addEvent('Conectando a $uri');
    notifyListeners();
    if (!_isCurrent(generation) || socketGeneration != _socketGeneration) {
      return handshake.future;
    }

    void failed(String reason) {
      if (!_isCurrent(generation) || socketGeneration != _socketGeneration) {
        return;
      }
      if (_pendingHandshake != null) {
        _addEvent(reason, MachineEventLevel.warning);
        _closeSocket();
      } else {
        _handleDisconnect(reason, generation, isError: true);
      }
    }

    try {
      final channel = _channelFactory(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        (data) {
          if (_isCurrent(generation) && socketGeneration == _socketGeneration) {
            _onMessage(data);
          }
        },
        onError: (_) => failed('Error de conexión'),
        onDone: () => failed('ESP32 desconectado'),
        cancelOnError: false,
      );
      // Handle transport errors as well as stream errors; READY is still required.
      unawaited(
        channel.ready.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {
            failed('No se pudo abrir el WebSocket');
          },
        ),
      );
      _connectionTimer = Timer(_readyTimeout, () {
        failed('El ESP32 no envió READY');
      });
    } catch (_) {
      failed('No se pudo conectar');
    }
    return handshake.future;
  }

  void _closeSocket() {
    ++_socketGeneration;
    _connectionTimer?.cancel();
    _connectionTimer = null;
    final handshake = _pendingHandshake;
    _pendingHandshake = null;
    if (handshake != null && !handshake.isCompleted) handshake.complete(false);
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    if (subscription != null) {
      unawaited(_ignoreCloseError(subscription.cancel()));
    }
    if (channel != null) unawaited(_ignoreCloseError(channel.sink.close()));
  }

  Future<void> _ignoreCloseError(Future<dynamic> closing) async {
    try {
      await closing;
    } catch (_) {}
  }

  Future<void> disconnect({String reason = 'Conexión cerrada'}) async {
    ++_connectionGeneration;
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _discovery.cancel();
    _isDiscovering = false;
    _connectionWebsocketUrl = null;

    if (_state.activeMovement != null && _state.isConnected) {
      try {
        _channel?.sink.add(Esp32Command.stop.payload);
      } catch (_) {}
    }
    _stopHeartbeat();

    _closeSocket();

    if (_disposed) return;
    _state = _state.copyWith(
      connection: ConnectionPhase.disconnected,
      activeMovement: null,
      sequence: SequencePhase.idle,
      sequenceStep: null,
      sequenceStepLabel: null,
      lastStatus: reason,
      connectionError: null,
    );
    _addEvent(reason, MachineEventLevel.warning);
    notifyListeners();
  }

  Future<void> reconnect() async {
    final closing = disconnect(reason: 'Reconectando…');
    final generation = _connectionGeneration;
    await closing;
    if (!_isCurrent(generation)) return;
    _manualDisconnect = false;
    await connect();
  }

  bool startMovement(MovementDirection movement) {
    if (!canStartMovement) return false;

    final command = _commandForMovement(movement);
    if (!_transmit(command)) return false;

    _state = _state.copyWith(
      activeMovement: movement,
      lastStatus: 'Moviendo ${movement.label}',
    );
    _addEvent('Movimiento: ${movement.label}');
    _startHeartbeat();
    unawaited(_haptics.movementStart());
    notifyListeners();
    return true;
  }

  void stopMovement([MovementDirection? movement]) {
    final active = _state.activeMovement;
    if (active == null || (movement != null && movement != active)) return;

    _stopHeartbeat();
    _state = _state.copyWith(
      activeMovement: null,
      lastStatus: 'Motor detenido',
    );
    if (_state.isConnected) _transmit(Esp32Command.stop);
    _addEvent('Movimiento detenido');
    unawaited(_haptics.movementStop());
    notifyListeners();
  }

  void stopNow() {
    _stopHeartbeat();
    _state = _state.copyWith(
      activeMovement: null,
      lastStatus: 'STOP manual enviado',
    );
    if (_state.isConnected) _transmit(Esp32Command.stop);
    _addEvent('STOP manual enviado', MachineEventLevel.warning);
    unawaited(_haptics.action());
    notifyListeners();
  }

  void openGripper() {
    if (!canUseAuxiliaryControls) return;
    if (!_transmit(Esp32Command.openGripper)) return;
    _state = _state.copyWith(
      gripper: GripperState.opening,
      lastStatus: 'Abriendo pinza…',
    );
    _addEvent('Orden: abrir pinza');
    unawaited(_haptics.action());
    notifyListeners();
  }

  void closeGripper() {
    if (!canUseAuxiliaryControls) return;
    if (!_transmit(Esp32Command.closeGripper)) return;
    _state = _state.copyWith(
      gripper: GripperState.closing,
      lastStatus: 'Cerrando pinza…',
    );
    _addEvent('Orden: cerrar pinza');
    unawaited(_haptics.action());
    notifyListeners();
  }

  void requestFaster() =>
      _sendAuxiliary(Esp32Command.faster, 'Solicitud: más rápido');

  void requestSlower() =>
      _sendAuxiliary(Esp32Command.slower, 'Solicitud: más lento');

  void _sendAuxiliary(Esp32Command command, String status) {
    if (!canUseAuxiliaryControls || !_transmit(command)) return;
    _state = _state.copyWith(lastStatus: status);
    _addEvent(status);
    unawaited(_haptics.action());
    notifyListeners();
  }

  void startSequence() {
    if (!canStartSequence || !_transmit(Esp32Command.startSequence)) return;
    _state = _state.copyWith(
      sequence: SequencePhase.requested,
      sequenceStep: null,
      sequenceStepLabel: null,
      lastStatus: 'Solicitando secuencia automática…',
    );
    _addEvent('Secuencia automática solicitada');
    unawaited(_haptics.action());
    notifyListeners();
  }

  void emergencyStop() {
    _stopHeartbeat();
    _state = _state.copyWith(
      activeMovement: null,
      sequence: SequencePhase.cancelled,
      sequenceStep: null,
      sequenceStepLabel: null,
      lastStatus: 'PARADA DE EMERGENCIA',
    );
    if (_state.isConnected) _transmit(Esp32Command.emergencyStop);
    _addEvent('PARADA DE EMERGENCIA', MachineEventLevel.critical);
    unawaited(_haptics.critical());
    notifyListeners();
  }

  void setManualControlsLocked(bool locked) {
    if (_manualControlsLocked == locked) return;
    if (locked && _state.activeMovement != null) stopNow();
    _manualControlsLocked = locked;
    _addEvent(
      locked ? 'Control manual bloqueado' : 'Control manual desbloqueado',
    );
    notifyListeners();
  }

  void handleAppInactive() {
    if (_disposed || _inactive) return;
    _inactive = true;
    if (_state.activeMovement != null) {
      stopMovement();
      _addEvent(
        'Movimiento detenido por cambio de estado de la app',
        MachineEventLevel.warning,
      );
    } else {
      _stopHeartbeat();
    }
    // WiFi settings can leave a TCP socket apparently alive on an old network.
    // Suspend it after STOP, retaining the user's reconnect/disconnect intent.
    ++_connectionGeneration;
    _reconnectTimer?.cancel();
    _discovery.cancel();
    _isDiscovering = false;
    _closeSocket();
    _setDisconnected(
      'Conexión pausada mientras la app está inactiva',
      isError: false,
    );
  }

  void handleAppResumed() {
    if (_disposed) return;
    _inactive = false;
    if ((_state.connection == ConnectionPhase.disconnected ||
            _state.connection == ConnectionPhase.error) &&
        _settings.settings.autoReconnect &&
        !_manualDisconnect) {
      connect();
    }
  }

  void clearEvents() {
    _events.clear();
    _addEvent('Historial limpiado');
    notifyListeners();
  }

  void _onMessage(Object? data) {
    final message = _parser.parse(data);
    final now = DateTime.now();
    _state = _state.copyWith(lastMessage: message.raw, lastReceivedAt: now);

    switch (message.type) {
      case Esp32MessageType.ready:
        _connectionTimer?.cancel();
        _reconnectAttempt = 0;
        _state = _state.copyWith(
          connection: ConnectionPhase.connected,
          lastStatus: 'ESP32 conectado',
          connectionError: null,
        );
        _addEvent('ESP32 conectado', MachineEventLevel.success);
        final handshake = _pendingHandshake;
        _pendingHandshake = null;
        if (handshake != null && !handshake.isCompleted) {
          handshake.complete(true);
        }
      case Esp32MessageType.movementStarted:
        _state = _state.copyWith(lastStatus: 'Movimiento confirmado por ESP32');
      case Esp32MessageType.stopped:
        _stopHeartbeat();
        _state = _state.copyWith(
          activeMovement: null,
          lastStatus: 'Motor detenido',
        );
        _addEvent('Motor detenido');
      case Esp32MessageType.stopTimeout:
        _stopHeartbeat();
        _state = _state.copyWith(
          activeMovement: null,
          lastStatus: 'Motor detenido por timeout de seguridad',
        );
        _addEvent('STOP_TIMEOUT recibido', MachineEventLevel.critical);
      case Esp32MessageType.cancelled:
        _stopHeartbeat();
        _state = _state.copyWith(
          activeMovement: null,
          sequence: SequencePhase.cancelled,
          sequenceStep: null,
          sequenceStepLabel: null,
          lastStatus: 'Operación cancelada',
        );
        _addEvent('Operación cancelada', MachineEventLevel.warning);
      case Esp32MessageType.gripperOpen:
        _state = _state.copyWith(
          gripper: GripperState.open,
          lastStatus: 'Pinza abierta',
        );
        _addEvent('Pinza abierta', MachineEventLevel.success);
      case Esp32MessageType.gripperClosed:
        _state = _state.copyWith(
          gripper: GripperState.closed,
          lastStatus: 'Pinza cerrada',
        );
        _addEvent('Pinza cerrada', MachineEventLevel.success);
      case Esp32MessageType.sequenceStarted:
        _stopHeartbeat();
        _state = _state.copyWith(
          activeMovement: null,
          sequence: SequencePhase.running,
          sequenceStep: null,
          sequenceStepLabel: 'Preparando secuencia',
          lastStatus: 'Secuencia automática iniciada',
        );
        _addEvent('Secuencia iniciada', MachineEventLevel.success);
      case Esp32MessageType.sequenceStep:
        _stopHeartbeat();
        _state = _state.copyWith(
          activeMovement: null,
          sequence: SequencePhase.running,
          sequenceStep: message.sequenceStep,
          sequenceStepLabel: message.detail,
          lastStatus: message.detail ?? 'Secuencia en curso',
        );
        _addEvent(
          'Paso ${message.sequenceStep ?? '—'}: ${message.detail ?? 'en curso'}',
        );
      case Esp32MessageType.sequenceCompleted:
        _state = _state.copyWith(
          sequence: SequencePhase.completed,
          sequenceStep: 8,
          sequenceStepLabel: 'Secuencia completada',
          lastStatus: 'Secuencia completada',
        );
        _addEvent('Secuencia completada', MachineEventLevel.success);
        unawaited(_haptics.action());
      case Esp32MessageType.plateSensor:
        _setPlate(message.booleanValue == true);
      case Esp32MessageType.finalLimitSensor:
        _setFinalLimit(message.booleanValue == true);
      case Esp32MessageType.sensorSnapshot:
        _state = _state.copyWith(lastSensorPacket: message.raw);
        _setPlate(message.plateDetected == true);
        _setFinalLimit(message.finalLimitActive == true);
      case Esp32MessageType.finalLimitError:
        _setFinalLimit(true, addEvent: false);
        _state = _state.copyWith(
          lastStatus: 'Movimiento bloqueado por final de carrera',
        );
        _addEvent('Error: final de carrera', MachineEventLevel.critical);
      case Esp32MessageType.sequenceActiveError:
        _state = _state.copyWith(
          sequence: SequencePhase.error,
          lastStatus: 'Ya existe una secuencia activa',
        );
        _addEvent('Secuencia ya activa', MachineEventLevel.warning);
      case Esp32MessageType.acknowledgement:
        break;
      case Esp32MessageType.unknown:
        if (message.raw.isNotEmpty) {
          _addEvent('Mensaje no reconocido: ${message.raw}');
        }
    }

    notifyListeners();
  }

  void _setPlate(bool detected, {bool addEvent = true}) {
    if (_state.plateDetected == detected) return;
    _state = _state.copyWith(
      plateDetected: detected,
      lastStatus: detected ? 'Plato detectado' : 'Zona de plato libre',
    );
    if (addEvent) {
      _addEvent(
        detected ? 'Sensor: plato detectado' : 'Sensor: plato libre',
        detected ? MachineEventLevel.success : MachineEventLevel.info,
      );
    }
  }

  void _setFinalLimit(bool active, {bool addEvent = true}) {
    final wasActive = _state.finalLimitActive == true;
    if (active) {
      _stopHeartbeat();
      _state = _state.copyWith(
        finalLimitActive: true,
        activeMovement: null,
        sequence: _state.sequenceActive
            ? SequencePhase.cancelled
            : _state.sequence,
        lastStatus: 'FINAL DE CARRERA ACTIVADO',
      );
      if (!wasActive && _settings.settings.strongLimitFeedback) {
        unawaited(_haptics.critical());
      }
    } else {
      _state = _state.copyWith(
        finalLimitActive: false,
        lastStatus: wasActive ? 'Final de carrera liberado' : _state.lastStatus,
      );
    }
    if (addEvent && wasActive != active) {
      _addEvent(
        active ? 'FINAL DE CARRERA ACTIVADO' : 'Final de carrera liberado',
        active ? MachineEventLevel.critical : MachineEventLevel.success,
      );
    }
  }

  bool _transmit(Esp32Command command, {bool track = true}) {
    if (!_state.isConnected || _channel == null) return false;
    try {
      _channel!.sink.add(command.payload);
      if (track) {
        _state = _state.copyWith(lastCommand: command.payload);
      }
      debugPrint('BLANQUITA -> ${command.payload}');
      return true;
    } catch (_) {
      _handleDisconnect(
        'Error enviando comando',
        _connectionGeneration,
        isError: true,
      );
      return false;
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_state.activeMovement != null && _state.isConnected) {
        _transmit(Esp32Command.heartbeat, track: false);
      } else {
        _stopHeartbeat();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Esp32Command _commandForMovement(MovementDirection movement) {
    return switch (movement) {
      MovementDirection.xLeft => Esp32Command.moveLeft,
      MovementDirection.xRight => Esp32Command.moveRight,
      MovementDirection.zUp => Esp32Command.moveUp,
      MovementDirection.zDown => Esp32Command.moveDown,
    };
  }

  void _handleDisconnect(
    String reason,
    int generation, {
    bool isError = false,
  }) {
    if (_disposed || generation != _connectionGeneration) return;
    ++_connectionGeneration;
    _discovery.cancel();
    _isDiscovering = false;
    _stopHeartbeat();
    _closeSocket();
    _setDisconnected(reason, isError: isError);

    if (!_manualDisconnect && _settings.settings.autoReconnect) {
      _scheduleReconnect();
    }
  }

  void _setDisconnected(String reason, {required bool isError}) {
    _state = _state.copyWith(
      connection: isError
          ? ConnectionPhase.error
          : ConnectionPhase.disconnected,
      activeMovement: null,
      sequence: SequencePhase.idle,
      sequenceStep: null,
      sequenceStepLabel: null,
      lastStatus: reason,
      connectionError: isError ? reason : null,
    );
    _addEvent(
      reason,
      isError ? MachineEventLevel.critical : MachineEventLevel.warning,
    );
    notifyListeners();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final seconds = math.min(2 << _reconnectAttempt.clamp(0, 3), 15);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!_disposed && !_manualDisconnect) connect();
    });
  }

  void _addEvent(
    String message, [
    MachineEventLevel level = MachineEventLevel.info,
  ]) {
    _events.insert(
      0,
      MachineEvent(timestamp: DateTime.now(), message: message, level: level),
    );
    if (_events.length > maxEvents) {
      _events.removeRange(maxEvents, _events.length);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_connectionGeneration;
    if (_state.activeMovement != null && _state.isConnected) {
      try {
        _channel?.sink.add(Esp32Command.stop.payload);
      } catch (_) {}
    }
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _discovery.dispose();
    _closeSocket();
    super.dispose();
  }
}
