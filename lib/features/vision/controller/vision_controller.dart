import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../settings/controller/app_settings.dart';
import '../../settings/controller/settings_controller.dart';
import '../domain/vision_message.dart';
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
  bool get isConnecting =>
      _flowActive || state.connection == VisionConnection.connecting;

  Future<void> connect() async {
    if (_disposed || _inactive || state.isConnected || isConnecting) return;
    await _connectFlow();
  }

  Future<void> saveEndpointAndReconnect(String value) async {
    if (_disposed) return;
    // Invalidate old discovery/socket callbacks before accepting a manual URL.
    final closing = disconnect();
    final generation = _generation;
    await closing;
    if (!_current(generation)) return;
    final url = value.trim();
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
    _closeSocket();
    final generation = ++_generation;
    _flowActive = true;
    _isDiscovering = false;
    _connectionUrl = null;
    final knownUrl = endpoint;
    _set(const VisionState(connection: VisionConnection.connecting));
    try {
      if (!discoveryFirst && RemoteVisionService.isValidUrl(knownUrl)) {
        if (await _attemptWebsocket(Uri.parse(knownUrl), generation)) return;
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
      _connectionUrl = null;
      _set(
        state.copyWith(
          connection: VisionConnection.disconnected,
          status: state.status.merge(const VisionStatus(ready: false)),
          stale: true,
          error:
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

  Future<bool> _attemptWebsocket(Uri uri, int generation) async {
    if (!_current(generation)) return false;
    _closeSocket();
    final socketGeneration = _socketGeneration;
    final handshake = Completer<bool>();
    _pendingHandshake = handshake;
    _connectionUrl = uri.toString();
    // Each candidate is a new session, never reuse previous telemetry.
    _set(const VisionState(connection: VisionConnection.connecting));
    _log('Conectando a $uri; esperando vision.ready');
    bool currentSocket() =>
        _current(generation) && socketGeneration == _socketGeneration;
    void failed(String reason) {
      if (!currentSocket()) return;
      if (_pendingHandshake != null) {
        _log(reason);
        _set(state.copyWith(error: reason));
        _closeSocket();
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
        onError: (Object error) {
          failed('WebSocket de visión: $error');
        },
        onDone: () => failed('Vision Server desconectado'),
      );
      _handshakeTimer = Timer(
        connectionTimeout,
        () => failed('El visor no envió vision.ready dentro del timeout.'),
      );
      unawaited(
        session.ready.then<void>(
          (_) {
            if (!currentSocket()) return;
            _transportReady = true;
            _completeHandshake();
          },
          onError: (Object error, StackTrace stack) =>
              failed('No se pudo abrir el WebSocket: $error'),
        ),
      );
    } catch (error) {
      failed('No se pudo conectar al visor: $error');
    }
    return handshake.future;
  }

  void _completeHandshake() {
    final handshake = _pendingHandshake;
    if (handshake == null ||
        !_transportReady ||
        !_serverReady ||
        state.status.ready != true) {
      return;
    }
    _pendingHandshake = null;
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    _connectedAt = _now();
    _lastPingAt = null;
    _attempt = 0;
    final socketGeneration = _socketGeneration;
    _set(
      state.copyWith(connection: VisionConnection.connected, clearError: true),
    );
    if (_disposed || socketGeneration != _socketGeneration) {
      if (!handshake.isCompleted) handshake.complete(false);
      return;
    }
    _log('Visor validado con vision.ready: $_connectionUrl');
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
    } catch (error) {
      unawaited(_lost('Error enviando ${command.wireName}: $error'));
    }
  }

  void _receive(Object? raw) {
    final result = _parser.parse(raw);
    if (result.error != null) {
      _log('RX rechazado: ${result.error}');
      _set(state.copyWith(error: result.error));
      return;
    }
    if (result.ignored) {
      _log('RX ignorado: tipo desconocido');
      return;
    }
    final message = result.message!;
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
    if (message.type == VisionMessageType.ready) {
      _serverReady = message.status.ready == true;
      _completeHandshake();
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
    final stale = baseline != null && _age(baseline) > _timeout;
    if (stale) {
      unawaited(_lost('Heartbeat de visión vencido; recuperando conexión.'));
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
    _set(state.copyWith(connection: VisionConnection.reconnecting));
    _log('Reconexión en ${delay.inMilliseconds} ms');
    _retry = Timer(delay, () {
      if (_disposed || !_desiredConnection || _inactive) return;
      _set(state.copyWith(connection: VisionConnection.disconnected));
      unawaited(connect());
    });
  }

  Future<void> _close() async {
    _closeSocket();
  }

  void _closeSocket() {
    ++_socketGeneration;
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    final handshake = _pendingHandshake;
    _pendingHandshake = null;
    if (handshake != null && !handshake.isCompleted) handshake.complete(false);
    _transportReady = false;
    _serverReady = false;
    _timer?.cancel();
    _timer = null;
    _pings.clear();
    final subscription = _subscription;
    final session = _session;
    _subscription = null;
    _session = null;
    if (subscription != null) {
      unawaited(_ignoreCloseError(subscription.cancel()));
    }
    if (session != null) unawaited(_ignoreCloseError(session.close()));
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
    if (_desiredConnection && _settings.settings.visionAutoReconnect) {
      unawaited(connect());
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _set(VisionState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  void _log(String message) {
    _diagnostics.insert(0, '${_now().toIso8601String()} $message');
    if (_diagnostics.length > 80) _diagnostics.removeLast();
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
