import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../features/settings/controller/settings_controller.dart';
import '../diagnostics/connection_log.dart';
import '../network/connection_failure.dart';
import '../haptics/haptics_service.dart';
import '../models/machine_state.dart';
import '../protocol/esp32_protocol.dart';

class MachineController extends ChangeNotifier {
  MachineController(
    this._settings, {
    WebSocketChannel Function(Uri)? channelFactory,
    Duration? readyTimeout,
    Duration? transportTimeout,
    this.reconnectBaseDelay = const Duration(seconds: 2),
    ConnectionLog? connectionLog,
  }) : _haptics = HapticsService(_settings),
       _channelFactory = channelFactory ?? WebSocketChannel.connect,
       _readyTimeout = readyTimeout ?? handshakeTimeout,
       _transportTimeout = transportTimeout ?? handshakeTimeout,
       _connectionLog = connectionLog ?? ConnectionLog.shared,
       _previousUrl = _settings.settings.websocketUrl,
       _previousAutoReconnect = _settings.settings.autoReconnect {
    _settings.addListener(_settingsChanged);
    _log('URL de control cargada', phase: 'endpoint_loaded');
  }
  static const wifiName = 'CARTESIANO';
  static const heartbeatInterval = Duration(milliseconds: 200);
  static const handshakeTimeout = Duration(seconds: 5);
  static const maxEvents = 80;
  final SettingsController _settings;
  final HapticsService _haptics;
  final ConnectionLog _connectionLog;
  final WebSocketChannel Function(Uri) _channelFactory;
  final Duration _readyTimeout;
  final Duration _transportTimeout;
  final Duration reconnectBaseDelay;
  final Esp32MessageParser _parser = const Esp32MessageParser();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _connectionTimer;
  Timer? _reconnectTimer;
  Completer<bool>? _pendingHandshake;
  MachineState _state = const MachineState();
  final List<MachineEvent> _events = [];
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;
  int _attempt = 0;
  bool _manualDisconnect = false;
  bool _desiredConnection = false;
  bool _manualControlsLocked = false;
  bool _disposed = false;
  bool _inactive = false;
  bool _connectOnResume = false;
  bool _testing = false;
  bool _transportOpen = false;
  bool _readyReceived = false;
  String _phase = 'disconnected';
  String? _lastErrorCode;
  String? _lastTechnicalError;
  String _previousUrl;
  bool _previousAutoReconnect;
  String? _connectionWebsocketUrl;

  MachineState get state => _state;
  List<MachineEvent> get events => List.unmodifiable(_events);
  bool get manualControlsLocked => _manualControlsLocked;
  String get settingsWebsocketUrl => _settings.settings.websocketUrl;
  bool get isConnecting => _state.connection == ConnectionPhase.connecting;
  String get phase => _phase;
  bool get transportOpen => _transportOpen;
  bool get protocolReady => _state.isConnected;
  String? get lastErrorCode => _lastErrorCode;
  String? get lastTechnicalError => _lastTechnicalError;
  int get reconnectAttempts => _reconnectAttempt;
  String? get connectionWebsocketUrl =>
      _connectionWebsocketUrl ??
      (settingsWebsocketUrl.isEmpty ? null : settingsWebsocketUrl);
  String? get deviceAddress =>
      EndpointValidation.parse(connectionWebsocketUrl ?? '')?.host;
  String get connectionStatusLabel => _state.isConnected
      ? 'Conectado'
      : isConnecting
      ? 'Conectando'
      : _state.connection == ConnectionPhase.error
      ? 'Error'
      : 'Desconectado';
  bool get canStartMovement =>
      _state.isConnected &&
      !_state.sequenceActive &&
      _state.activeMovement == null &&
      _state.finalLimitActive != true &&
      !_manualControlsLocked &&
      !_inactive &&
      !_testing;
  bool get canUseAuxiliaryControls =>
      _state.isConnected &&
      !_state.sequenceActive &&
      _state.activeMovement == null &&
      !_inactive &&
      !_testing;
  bool get canStartSequence =>
      canUseAuxiliaryControls && _state.finalLimitActive != true;

