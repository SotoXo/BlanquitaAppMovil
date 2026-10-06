import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/connection_log.dart';
import '../../../core/network/connection_failure.dart';
import '../../settings/controller/app_settings.dart';
import '../../settings/controller/settings_controller.dart';
import '../domain/vision_message.dart';
import '../domain/vision_state.dart';
import '../domain/vision_status.dart';
import '../services/remote_vision_service.dart';
import '../services/vision_protocol_parser.dart';

class VisionController extends ChangeNotifier {
  VisionController(
    this._settings, {
    RemoteVisionService? service,
    DateTime Function()? now,
    ConnectionLog? connectionLog,
    this.connectionTimeout = const Duration(seconds: 8),
    Duration? readyTimeout,
    this.reconnectBaseDelay = const Duration(seconds: 1),
    this.tickInterval = const Duration(seconds: 1),
  }) : _service = service ?? RemoteVisionService(),
       _connectionLog = connectionLog ?? ConnectionLog.shared,
       readyTimeout = readyTimeout ?? connectionTimeout,
       _now = now ?? DateTime.now,
       _previousSettings = _settings.settings {
    _settings.addListener(_settingsChanged);
    _log('Dirección de visión cargada.');
  }

  final SettingsController _settings;
  final RemoteVisionService _service;
  final ConnectionLog _connectionLog;
  final DateTime Function() _now;
  final Duration connectionTimeout;
  final Duration readyTimeout;
  final Duration reconnectBaseDelay;
  final Duration tickInterval;
  final _parser = const VisionProtocolParser();
  AppSettings _previousSettings;
  VisionState _state = const VisionState();
  VisionSession? _session;
  StreamSubscription<dynamic>? _subscription;
  Timer? _timer;
  Timer? _retry;
  Timer? _readyTimer;
  Completer<bool>? _readyOutcome;
  bool _protocolReadyReceived = false;
  bool _transportOpen = false;
  String _phase = 'disconnected';
  String? _lastErrorCode;
  String? _lastTechnicalError;
  String? _lastCommand;
  DateTime? _connectedAt;
  DateTime? _lastPingAt;
  final Map<String, DateTime> _pings = {};
  final Map<String, DateTime> _sampledLast = {};
  final Map<String, int> _sampledCounts = {};
  int _generation = 0;
  int _attempt = 0;
  int _connectionAttempt = 0;
  int _commandId = 0;
  bool _desiredConnection = false;
  bool _inactive = false;
  bool _disposed = false;
  bool _connectOnResume = false;
  final List<String> _diagnostics = [];

  VisionState get state => _state;
  String get endpoint => _settings.settings.visionWebsocketUrl;
  List<String> get diagnostics => List.unmodifiable(_diagnostics);
  int get reconnectAttempts => _attempt;
  String get phase => _phase;
  bool get transportOpen => _transportOpen;
  String? get lastErrorCode => _lastErrorCode;
  String? get lastTechnicalError => _lastTechnicalError;
  String? get lastCommand => _lastCommand;
  bool get isConnecting =>
      state.connection == VisionConnection.connecting ||
      state.connection == VisionConnection.reconnecting;

