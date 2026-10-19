import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../features/settings/controller/settings_controller.dart';
import '../haptics/haptics_service.dart';
import '../models/machine_state.dart';
import '../models/esp32_device.dart';
import '../network/esp32_discovery_service.dart';
import '../protocol/esp32_protocol.dart';
import '../protocol/esp32_session.dart';
import '../storage/esp32_credential_store.dart';
import 'esp32_channel.dart';

class MachineController extends ChangeNotifier {
  MachineController(
    this._settings, {
    Esp32DiscoveryService? discoveryService,
    WebSocketChannel Function(Uri)? channelFactory,
    Duration? readyTimeout,
    Esp32CredentialStore? credentialStore,
  }) : _haptics = HapticsService(_settings),
       _discovery = discoveryService ?? Esp32DiscoveryService(),
       _channelFactory = channelFactory ?? connectEsp32Channel,
       _credentials = credentialStore ?? const SecureEsp32CredentialStore(),
       _readyTimeout = readyTimeout ?? handshakeTimeout;

  static const wifiName = 'la misma red local que el ESP32';
  static const heartbeatInterval = Duration(milliseconds: 200);
  static const handshakeTimeout = Duration(seconds: 5);
  static const maxEvents = 80;

  final SettingsController _settings;
  final HapticsService _haptics;
  final Esp32DiscoveryService _discovery;
  final WebSocketChannel Function(Uri) _channelFactory;
  final Duration _readyTimeout;
  final Esp32CredentialStore _credentials;
  Esp32Session? _session;
  bool _laboratoryReady = false;
  bool _pairing = false;
  String? _lastError;
  Esp32LinkPhase _linkPhase = Esp32LinkPhase.disconnected;
  List<Esp32Device> _devices = [];
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
  bool get laboratoryEnabled => _settings.settings.laboratoryEnabled;
  bool get isAuthorized => _session?.authorized == true && _state.isConnected;
  bool get hasValidConnection =>
      !_pairing &&
      _state.isConnected &&
      (isAuthorized || (_laboratoryReady && laboratoryEnabled));
  Esp32LinkPhase get linkPhase => _linkPhase;
  String? get lastError => _lastError;
  Esp32Device? get selectedDevice => _settings.settings.selectedEsp32;
  List<Esp32Device> get devices => List.unmodifiable(
    _devices.map(
      (d) => selectedDevice?.deviceId == d.deviceId && deviceAddress == d.ip
          ? d.copyWith(connection: _linkPhase)
          : d,
    ),
  );
  String get authenticationLabel => isAuthorized
      ? 'Autorizado V2'
      : _laboratoryReady
      ? 'Laboratorio: READY sin autenticación'
      : 'Sin autenticar';
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
      ? 'Error'
      : 'Desconectado';

  bool get canStartMovement =>
      hasValidConnection &&
      !_state.sequenceActive &&
      _state.activeMovement == null &&
      _state.finalLimitActive != true &&
      !_manualControlsLocked;

  bool get canUseAuxiliaryControls =>
      hasValidConnection &&
      !_state.sequenceActive &&
      _state.activeMovement == null;

  bool get canStartSequence =>
      hasValidConnection &&
      !_state.sequenceActive &&
      _state.activeMovement == null &&
      _state.finalLimitActive != true;

  Future<void> connect() async {
    if (_disposed ||
        _inactive ||
        _pairing ||
        isConnecting ||
        _state.isConnected) {
      return;
    }
    await _connectFlow();
  }

  Future<void> setLaboratoryMode(bool enabled) async {
    await disconnect(reason: 'Cambiando modo de conexión');
    if (_disposed) return;
    await _settings.setEsp32LaboratoryMode(enabled);
    if (!_disposed) notifyListeners();
  }

