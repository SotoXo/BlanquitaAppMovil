import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../settings/controller/app_settings.dart';
import '../../settings/controller/settings_controller.dart';
import '../domain/vision_message.dart';
import '../domain/vision_endpoint.dart';
import '../domain/vision_network_failure.dart';
import '../domain/vision_state.dart';
import '../domain/vision_status.dart';
import '../services/remote_vision_service.dart';
import '../services/vision_discovery_service.dart';
import '../services/vision_protocol_parser.dart';

class VisionController extends ChangeNotifier {
  VisionController(
    this._settings, {
    RemoteVisionService? service,
    VisionDiscoveryService? discoveryService,
    DateTime Function()? now,
    this.connectionTimeout = const Duration(seconds: 8),
    this.reconnectBaseDelay = const Duration(seconds: 1),
    this.tickInterval = const Duration(seconds: 1),
  }) : _service = service ?? RemoteVisionService(),
       _discovery = discoveryService ?? VisionDiscoveryService(),
       _now = now ?? DateTime.now,
       _previousSettings = _settings.settings {
    _settings.addListener(_settingsChanged);
  }

  final SettingsController _settings;
  final RemoteVisionService _service;
  final VisionDiscoveryService _discovery;
  final DateTime Function() _now;
  final Duration connectionTimeout;
  final Duration reconnectBaseDelay;
  final Duration tickInterval;
  final _parser = const VisionProtocolParser();
  AppSettings _previousSettings;
  VisionState _state = const VisionState();
  VisionSession? _session;
  StreamSubscription<dynamic>? _subscription;
  Timer? _timer;
  Timer? _retry;
  Timer? _handshakeTimer;
  Completer<bool>? _pendingHandshake;
  int _socketGeneration = 0;
  bool _transportReady = false;
  bool _serverReady = false;
  bool _helloReceived = false;
  bool _heartbeatReceived = false;
  Future<void> _closing = Future<void>.value();
  VisionNetworkPhase _networkPhase = VisionNetworkPhase.disconnected;
  VisionNetworkFailure? _firstFailure;
  VisionNetworkFailure? _lastFailure;
  int _connectionAttempt = 0;
  bool _diagnosticMode = false;
  bool _flowActive = false;
  bool _isDiscovering = false;
  String _discoveryStatus = 'Sin búsqueda';
  String? _detectedUrl;
  String? _connectionUrl;
  String? _persistingUrl;
  DateTime? _connectedAt;
  DateTime? _lastPingAt;
  final Map<String, DateTime> _pings = {};
  int _generation = 0;
  int _attempt = 0;
  int _commandId = 0;
  bool _desiredConnection = false;
  bool _inactive = false;
  bool _disposed = false;
  final List<String> _diagnostics = [];

  VisionState get state => _state;
  String get endpoint => _settings.settings.visionWebsocketUrl;
  String? get connectionWebsocketUrl => _connectionUrl;
  String? get detectedAddress =>
      _detectedUrl == null ? null : Uri.parse(_detectedUrl!).host;
  String get discoveryStatusLabel => _discoveryStatus;
  bool get isDiscovering => _isDiscovering;
  List<String> get diagnostics => List.unmodifiable(_diagnostics);
  int get reconnectAttempts => _attempt;
  int get connectionAttempt => _connectionAttempt;
  VisionNetworkPhase get networkPhase => _networkPhase;
  VisionNetworkFailure? get firstFailure => _firstFailure;
  VisionNetworkFailure? get lastFailure => _lastFailure;
  bool get diagnosticMode => _diagnosticMode;
  int? get detectedPort =>
      _detectedUrl == null ? null : Uri.parse(_detectedUrl!).port;

  void setDiagnosticMode(bool value) {
    _diagnosticMode = value;
    if (value) {
      _retry?.cancel();
      if (state.connection == VisionConnection.reconnecting) {
        _phase(
          _lastFailure == null
              ? VisionNetworkPhase.disconnected
              : VisionNetworkPhase.error,
        );
        _set(state.copyWith(connection: VisionConnection.disconnected));
      }
    } else if (_desiredConnection &&
        !_inactive &&
        !state.isConnected &&
        !isConnecting) {
      _scheduleRetry();
    }
    _log('Diagnóstico sin reintentos automáticos: $value');
    notifyListeners();
  }