  Future<void> connect() async {
    if (_disposed || _inactive || state.isConnected || isConnecting) return;
    _desiredConnection = true;
    _connectOnResume = false;
    _retry?.cancel();
    final url = endpoint;
    _phase = 'validating_endpoint';
    _log('Validando la dirección de la laptop.');
    if (!RemoteVisionService.isValidUrl(url)) {
      _desiredConnection = false;
      _recordFailure(
        'INVALID_ENDPOINT',
        'La dirección configurada para la laptop no es válida. Usa ws:// o wss:// con host y puerto correctos.',
        'EndpointValidation rejected endpoint',
      );
      _phase = 'error';
      _finishReady(false);
      _set(
        state.copyWith(
          connection: VisionConnection.error,
          error:
              'La dirección configurada para la laptop no es válida. Usa ws:// o wss:// con host y puerto correctos.',
        ),
      );
      return;
    }
    final generation = ++_generation;
    ++_connectionAttempt;
    _readyOutcome = Completer<bool>();
    _protocolReadyReceived = false;
    _transportOpen = false;
    _sampledLast.clear();
    _sampledCounts.clear();
    _lastErrorCode = null;
    _lastTechnicalError = null;
    _phase = 'transport_connect';
    _log('Intentando abrir el WebSocket de la laptop.');
    // Clear session telemetry; old reports must not describe a new server.
    _set(const VisionState(connection: VisionConnection.connecting));
    try {
      final session = _service.open(EndpointValidation.parse(url)!);
      _session = session;
      // Subscribe before awaiting ready, so early hello/ready are not lost and
      // connection errors have a handler while the handshake is pending.
      _subscription = session.messages.listen(
        (raw) {
          if (_current(generation)) _receive(raw);
        },
        onError: (Object error) {
          if (_current(generation)) {
            final failure = ConnectionFailure.classify(
              error,
              device: 'la laptop',
            );
            unawaited(
              _lost(
                failure.humanMessage,
                code: failure.code,
                technical: failure.technicalMessage,
              ),
            );
          }
        },
        onDone: () {
          if (_current(generation)) {
            unawaited(
              _lost(
                'La laptop cerró la conexión de visión.',
                code: 'REMOTE_CLOSED',
                technical: 'WebSocket stream completed',
              ),
            );
          }
        },
      );
      await session.ready.timeout(connectionTimeout);
      if (!_current(generation)) return;
      _transportOpen = true;
      _phase = _protocolReadyReceived ? 'connected' : 'waiting_ready';
      _connectedAt = _now();
      _lastPingAt = null;
      _set(
        state.copyWith(
          connection: VisionConnection.connected,
          clearError: true,
        ),
      );
      _log(
        _protocolReadyReceived
            ? 'WebSocket de visión abierto y vision.ready confirmado.'
            : 'WebSocket de visión abierto. Esperando vision.ready.',
        technical:
            'transport=open protocol_ready=$_protocolReadyReceived timeout=${readyTimeout.inMilliseconds}ms',
      );
      if (_protocolReadyReceived) {
        _finishReady(true);
      } else {
        _readyTimer = Timer(readyTimeout, () {
          if (!_current(generation) || _protocolReadyReceived) return;
          unawaited(
            _lost(
              'Se abrió el WebSocket de la laptop, pero el Vision Server no confirmó vision.ready. Comprueba el servidor y su protocolo.',
              code: 'READY_TIMEOUT',
              technical:
                  'transport=open protocol_ready=false timeout=${readyTimeout.inMilliseconds}ms',
            ),
          );
        });
      }
      _timer = Timer.periodic(tickInterval, (_) => _tick());
      ping();
    } catch (error) {
      if (_current(generation)) {
        final failure = ConnectionFailure.classify(error, device: 'la laptop');
        await _lost(
          failure.humanMessage,
          code: failure.code,
          technical:
              '${failure.technicalMessage} timeout=${connectionTimeout.inMilliseconds}ms',
        );
      }
    }
  }

  /// Validates this independent vision link without sending motor commands.
  Future<bool> testConnection() async {
    if (_disposed || _inactive) return false;
    if (state.ready) return true;
    if (!state.isConnected && !isConnecting) unawaited(connect());
    if (_disposed || _inactive || !_desiredConnection) return false;
    final outcome = _readyOutcome;
    if (outcome == null) return false;
    final generation = _generation;
    final ready = await outcome.future;
    return ready && _current(generation) && !_inactive && state.ready;
  }

  Future<void> disconnect() async {
    _desiredConnection = false;
    _connectOnResume = false;
    _retry?.cancel();
    _attempt = 0;
    ++_generation;
    _phase = 'disconnected';
    _transportOpen = false;
    _protocolReadyReceived = false;
    _finishReady(false);
    final closing = _close();
    _log('Visión desconectada por el usuario.');
    _set(
      state.copyWith(
        connection: VisionConnection.disconnected,
        status: state.status.merge(const VisionStatus(ready: false)),
        stale: true,
        reportStale: state.lastReport != null,
      ),
    );
    await closing;
  }