  Future<void> connect() async {
    if (_disposed || _inactive || isConnecting || _state.isConnected) return;
    _desiredConnection = true;
    _connectOnResume = false;
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    final generation = ++_connectionGeneration;
    _closeSocket();
    _stopHeartbeat();
    _lastErrorCode = null;
    _lastTechnicalError = null;
    _readyReceived = false;
    _connectionWebsocketUrl = settingsWebsocketUrl;
    ++_attempt;
    _phase = 'validating_endpoint';
    _state = MachineState(
      connection: ConnectionPhase.connecting,
      lastStatus: 'Validando dirección del ESP32…',
    );
    _log('Inicio de intento de conexión con el ESP32');
    notifyListeners();
    final uri = EndpointValidation.parse(settingsWebsocketUrl);
    if (uri == null) {
      _desiredConnection = false;
      _handleDisconnect(
        'La dirección configurada para el ESP32 no es válida. Configúrala en Ajustes.',
        generation,
        isError: true,
        code: 'INVALID_ENDPOINT',
        technical: 'URL vacía o inválida',
      );
      return;
    }
    final handshake = Completer<bool>();
    _pendingHandshake = handshake;
    _phase = 'connecting_transport';
    _log(
      'Intentando abrir el WebSocket del ESP32',
      technical: 'timeout=${_transportTimeout.inMilliseconds}ms',
    );
    try {
      final channel = _channelFactory(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        (raw) {
          if (_isCurrent(generation)) _onMessage(raw);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_isCurrent(generation)) return;
          final failure = ConnectionFailure.classify(error, device: 'el ESP32');
          _handleDisconnect(
            failure.humanMessage,
            generation,
            isError: true,
            code: failure.code,
            technical: '${failure.technicalMessage}\n$stackTrace',
          );
        },
        onDone: () {
          if (_isCurrent(generation)) {
            _handleDisconnect(
              'El ESP32 cerró la conexión.',
              generation,
              isError: true,
              code: 'REMOTE_CLOSED',
              technical:
                  'closeCode=${channel.closeCode} closeReason=${channel.closeReason}',
            );
          }
        },
      );
      unawaited(
        channel.ready
            .timeout(_transportTimeout)
            .then<void>(
              (_) {
                if (!_isCurrent(generation)) return;
                _transportOpen = true;
                _phase = 'websocket_open';
                _log('WebSocket abierto', technical: 'transport=open');
                _phase = 'waiting_ready';
                _log(
                  'Esperando confirmación READY del ESP32',
                  technical:
                      'protocol_ready=false timeout=${_readyTimeout.inMilliseconds}ms',
                );
                if (_readyReceived) {
                  _confirmReady();
                } else {
                  _connectionTimer = Timer(_readyTimeout, () {
                    if (_isCurrent(generation)) {
                      _handleDisconnect(
                        'Se abrió la conexión con el ESP32, pero el firmware no confirmó el protocolo de BLANQUITA.',
                        generation,
                        isError: true,
                        code: 'READY_TIMEOUT',
                        technical:
                            'transport=open protocol_ready=false timeout=${_readyTimeout.inMilliseconds}ms',
                      );
                    }
                  });
                }
                notifyListeners();
              },
              onError: (Object error, StackTrace stackTrace) {
                if (!_isCurrent(generation)) return;
                final failure = ConnectionFailure.classify(
                  error,
                  device: 'el ESP32',
                );
                _handleDisconnect(
                  failure.humanMessage,
                  generation,
                  isError: true,
                  code: failure.code,
                  technical:
                      '${failure.technicalMessage}\ntimeout=${_transportTimeout.inMilliseconds}ms\n$stackTrace',
                );
              },
            ),
      );
    } catch (error, stackTrace) {
      final failure = ConnectionFailure.classify(error, device: 'el ESP32');
      _handleDisconnect(
        failure.humanMessage,
        generation,
        isError: true,
        code: failure.code,
        technical: '${failure.technicalMessage}\n$stackTrace',
      );
    }
    await handshake.future;
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _connectionGeneration;
  void _confirmReady() {
    _connectionTimer?.cancel();
    _reconnectAttempt = 0;
    _phase = 'connected';
    _state = _state.copyWith(
      connection: ConnectionPhase.connected,
      lastStatus: 'ESP32 conectado',
      connectionError: null,
    );
    _log(
      'ESP32 conectado correctamente',
      level: ConnectionLogLevel.success,
      technical: 'transport=open protocol=READY status=connected',
    );
    _addEvent('ESP32 conectado', MachineEventLevel.success);
    final handshake = _pendingHandshake;
    _pendingHandshake = null;
    if (handshake != null && !handshake.isCompleted) handshake.complete(true);
  }