  Future<void> selectDevice(Esp32Device device) async {
    if (_pairing || _disposed) return;
    if (selectedDevice != null && selectedDevice!.deviceId != device.deviceId) {
      _lastError = 'Desvincula el ESP32 actual antes de seleccionar otro';
      notifyListeners();
      return;
    }
    await disconnect(reason: 'Seleccionando ESP32');
    if (_disposed) return;
    await _settings.selectEsp32(device);
    _linkPhase = Esp32LinkPhase.found;
    notifyListeners();
  }

  Future<bool> pairSelected(String secret) async {
    final device = selectedDevice;
    if (_disposed || _inactive || _pairing || device == null) return false;
    if (!Esp32Session.validSecret(secret)) {
      _lastError = 'La credencial debe tener 64 caracteres hex minúscula';
      notifyListeners();
      return false;
    }
    _pairing = true;
    try {
      final closing = disconnect(reason: 'Vinculando ESP32 V2');
      final disconnectGeneration = _connectionGeneration;
      await closing;
      if (!_isCurrent(disconnectGeneration) || _inactive) return false;
      _manualDisconnect = false;
      final generation = ++_connectionGeneration;
      final session = Esp32Session(deviceId: device.deviceId, secret: secret);
      if (!await _attemptWebsocket(device.uri, generation, session: session)) {
        if (_isCurrent(generation)) {
          _setDisconnected(_lastError ?? 'Vinculación fallida', isError: true);
        }
        return false;
      }
      if (!_isCurrent(generation)) return false;
      await _credentials.write(device.deviceId, secret);
      if (!_isCurrent(generation) || _inactive) {
        await _credentials.delete(device.deviceId);
        return false;
      }
      await _settings.setWebsocketUrl(device.uri.toString());
      return _isCurrent(generation) && isAuthorized;
    } catch (_) {
      await disconnect(reason: 'No se pudo guardar la credencial segura');
      if (_disposed) return false;
      _lastError = 'No se pudo vincular; comprueba el almacenamiento seguro';
      notifyListeners();
      return false;
    } finally {
      _pairing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> unpair() async {
    final device = selectedDevice;
    await disconnect(reason: 'ESP32 desvinculado');
    if (device != null) {
      try {
        await _credentials.delete(device.deviceId);
      } catch (_) {
        _lastError = 'No se pudo eliminar la credencial';
        notifyListeners();
        return;
      }
    }
    if (_disposed) return;
    await _settings.selectEsp32(null);
    await _settings.setWebsocketUrl('');
    if (!_disposed) notifyListeners();
  }

  void cancelSearch() {
    unawaited(disconnect(reason: 'Búsqueda cancelada'));
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
    _lastError = null;
    _linkPhase = Esp32LinkPhase.connecting;

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

    final selected = selectedDevice;
    String? secret;
    if (selected != null) {
      try {
        secret = await _credentials.read(selected.deviceId);
      } catch (_) {
        _lastError = 'No se pudo leer la credencial segura';
      }
      if (!_isCurrent(generation)) return;
      if (!Esp32Session.validSecret(secret ?? '') && !discoveryFirst) {
        _setDisconnected(
          _lastError ?? 'Seleccionado; falta vincular con la credencial física',
          isError: true,
        );
        return;
      }
    } else if (!laboratoryEnabled && !discoveryFirst) {
      // Discovery may list devices, but selection is always explicit.
      discoveryFirst = true;
    }

    final knownUrl = _settings.settings.websocketUrl;
    if (!discoveryFirst &&
        knownUrl.isNotEmpty &&
        (selected != null || laboratoryEnabled)) {
      final knownUri = Uri.tryParse(knownUrl);
      if (knownUri != null &&
          (knownUri.scheme == 'ws' || knownUri.scheme == 'wss') &&
          knownUri.host.isNotEmpty) {
        if (await _attemptWebsocket(
          knownUri,
          generation,
          session: selected == null
              ? null
              : Esp32Session(deviceId: selected.deviceId, secret: secret!),
        )) {
          await _persistVerifiedEndpoint(knownUri, generation);
          return;
        }
      } else {
        _addEvent(
          'La dirección guardada no es válida',
          MachineEventLevel.warning,
        );
      }
    }
    if (!_isCurrent(generation)) return;

    _isDiscovering = true;
    _state = _state.copyWith(
      lastStatus: 'Buscando dispositivos V2 en la red local…',
    );
    _addEvent('Buscando ESP32 por UDP');
    notifyListeners();
    if (!_isCurrent(generation)) return;
    List<Esp32Device> candidates = [];
    try {
      candidates = await _discovery.discoverDevices();
    } catch (_) {
      _addEvent('No se pudo buscar en la red local', MachineEventLevel.warning);
    }
    if (!_isCurrent(generation)) return;
    _isDiscovering = false;
    _devices = candidates;
    if (selected == null) {
      _state = _state.copyWith(
        connection: _lastError == null
            ? ConnectionPhase.disconnected
            : ConnectionPhase.error,
        connectionError: _lastError,
        lastStatus: candidates.isEmpty
            ? 'Sin respuestas V2. Firmware antiguo: activa laboratorio y usa la URL manual.'
            : 'Selecciona explícitamente tu ESP32 y vincula su credencial',
      );
      _linkPhase = _lastError != null
          ? Esp32LinkPhase.error
          : candidates.isEmpty
          ? Esp32LinkPhase.disconnected
          : Esp32LinkPhase.found;
      notifyListeners();
      if (laboratoryEnabled &&
          _lastError != null &&
          !_manualDisconnect &&
          _settings.settings.autoReconnect) {
        _scheduleReconnect();
      }
      return;
    }
    final matches = candidates
        .where(
          (d) =>
              d.deviceId == selected.deviceId &&
              d.deviceType == Esp32Device.cartesianType,
        )
        .toList();
    if (!Esp32Session.validSecret(secret ?? '')) {
      _state = _state.copyWith(
        connection: ConnectionPhase.disconnected,
        lastStatus:
            'Búsqueda completa; vincula la credencial física antes de conectar',
      );
      _linkPhase = candidates.isEmpty
          ? Esp32LinkPhase.disconnected
          : Esp32LinkPhase.found;
      notifyListeners();
      return;
    }
    if (matches.length == 1) {
      final candidate = matches.single.uri;
      if (await _attemptWebsocket(
        candidate,
        generation,
        session: Esp32Session(deviceId: selected.deviceId, secret: secret!),
      )) {
        await _persistVerifiedEndpoint(candidate, generation);
        return;
      }
    } else if (matches.length > 1) {
      _lastError =
          'Device ID duplicado en varias direcciones; usa la URL manual';
    }
    if (!_isCurrent(generation)) return;
    _setDisconnected(
      _lastError ??
          'ESP32 vinculado no encontrado. Comprueba la LAN o la URL manual.',
      isError: true,
    );
    if (!_manualDisconnect && _settings.settings.autoReconnect) {
      _scheduleReconnect();
    }
  }

  Future<void> _persistVerifiedEndpoint(Uri uri, int generation) async {
    if (!_isCurrent(generation) || !hasValidConnection) return;
    try {
      final selected = selectedDevice;
      if (selected != null && isAuthorized) {
        await _settings.selectEsp32(selected.copyWith(ip: uri.host));
      }
      if (_isCurrent(generation)) {
        await _settings.setWebsocketUrl(uri.toString());
      }
    } catch (_) {
      if (_isCurrent(generation)) {
        _lastError = 'Conectado; no se pudo guardar la dirección';
        notifyListeners();
      }
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _connectionGeneration;

  Future<bool> _attemptWebsocket(
    Uri uri,
    int generation, {
    Esp32Session? session,
  }) async {
    if (!_isCurrent(generation)) return false;
    _closeSocket();
    _session = session;
    final socketGeneration = _socketGeneration;
    final handshake = Completer<bool>();
    _pendingHandshake = handshake;
    _connectionWebsocketUrl = uri.toString();
    _linkPhase = Esp32LinkPhase.connecting;
    _state = _state.copyWith(
      connection: ConnectionPhase.connecting,
      lastStatus: session == null
          ? 'Esperando READY (laboratorio sin autenticación)…'
          : 'Verificando identidad V2…',
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
        _lastError = reason;
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
            try {
              if (session == null) {
                _onMessage(data);
              } else if (!session.identityVerified) {
                final answer = session.answerChallenge(data);
                _linkPhase = Esp32LinkPhase.identityVerified;
                notifyListeners();
                if (!_isCurrent(generation) ||
                    socketGeneration != _socketGeneration) {
                  return;
                }
                _linkPhase = Esp32LinkPhase.authenticating;
                channel.sink.add(answer);
                notifyListeners();
              } else if (!session.authorized) {
                session.acceptReady(data);
                _acceptConnection();
              } else {
                _onMessage(session.event(data));
              }
            } catch (_) {
              failed('Identidad, autenticación o trama V2 inválida');
            }
          }
        },
        onError: (_) => failed('Error de conexión'),
        onDone: () => failed('ESP32 desconectado'),
        cancelOnError: false,
      );
      // Handle transport errors as well as stream errors; READY is still required.
      unawaited(
        channel.ready.then<void>(
          (_) {
            if (session != null &&
                _isCurrent(generation) &&
                socketGeneration == _socketGeneration) {
              try {
                channel.sink.add(session.hello());
              } catch (_) {
                failed('No se pudo iniciar el handshake V2');
              }
            }
          },
          onError: (Object _, StackTrace _) {
            failed('No se pudo abrir el WebSocket');
          },
        ),
      );
      _connectionTimer = Timer(_readyTimeout, () {
        failed('Timeout de handshake: no llegó READY autorizado');
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
    _session = null;
    _laboratoryReady = false;
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

    _tryStopBeforeClose();
    _stopHeartbeat();

    _closeSocket();
    _linkPhase = Esp32LinkPhase.disconnected;

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
    _tryStopBeforeClose();
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
        if (_session != null || !laboratoryEnabled) return;
        _laboratoryReady = true;
        _acceptConnection();
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

  void _acceptConnection() {
    _connectionTimer?.cancel();
    _reconnectAttempt = 0;
    _lastError = null;
    _linkPhase = _session?.authorized == true
        ? Esp32LinkPhase.authorized
        : Esp32LinkPhase.laboratory;
    _state = _state.copyWith(
      connection: ConnectionPhase.connected,
      lastStatus: _linkPhase.label,
      connectionError: null,
    );
    _addEvent(_linkPhase.label, MachineEventLevel.success);
    final handshake = _pendingHandshake;
    _pendingHandshake = null;
    if (handshake != null && !handshake.isCompleted) handshake.complete(true);
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
    if (!hasValidConnection || _channel == null) return false;
    try {
      _channel!.sink.add(_session?.command(command.payload) ?? command.payload);
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
    _tryStopBeforeClose();
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
    _linkPhase = isError ? Esp32LinkPhase.error : Esp32LinkPhase.disconnected;
    if (isError) _lastError = reason;
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
      if (!_disposed && !_manualDisconnect && _settings.settings.autoReconnect) {
        connect();
      }
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
    _tryStopBeforeClose();
    _disposed = true;
    ++_connectionGeneration;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _discovery.dispose();
    _closeSocket();
    super.dispose();
  }

  void _tryStopBeforeClose() {
    final validated =
        _state.isConnected &&
        (_session?.authorized == true ||
            (_laboratoryReady && laboratoryEnabled));
    if (!validated ||
        (_state.activeMovement == null && !_state.sequenceActive)) {
      return;
    }
    try {
      _channel?.sink.add(
        _session?.command(Esp32Command.stop.payload) ??
            Esp32Command.stop.payload,
      );
    } catch (_) {}
  }
}