  Future<void> reconnect() async {
    final closing = disconnect();
    final generation = _generation;
    await closing;
    if (_current(generation)) await connect();
  }

  void start() => _send(VisionCommand.start);
  void stop() => _send(VisionCommand.stop);
  void ping() => _send(VisionCommand.ping);

  void _send(VisionCommand command) {
    if (_disposed || !state.isConnected || _session == null) return;
    final now = _now();
    final id = 'mobile-${now.microsecondsSinceEpoch}-${++_commandId}';
    try {
      _session!.send(command, id, now);
      _lastCommand = command.wireName;
      if (command == VisionCommand.ping) {
        _lastPingAt = now;
        _pings[id] = now;
        while (_pings.length > 16) {
          _pings.remove(_pings.keys.first);
        }
      }
      if (command == VisionCommand.ping) {
        _sampleLog('TX ${command.wireName}');
      } else {
        _log('TX ${command.wireName}');
      }
    } catch (error) {
      final failure = ConnectionFailure.classify(error, device: 'la laptop');
      unawaited(
        _lost(
          failure.humanMessage,
          code: failure.code,
          technical: '${command.wireName}: ${failure.technicalMessage}',
        ),
      );
    }
  }

  void _receive(Object? raw) {
    final result = _parser.parse(raw);
    if (result.error != null) {
      const human =
          'La laptop envió un mensaje de visión inválido. Revisa el protocolo del Vision Server.';
      _recordFailure('INVALID_PROTOCOL_MESSAGE', human, result.error!);
      _set(state.copyWith(error: human));
      return;
    }
    if (result.ignored) {
      _log('RX ignorado: tipo desconocido');
      return;
    }
    final message = result.message!;
    final now = _now();
    var status = state.status.merge(message.status);
    if (message.type == VisionMessageType.ready &&
        message.status.ready == true) {
      _connectedAt = now;
      _protocolReadyReceived = true;
      _readyTimer?.cancel();
      _attempt = 0;
      if (_transportOpen) {
        _phase = 'connected';
        _finishReady(true);
      }
      _log(
        'Vision Server confirmó vision.ready.',
        level: ConnectionLogLevel.success,
      );
    }
    // A status or heartbeat cannot substitute the protocol handshake.
    if (!_protocolReadyReceived) {
      status = status.merge(const VisionStatus(ready: false));
    }
    if (message.replyTo != null) {
      final sent = _pings.remove(message.replyTo);
      if (sent != null) {
        status = status.merge(
          VisionStatus(
            latency: math.max(0, now.difference(sent).inMicroseconds / 1000),
          ),
        );
      }
    }
    final heartbeat = message.type == VisionMessageType.heartbeat;
    if (heartbeat && _protocolReadyReceived && status.ready == true) {
      _phase = 'connected';
    }
    final report = message.report;
    // Late/replayed reports must never replace newer coordinates.
    final oldReport =
        report != null &&
        state.lastReport != null &&
        !report.timestamp.isAfter(state.lastReport!.timestamp);
    if (oldReport) _log('Reporte fuera de orden ignorado: ${report.id}');
    final accepted = oldReport ? null : report;
    _set(
      state.copyWith(
        status: oldReport ? state.status : status,
        lastMessage: message.type.wireName,
        lastMessageAt: now,
        lastHeartbeat: heartbeat ? now : null,
        stale: heartbeat ? false : null,
        lastReport: accepted,
        lastReportReceivedAt: accepted == null ? null : now,
        reportAge: accepted == null ? null : _age(accepted.timestamp),
        reportStale: accepted == null
            ? null
            : _age(accepted.timestamp) > _timeout,
        alerts: oldReport ? null : message.alerts,
        error: message.error == null
            ? null
            : 'El Vision Server informó un error. Consulta los detalles técnicos en Diagnósticos.',
        clearError: message.type != VisionMessageType.error,
      ),
    );
    if (message.error != null) {
      _recordFailure(
        'VISION_SERVER_ERROR',
        'El Vision Server informó un error.',
        message.error!,
      );
    }
    if (heartbeat || message.type == VisionMessageType.report) {
      _sampleLog('RX ${message.type.wireName}');
    } else {
      _log('RX ${message.type.wireName}');
    }
  }