  void _closeSocket() {
    _transportOpen = false;
    _connectionTimer?.cancel();
    _connectionTimer = null;
    final handshake = _pendingHandshake;
    _pendingHandshake = null;
    if (handshake != null && !handshake.isCompleted) handshake.complete(false);
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    if (subscription != null) unawaited(_closeLogged(subscription.cancel()));
    if (channel != null) unawaited(_closeLogged(channel.sink.close()));
  }

  Future<void> _closeLogged(Future<dynamic> closing) async {
    try {
      await closing.timeout(const Duration(seconds: 2));
    } catch (error, stackTrace) {
      _log(
        'No se pudo completar el cierre del canal',
        level: ConnectionLogLevel.warning,
        technical: '${error.runtimeType}: $error\n$stackTrace',
      );
    }
  }

  Future<void> disconnect({
    String reason = 'Conexión cerrada manualmente',
  }) async {
    ++_connectionGeneration;
    _manualDisconnect = true;
    _desiredConnection = false;
    _connectOnResume = false;
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    if (_state.isConnected &&
        (_state.activeMovement != null || _state.sequenceActive)) {
      _transmit(
        _state.sequenceActive ? Esp32Command.emergencyStop : Esp32Command.stop,
      );
    }
    _stopHeartbeat();
    _closeSocket();
    if (_disposed) return;
    _phase = 'disconnected';
    _log('Reconexión cancelada manualmente');
    _setDisconnected(reason, isError: false);
  }

  Future<void> reconnect() async {
    final closing = disconnect(reason: 'Reconectando con el ESP32…');
    final generation = _connectionGeneration;
    await closing;
    if (!_isCurrent(generation)) return;
    await connect();
  }