  bool get isConnecting =>
      _flowActive || state.connection == VisionConnection.connecting;

  Future<void> connect() async {
    if (_disposed || _inactive || state.isConnected || isConnecting) return;
    await _connectFlow();
  }

  Future<void> saveEndpointAndReconnect(String value) async {
    if (_disposed) return;
    final url = VisionEndpoint.normalize(value);
    // Invalidate old discovery/socket callbacks before accepting a manual URL.
    final closing = disconnect();
    final generation = _generation;
    await closing;
    if (!_current(generation)) return;
    _persistingUrl = url;
    try {
      // Suppress the URL listener's automatic reconnect until persistence ends.
      await _settings.setVisionWebsocketUrl(url);
    } finally {
      if (_persistingUrl == url) _persistingUrl = null;
    }
    if (_current(generation)) await connect();
  }

  Future<void> searchVision() async {
    if (_disposed || _inactive || isConnecting) return;
    final closing = disconnect();
    final generation = _generation;
    await closing;
    if (_current(generation) && !_inactive) {
      await _connectFlow(discoveryFirst: true);
    }
  }

  Future<void> _connectFlow({bool discoveryFirst = false}) async {
    _desiredConnection = true;
    _retry?.cancel();
    _discovery.cancel();
    final generation = ++_generation;
    _flowActive = true;
    _isDiscovering = false;
    _connectionUrl = null;
    final knownUrl = endpoint;
    _set(const VisionState(connection: VisionConnection.connecting));
    try {
      await _closeSocket();
      if (!_current(generation)) return;
      if (!discoveryFirst && RemoteVisionService.isValidUrl(knownUrl)) {
        if (await _attemptWebsocket(
          VisionEndpoint.parse(knownUrl),
          generation,
          rawValue: knownUrl,
        )) {
          return;
        }
      } else if (!discoveryFirst && knownUrl.isNotEmpty) {
        _recordFailure(
          FormatException('URL Vision inválida: $knownUrl'),
          StackTrace.current,
          category: 'URI inválida',
        );
      }
      if (!_current(generation)) return;
      _isDiscovering = true;
      _discoveryStatus = 'Buscando por UDP';
      _detectedUrl = null;
      _log('Buscando visor por UDP :4211');
      notifyListeners();
      if (!_current(generation)) return;
      Uri? candidate;
      try {
        candidate = await _discovery.discover();
      } catch (error) {
        _log('Error de discovery: $error');
      }
      if (!_current(generation)) return;
      _isDiscovering = false;
      _discoveryStatus = candidate == null
          ? 'No encontrado'
          : 'Candidato · esperando vision.ready';
      _detectedUrl = candidate?.toString();
      if (candidate != null) {
        candidate = VisionEndpoint.parse(candidate.toString());
        _detectedUrl = candidate.toString();
        _phase(VisionNetworkPhase.discovered);
        _log(
          'VISION_DISCOVERY source IP=${candidate.host} port=${candidate.port} URI=$candidate',
        );
      }
      notifyListeners();
      if (candidate != null && await _attemptWebsocket(candidate, generation)) {
        if (_current(generation) && state.isConnected) {
          _discoveryStatus = 'Visor validado';
          _persistingUrl = candidate.toString();
          try {
            await _settings.setVisionWebsocketUrl(_persistingUrl!);
          } catch (error) {
            _log('Conectado; no se pudo guardar la URL: $error');
            if (_current(generation)) {
              _set(
                state.copyWith(
                  error: 'Conectado; no se pudo guardar la dirección.',
                ),
              );
            }
          } finally {
            _persistingUrl = null;
          }
        }
        return;
      }
      if (!_current(generation)) return;
      if (candidate != null) _discoveryStatus = 'Candidato sin vision.ready';
      _set(
        state.copyWith(
          connection: VisionConnection.disconnected,
          status: state.status.merge(const VisionStatus(ready: false)),
          stale: true,
          error:
              state.error ??
              'Visor no encontrado o sin vision.ready. Conserva o configura la URL manual.',
        ),
      );
      _scheduleRetry();
    } finally {
      if (_current(generation)) {
        _flowActive = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _attemptWebsocket(
    Uri uri,
    int generation, {
    String? rawValue,
  }) async {
    if (!_current(generation)) return false;
    await _closeSocket();
    if (!_current(generation)) return false;
    uri = VisionEndpoint.parse(uri.toString());
    final socketGeneration = _socketGeneration;
    final handshake = Completer<bool>();
    _pendingHandshake = handshake;
    _connectionUrl = uri.toString();
    ++_connectionAttempt;
    // Each candidate is a new session, never reuse previous telemetry.
    _set(const VisionState(connection: VisionConnection.connecting));
    _phase(VisionNetworkPhase.connecting);
    _log(
      'VISION_WS_CONNECT attempt=$_connectionAttempt\n'
      'raw value: ${rawValue ?? uri}\nparsed URI: $uri\n'
      'scheme: ${uri.scheme}\nhost: ${uri.host}\nport: ${uri.port}\n'
      'path: ${uri.path}\nquery: ${uri.query}\nfragment: ${uri.fragment}',
    );
    bool currentSocket() =>
        _current(generation) && socketGeneration == _socketGeneration;
    void failed(Object error, StackTrace stack, {String? category}) {
      if (!currentSocket()) return;
      _recordFailure(error, stack, category: category);
      final reason = _lastFailure!.summary;
      if (_pendingHandshake != null) {
        _set(state.copyWith(error: reason));
        unawaited(_closeSocket());
      } else {
        unawaited(_lost(reason));
      }
    }

    if (!currentSocket()) return handshake.future;
    try {
      final session = _service.open(uri);
      _session = session;
      _subscription = session.messages.listen(
        (raw) {
          if (currentSocket()) _receive(raw);
        },
        onError: (Object error, StackTrace stack) {
          failed(error, stack);
        },
        onDone: () => failed(
          StateError(
            'Vision Server desconectado; closeCode=${session.closeCode}; '
            'closeReason=${session.closeReason}',
          ),
          StackTrace.current,
          category: 'Socket cerrado',
        ),
      );
      _handshakeTimer = Timer(
        connectionTimeout,
        () => failed(
          TimeoutException(
            _transportReady
                ? 'Esperando hello/vision.ready/heartbeat; estado=${_networkPhase.label}'
                : 'Timeout TCP/upgrade WebSocket',
            connectionTimeout,
          ),
          StackTrace.current,
          category: _transportReady
              ? 'Timeout protocolo JSON v1'
              : 'Timeout TCP/upgrade',
        ),
      );
      unawaited(
        session.ready.then<void>((_) {
          if (!currentSocket()) return;
          _transportReady = true;
          _phase(VisionNetworkPhase.socketConnected);
          _waitingPhase();
          _completeHandshake();
        }, onError: (Object error, StackTrace stack) => failed(error, stack)),
      );
    } catch (error, stack) {
      failed(error, stack);
    }
    return handshake.future;
  }

  void _completeHandshake() {
    final handshake = _pendingHandshake;
    if (handshake == null ||
        !_transportReady ||
        !_helloReceived ||
        !_serverReady ||
        !_heartbeatReceived ||
        state.status.ready != true) {
      return;
    }
    _pendingHandshake = null;
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    _connectedAt = _now();
    _lastPingAt = null;
    _attempt = 0;
    _phase(VisionNetworkPhase.ready);
    final socketGeneration = _socketGeneration;
    _set(
      state.copyWith(connection: VisionConnection.connected, clearError: true),
    );
    if (_disposed || socketGeneration != _socketGeneration) {
      if (!handshake.isCompleted) handshake.complete(false);
      return;
    }
    _log(
      'Visor validado con vision.hello + vision.ready + heartbeat: $_connectionUrl',
    );
    _timer = Timer.periodic(tickInterval, (_) => _tick());
    ping();
    if (!handshake.isCompleted) handshake.complete(state.isConnected);
  }

  Future<void> disconnect() async {
    _desiredConnection = false;
    _retry?.cancel();
    _attempt = 0;
    ++_generation;
    _flowActive = false;
    _discovery.cancel();
    if (_isDiscovering) _discoveryStatus = 'Búsqueda cancelada';
    _isDiscovering = false;
    _connectionUrl = null;
    _phase(VisionNetworkPhase.disconnected);
    _set(
      state.copyWith(
        connection: VisionConnection.disconnected,
        status: state.status.merge(const VisionStatus(ready: false)),
        stale: true,
        reportStale: state.lastReport != null,
      ),
    );
    await _close();
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
      if (command == VisionCommand.ping) {
        _lastPingAt = now;
        _pings[id] = now;
        while (_pings.length > 16) {
          _pings.remove(_pings.keys.first);
        }
      }
      _log('TX ${command.wireName}');
    } catch (error, stack) {
      _recordFailure(error, stack, category: 'Envío WebSocket');
      unawaited(_lost('Error enviando ${command.wireName}: $error'));
    }
  }

  void _receive(Object? raw) {
    final result = _parser.parse(raw);
    if (result.error != null) {
      _recordFailure(
        FormatException(result.error!),
        StackTrace.current,
        category: 'Protocolo JSON inválido',
      );
      _log('RX rechazado: ${result.error}');
      _set(state.copyWith(error: result.error));
      return;
    }
    if (result.ignored) {
      _log('RX ignorado: tipo desconocido');
      return;
    }
    final message = result.message!;
    if (_pendingHandshake != null &&
        message.type == VisionMessageType.ready &&
        !_helloReceived) {
      _recordFailure(
        const FormatException('vision.ready llegó antes de vision.hello'),
        StackTrace.current,
        category: 'Orden de protocolo inválido',
      );
      _set(state.copyWith(error: _lastFailure!.summary));
      return;
    }
    if (message.type == VisionMessageType.hello) _helloReceived = true;
    if (message.type == VisionMessageType.ready) {
      _serverReady = message.status.ready == true;
    }
    if (message.type == VisionMessageType.heartbeat &&
        _helloReceived &&
        _serverReady) {
      _heartbeatReceived = true;
    }
    final now = _now();
    var status = state.status.merge(message.status);
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
        error: message.error,
        clearError: message.type != VisionMessageType.error,
      ),
    );
    if (_pendingHandshake != null) {
      _waitingPhase();
      _completeHandshake();
    } else if (state.isConnected) {
      _phase(VisionNetworkPhase.ready);
    }
    _log('RX ${message.type.wireName}');
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
    final stale = baseline != null && _age(baseline) >= _timeout;
    if (stale) {
      _recordFailure(
        TimeoutException('Heartbeat de visión vencido', _timeout),
        StackTrace.current,
        category: 'Heartbeat timeout posterior',
      );
      unawaited(_lost(_lastFailure!.summary));
      return;
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

  Future<void> _lost(String error) async {
    if (_disposed) return;
    ++_generation;
    _flowActive = false;
    _log(error);
    _set(
      state.copyWith(
        connection: VisionConnection.disconnected,
        status: state.status.merge(const VisionStatus(ready: false)),
        stale: true,
        reportStale: state.lastReport != null,
        error: error,
        reportAge: state.lastReport == null
            ? null
            : _age(state.lastReport!.timestamp),
      ),
    );
    // Schedule synchronously; cancellation by user/settings/lifecycle wins.
    _scheduleRetry();
    await _close();
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (!_desiredConnection ||
        _diagnosticMode ||
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
    _phase(VisionNetworkPhase.reconnecting);
    _set(state.copyWith(connection: VisionConnection.reconnecting));
    _log('Reconexión en ${delay.inMilliseconds} ms');
    _retry = Timer(delay, () {
      if (_disposed || !_desiredConnection || _inactive) return;
      _set(state.copyWith(connection: VisionConnection.disconnected));
      unawaited(connect());
    });
  }

  Future<void> _close() async {
    await _closeSocket();
  }

  Future<void> _closeSocket() {
    ++_socketGeneration;
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    final handshake = _pendingHandshake;
    _pendingHandshake = null;
    if (handshake != null && !handshake.isCompleted) handshake.complete(false);
    _transportReady = false;
    _serverReady = false;
    _helloReceived = false;
    _heartbeatReceived = false;
    _timer?.cancel();
    _timer = null;
    _pings.clear();
    final subscription = _subscription;
    final session = _session;
    _subscription = null;
    _session = null;
    // Invoke close now to abort TCP/upgrade before waiting for stream cleanup.
    final closingSession = session == null
        ? Future<void>.value()
        : _ignoreCloseError(session.close());
    final cancelling = subscription == null
        ? Future<void>.value()
        : _ignoreCloseError(subscription.cancel());
    _closing = Future.wait<void>([
      _closing,
      closingSession,
      cancelling,
    ]).then((_) {});
    return _closing;
  }

  Future<void> _ignoreCloseError(Future<void> closing) async {
    try {
      await closing;
    } catch (_) {
      /* The peer may already be gone. */
    }
  }

  void _settingsChanged() {
    final next = _settings.settings;
    final previous = _previousSettings;
    _previousSettings = next;
    if (next.visionWebsocketUrl != previous.visionWebsocketUrl) {
      if (next.visionWebsocketUrl == _persistingUrl) return;
      final wanted = _desiredConnection;
      final closing = disconnect();
      final generation = _generation;
      unawaited(
        closing.then((_) {
          if (wanted && _current(generation)) return connect();
        }),
      );
    } else if (!next.visionAutoReconnect) {
      _retry?.cancel();
      if (state.connection == VisionConnection.reconnecting) {
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
    if (_disposed || _inactive) return;
    _inactive = true;
    _retry?.cancel();
    ++_generation;
    _flowActive = false;
    _discovery.cancel();
    if (_isDiscovering) _discoveryStatus = 'Búsqueda cancelada';
    _isDiscovering = false;
    _phase(VisionNetworkPhase.disconnected);
    _set(
      state.copyWith(
        connection: VisionConnection.disconnected,
        status: state.status.merge(const VisionStatus(ready: false)),
        stale: true,
      ),
    );
    unawaited(_close());
  }

  void handleAppResumed() {
    if (_disposed) return;
    _inactive = false;
    if (_desiredConnection &&
        !_diagnosticMode &&
        _settings.settings.visionAutoReconnect) {
      unawaited(connect());
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void _waitingPhase() {
    if (_pendingHandshake == null || !_transportReady) return;
    _phase(
      !_helloReceived
          ? VisionNetworkPhase.waitingHello
          : !_serverReady
          ? VisionNetworkPhase.waitingReady
          : VisionNetworkPhase.waitingHeartbeat,
    );
  }

  void _phase(VisionNetworkPhase phase) {
    if (_networkPhase == phase) return;
    _log(
      'VISION_STATE ${_networkPhase.label} -> ${phase.label} attempt=$_connectionAttempt',
    );
    _networkPhase = phase;
  }

  void _recordFailure(Object error, StackTrace stack, {String? category}) {
    final failure = VisionNetworkFailure(
      error: error,
      stack: stack,
      uri: _connectionUrl ?? endpoint,
      timestamp: _now(),
      attempt: _connectionAttempt,
      previousState: _networkPhase.label,
      category: category,
    );
    _firstFailure ??= failure;
    _lastFailure = failure;
    _log(failure.toString());
    _phase(VisionNetworkPhase.error);
  }

  void _set(VisionState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  void _log(String message) {
    _diagnostics.insert(0, '${_now().toIso8601String()} $message');
    if (_diagnostics.length > 80) _diagnostics.removeLast();
    debugPrint('[VISION] ${_diagnostics.first}');
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _settings.removeListener(_settingsChanged);
    _discovery.dispose();
    _retry?.cancel();
    unawaited(_close());
    super.dispose();
  }
}
