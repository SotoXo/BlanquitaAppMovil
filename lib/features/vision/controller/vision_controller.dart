import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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
    this.connectionTimeout = const Duration(seconds: 8),
    this.reconnectBaseDelay = const Duration(seconds: 1),
    this.tickInterval = const Duration(seconds: 1),
  }) : _service = service ?? RemoteVisionService(),
       _now = now ?? DateTime.now,
       _previousSettings = _settings.settings {
    _settings.addListener(_settingsChanged);
  }

  final SettingsController _settings;
  final RemoteVisionService _service;
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
  List<String> get diagnostics => List.unmodifiable(_diagnostics);
  int get reconnectAttempts => _attempt;
  bool get isConnecting =>
      state.connection == VisionConnection.connecting ||
      state.connection == VisionConnection.reconnecting;

  Future<void> connect() async {
    if (_disposed || _inactive || state.isConnected || isConnecting) return;
    _desiredConnection = true;
    _retry?.cancel();
    final url = endpoint;
    if (!RemoteVisionService.isValidUrl(url)) {
      _desiredConnection = false;
      _set(
        state.copyWith(
          connection: VisionConnection.error,
          error: 'Configura una URL ws:// o wss:// válida para la laptop.',
        ),
      );
      return;
    }
    final generation = ++_generation;
    // Clear session telemetry; old reports must not describe a new server.
    _set(const VisionState(connection: VisionConnection.connecting));
    try {
      final session = _service.open(Uri.parse(url));
      _session = session;
      // Subscribe before awaiting ready, so early hello/ready are not lost and
      // connection errors have a handler while the handshake is pending.
      _subscription = session.messages.listen(
        (raw) {
          if (_current(generation)) _receive(raw);
        },
        onError: (Object error) {
          if (_current(generation)) {
            unawaited(_lost('WebSocket de visión: $error'));
          }
        },
        onDone: () {
          if (_current(generation)) {
            unawaited(_lost('Vision Server desconectado'));
          }
        },
      );
      await session.ready.timeout(connectionTimeout);
      if (!_current(generation)) return;
      _connectedAt = _now();
      _lastPingAt = null;
      _set(
        state.copyWith(
          connection: VisionConnection.connected,
          clearError: true,
        ),
      );
      _log('WebSocket conectado: $url');
      _timer = Timer.periodic(tickInterval, (_) => _tick());
      ping();
    } catch (error) {
      if (_current(generation)) {
        await _lost('No se pudo conectar al visor: $error');
      }
    }
  }

  Future<void> disconnect() async {
    _desiredConnection = false;
    _retry?.cancel();
    _attempt = 0;
    ++_generation;
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
    if (heartbeat || message.type == VisionMessageType.ready) _attempt = 0;
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
    if (stale && !state.stale) _log('Heartbeat de visión vencido');
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
    _log(error);
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
    _timer?.cancel();
    _timer = null;
    _pings.clear();
    final subscription = _subscription;
    final session = _session;
    _subscription = null;
    _session = null;
    if (subscription != null) await subscription.cancel();
    if (session != null) {
      try {
        await session.close().timeout(const Duration(seconds: 2));
      } catch (_) {
        /* The peer may already be gone. */
      }
    }
  }

  void _settingsChanged() {
    final next = _settings.settings;
    final previous = _previousSettings;
    _previousSettings = next;
    if (next.visionWebsocketUrl != previous.visionWebsocketUrl) {
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
    _inactive = true;
    _retry?.cancel();
    ++_generation;
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
    _retry?.cancel();
    unawaited(_close());
    super.dispose();
  }
}