  /// Reuses a validated connection or validates the configured endpoint; no TX.
  Future<bool> testConnection() async {
    if (_state.isConnected) {
      _log('Prueba: el canal de control ya está validado');
      return true;
    }
    if (isConnecting || _disposed || _inactive) return false;
    _testing = true;
    try {
      await connect();
      return _state.isConnected;
    } finally {
      _testing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _settingsChanged() {
    final url = settingsWebsocketUrl;
    final auto = _settings.settings.autoReconnect;
    final previousAuto = _previousAutoReconnect;
    _previousAutoReconnect = auto;
    if (_previousUrl != url) {
      _previousUrl = url;
      _log('URL de control cambiada');
      final closing = disconnect(reason: 'Dirección del ESP32 actualizada');
      final generation = _connectionGeneration;
      final hasEndpoint = url.trim().isNotEmpty;
      _desiredConnection = hasEndpoint;
      _manualDisconnect = !hasEndpoint;
      _connectOnResume = hasEndpoint && _inactive;
      unawaited(
        closing.then((_) {
          if (_isCurrent(generation) && hasEndpoint && !_inactive) {
            return connect();
          }
        }),
      );
    } else if (!auto) {
      _reconnectTimer?.cancel();
      if (previousAuto) _log('Reconexión automática de control desactivada');
    } else if (!previousAuto &&
        _desiredConnection &&
        !_state.isConnected &&
        !isConnecting) {
      _scheduleReconnect();
    }
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
    if (_disposed) return;
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

  /// STOP must be immediate on unmount; notifications wait for tree teardown.
  void stopMovementOnUnmount(MovementDirection movement) {
    if (_disposed || _state.activeMovement != movement) return;
    final channel = _channel;
    _stopHeartbeat();
    Object? failure;
    try {
      if (_state.isConnected) channel?.sink.add(Esp32Command.stop.payload);
    } catch (error) {
      failure = error;
    }
    _state = _state.copyWith(
      activeMovement: null,
      lastCommand: Esp32Command.stop.payload,
      lastStatus: 'Movimiento detenido al salir del control',
    );
    scheduleMicrotask(() {
      if (_disposed) return;
      if (failure != null) {
        final problem = ConnectionFailure.classify(failure, device: 'el ESP32');
        _handleDisconnect(
          problem.humanMessage,
          _connectionGeneration,
          isError: true,
          code: problem.code,
          technical: problem.technicalMessage,
        );
      } else {
        _log('Movimiento detenido al salir del control', technical: 'TX=x');
        notifyListeners();
      }
    });
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
    if (_state.activeMovement != null) stopMovement();
    _inactive = true;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    if (isConnecting) {
      ++_connectionGeneration;
      _closeSocket();
      _setDisconnected(
        'Intento suspendido mientras la app está en segundo plano',
        isError: false,
      );
    }
    _log('Canal de control en segundo plano', phase: 'background');
  }

  void handleAppResumed() {
    _inactive = false;
    _log('Canal de control en primer plano', phase: 'foreground');
    if (_connectOnResume) {
      _connectOnResume = false;
      unawaited(connect());
    } else if (!_state.isConnected &&
        !isConnecting &&
        _desiredConnection &&
        _settings.settings.autoReconnect &&
        !_manualDisconnect) {
      unawaited(connect());
    }
    notifyListeners();
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
        _readyReceived = true;
        _log('READY recibido', phase: 'ready_received');
        if (_transportOpen) _confirmReady();
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
    if (_disposed || !_state.isConnected || _channel == null) return false;
    try {
      _channel!.sink.add(command.payload);
      if (track) {
        _state = _state.copyWith(lastCommand: command.payload);
      }
      if (track) {
        _log(
          'Comando enviado: ${command.label}',
          technical: 'TX=${command.payload}',
        );
      }
      return true;
    } catch (error, stackTrace) {
      final failure = ConnectionFailure.classify(error, device: 'el ESP32');
      _handleDisconnect(
        failure.humanMessage,
        _connectionGeneration,
        isError: true,
        code: failure.code,
        technical: '${failure.technicalMessage}\n$stackTrace',
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
    String? code,
    String technical = '',
  }) {
    if (!_isCurrent(generation)) return;
    _lastErrorCode = code;
    _lastTechnicalError = redactConnectionText(technical);
    final failedPhase = _phase;
    _log(
      reason,
      level: isError ? ConnectionLogLevel.error : ConnectionLogLevel.warning,
      code: code,
      technical: technical,
      phase: failedPhase,
    );
    ++_connectionGeneration;
    _stopHeartbeat();
    _closeSocket();
    _phase = isError ? 'error' : 'disconnected';
    _setDisconnected(reason, isError: isError);
    if (_desiredConnection &&
        !_manualDisconnect &&
        !_inactive &&
        _settings.settings.autoReconnect) {
      _scheduleReconnect();
    }
  }

  void _setDisconnected(String reason, {required bool isError}) {
    _state = _state.copyWith(
      connection: isError
          ? ConnectionPhase.error
          : ConnectionPhase.disconnected,
      activeMovement: null,
      plateDetected: null,
      finalLimitActive: null,
      lastSensorPacket: null,
      gripper: GripperState.unknown,
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
    final ms = math.min(
      reconnectBaseDelay.inMilliseconds * (1 << _reconnectAttempt.clamp(0, 3)),
      15000,
    );
    ++_reconnectAttempt;
    _log(
      'Reconexión de control programada',
      phase: 'reconnect_scheduled',
      technical: 'delay=${ms}ms',
    );
    _reconnectTimer = Timer(Duration(milliseconds: ms), () {
      if (!_disposed &&
          !_manualDisconnect &&
          !_inactive &&
          _desiredConnection) {
        _log('Reconexión de control iniciada', phase: 'reconnecting');
        unawaited(connect());
      }
    });
  }

  void _log(
    String message, {
    ConnectionLogLevel level = ConnectionLogLevel.info,
    String? code,
    String technical = '',
    String? phase,
  }) {
    _connectionLog.add(
      channel: ConnectionChannel.control,
      level: level,
      humanMessage: message,
      technicalMessage: technical,
      errorCode: code,
      endpoint: connectionWebsocketUrl,
      phase: phase ?? _phase,
      attempt: _attempt,
    );
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
    if (_state.isConnected &&
        (_state.activeMovement != null || _state.sequenceActive)) {
      _transmit(
        _state.sequenceActive ? Esp32Command.emergencyStop : Esp32Command.stop,
      );
    }
    _disposed = true;
    ++_connectionGeneration;
    _settings.removeListener(_settingsChanged);
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _closeSocket();
    super.dispose();
  }
}