  Duration get _timeout => _settings.settings.visionHeartbeatTimeout;
  Duration _age(DateTime timestamp) {
    final age = _now().difference(timestamp);
    return age.isNegative ? Duration.zero : age;
  }

  void _tick() {
    if (_disposed || !state.isConnected) return;
    final baseline = state.lastHeartbeat ?? _connectedAt;
    final age = state.lastReport == null
        ? null
        : _age(state.lastReport!.timestamp);
    final stale =
        _protocolReadyReceived && baseline != null && _age(baseline) > _timeout;
    if (stale && !state.stale) {
      _phase = _protocolReadyReceived ? 'heartbeat_stale' : 'waiting_ready';
      _recordFailure(
        'HEARTBEAT_TIMEOUT',
        'La laptop dejó de enviar el heartbeat de visión. Sus datos pueden estar desactualizados.',
        'heartbeat_age=${_age(baseline).inMilliseconds}ms timeout=${_timeout.inMilliseconds}ms',
      );
    }
    _set(
      state.copyWith(
        stale: stale,
        reportAge: age,
        reportStale: age != null && age > _timeout,
      ),
    );
    final interval = Duration(
      milliseconds: math.max(500, _timeout.inMilliseconds ~/ 2),
    );
    if (_lastPingAt == null || _age(_lastPingAt!) >= interval) ping();
  }

  Future<void> _lost(
    String error, {
    required String code,
    required String technical,
  }) async {
    if (_disposed) return;
    final failurePhase = _phase;
    ++_generation;
    _transportOpen = false;
    _protocolReadyReceived = false;
    _phase = 'error';
    _finishReady(false);
    final closing = _close();
    _recordFailure(
      code,
      error,
      '$technical phase=$failurePhase',
      eventPhase: failurePhase,
    );
    _set(
      state.copyWith(
        connection: VisionConnection.disconnected,
        status: state.status.merge(const VisionStatus(ready: false)),
        stale: true,
        reportStale: state.lastReport != null,
        error: error,
      ),
    );
    // Schedule synchronously; cancellation by user/settings/lifecycle wins.
    _scheduleRetry();
    await closing;
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (!_desiredConnection ||
        _inactive ||
        !_settings.settings.visionAutoReconnect) {
      return;
    }
    final delay = Duration(
      milliseconds: math.min(
        30000,
        reconnectBaseDelay.inMilliseconds * (1 << math.min(_attempt, 5)),
      ),
    );
    ++_attempt;
    _phase = 'reconnecting';
    _set(state.copyWith(connection: VisionConnection.reconnecting));
    _log(
      'Reconexión en ${delay.inMilliseconds} ms',
      technical: 'delay=${delay.inMilliseconds}ms attempt=$_attempt',
    );
    _retry = Timer(delay, () {
      if (_disposed || !_desiredConnection || _inactive) return;
      _set(state.copyWith(connection: VisionConnection.disconnected));
      unawaited(connect());
    });
  }

  Future<void> _close() async {
    _readyTimer?.cancel();
    _readyTimer = null;
    _timer?.cancel();
    _timer = null;
    _pings.clear();
    final subscription = _subscription;
    final session = _session;
    final closePhase = _phase;
    _subscription = null;
    _session = null;
    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (error, stackTrace) {
        _log(
          'No se pudo cancelar la recepción de la conexión anterior de visión.',
          technical: '${error.runtimeType}: $error\n$stackTrace',
          errorCode: 'SUBSCRIPTION_CLOSE_FAILED',
          eventPhase: closePhase,
          level: ConnectionLogLevel.warning,
        );
      }
    }
    if (session != null) {
      try {
        await session.close().timeout(const Duration(seconds: 2));
      } catch (error, stackTrace) {
        _log(
          'No se pudo completar el cierre del WebSocket de visión. La conexión anterior ya fue descartada.',
          technical: '${error.runtimeType}: $error\n$stackTrace',
          errorCode: 'SOCKET_CLOSE_FAILED',
          eventPhase: closePhase,
          level: ConnectionLogLevel.warning,
        );
      }
    }
  }

  void _settingsChanged() {
    final next = _settings.settings;
    final previous = _previousSettings;
    _previousSettings = next;
    if (next.visionWebsocketUrl != previous.visionWebsocketUrl) {
      final closing = disconnect();
      final generation = _generation;
      final hasEndpoint = next.visionWebsocketUrl.trim().isNotEmpty;
      _desiredConnection = hasEndpoint;
      _connectOnResume = hasEndpoint && _inactive;
      _log('Dirección de visión actualizada.');
      unawaited(
        closing.then((_) {
          if (hasEndpoint && !_inactive && _current(generation)) {
            return connect();
          }
        }),
      );
    } else if (!next.visionAutoReconnect) {
      _retry?.cancel();
      if (state.connection == VisionConnection.reconnecting) {
        _phase = 'disconnected';
        _set(state.copyWith(connection: VisionConnection.disconnected));
      }
    } else if (!previous.visionAutoReconnect &&
        _desiredConnection &&
        !state.isConnected &&
        !isConnecting) {
      _scheduleRetry();
    }
    if (state.isConnected) _tick();
  }

  void handleAppInactive() {
    _inactive = true;
    _retry?.cancel();
    ++_generation;
    _transportOpen = false;
    _protocolReadyReceived = false;
    _phase = 'background';
    _finishReady(false);
    final closing = _close();
    _log('Visión pausada al pasar la aplicación a segundo plano.');
    _set(
      state.copyWith(
        connection: VisionConnection.disconnected,
        status: state.status.merge(const VisionStatus(ready: false)),
        stale: true,
      ),
    );
    unawaited(closing);
  }

  void handleAppResumed() {
    _inactive = false;
    if (_connectOnResume ||
        (_desiredConnection && _settings.settings.visionAutoReconnect)) {
      _connectOnResume = false;
      unawaited(connect());
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _set(VisionState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  void _finishReady(bool ready) {
    final outcome = _readyOutcome;
    if (outcome != null && !outcome.isCompleted) outcome.complete(ready);
  }

  void _recordFailure(
    String code,
    String human,
    String technical, {
    String? eventPhase,
  }) {
    _lastErrorCode = code;
    _lastTechnicalError = redactConnectionText(technical);
    _log(
      human,
      technical: technical,
      errorCode: code,
      level: ConnectionLogLevel.error,
      eventPhase: eventPhase,
    );
  }

  void _sampleLog(String event) {
    final now = _now();
    final count = (_sampledCounts[event] ?? 0) + 1;
    _sampledCounts[event] = count;
    final last = _sampledLast[event];
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    _sampledLast[event] = now;
    _log(event, technical: 'sample_interval=10s session_count=$count');
  }

  void _log(
    String message, {
    String technical = '',
    String? errorCode,
    ConnectionLogLevel level = ConnectionLogLevel.info,
    String? eventPhase,
  }) {
    _connectionLog.add(
      channel: ConnectionChannel.vision,
      level: level,
      humanMessage: message,
      technicalMessage: technical,
      errorCode: errorCode,
      endpoint: endpoint,
      phase: eventPhase ?? _phase,
      attempt: _connectionAttempt,
    );
    _diagnostics.insert(
      0,
      '${_now().toIso8601String()} ${redactConnectionText(message)}',
    );
    if (_diagnostics.length > 80) _diagnostics.removeLast();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _finishReady(false);
    _settings.removeListener(_settingsChanged);
    _retry?.cancel();
    unawaited(_close());
    super.dispose();
  }
}
