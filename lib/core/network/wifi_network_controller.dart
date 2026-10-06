import 'dart:async';
import 'package:flutter/foundation.dart';
import '../diagnostics/connection_log.dart';
import 'wifi_network_service.dart';
import 'wifi_network_status.dart';
import 'connection_failure.dart';
export 'wifi_network_status.dart';

class WifiNetworkController extends ChangeNotifier {
  WifiNetworkController({
    WifiNetworkService? service,
    ConnectionLog? connectionLog,
    DateTime Function()? now,
    this.sampleInterval = const Duration(seconds: 3),
    this.observationThreshold = const Duration(seconds: 10),
  }) : _service = service ?? WifiNetworkService(),
       _log = connectionLog ?? ConnectionLog.shared,
       _now = now ?? DateTime.now;
  final WifiNetworkService _service;
  final ConnectionLog _log;
  final DateTime Function() _now;
  final Duration sampleInterval;
  final Duration observationThreshold;
  StreamSubscription<WifiNetworkStatus>? _subscription;
  Timer? _timer;
  WifiNetworkStatus _status = const WifiNetworkStatus();
  bool _checking = false;
  bool _observing = false;
  bool _disposed = false;
  bool _reportedObservation = false;
  bool _probing = false;
  int _generation = 0;
  int _eventRevision = 0;
  int _disconnects = 0;
  int _linkChanges = 0;
  String? _error;
  DateTime? _connectedSince;
  DateTime? _lastUpdatedAt;
  WifiNetworkStatus get status => _status;
  bool get checking => _checking;
  bool get probing => _probing;
  String? get error => _error;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  DateTime? get connectedSince => _connectedSince;
  int get disconnects => _disconnects;
  int get linkChanges => _linkChanges;
  Duration get observedConnectedDuration => _connectedSince == null
      ? Duration.zero
      : _now().difference(_connectedSince!).isNegative
      ? Duration.zero
      : _now().difference(_connectedSince!);
  String get stabilityLabel {
    if (_error != null) return 'Observación no disponible';
    if (!_observing) return 'Observación pausada';
    if (!_status.supported) return 'Observación no disponible';
    if (!_status.connected) return 'Sin enlace Wi-Fi';
    if (_disconnects > 0 || _linkChanges > 0) {
      return 'Se observaron $_disconnects cortes y $_linkChanges cambios de enlace en esta sesión';
    }
    if (observedConnectedDuration < observationThreshold) {
      return 'Observando enlace';
    }
    return 'Sin cortes observados durante ${observedConnectedDuration.inSeconds} s';
  }

  Map<String, String> get snapshot => {
    'Wi-Fi observado': !_status.supported
        ? 'No disponible'
        : _status.connected
        ? 'Conectado'
        : 'Sin conexión',
    'IP Wi-Fi del teléfono': _status.localIpv4 ?? 'No informada',
    'Señal Wi-Fi':
        '${_status.signalLabel}${_status.rssiDbm == null ? '' : ' (${_status.rssiDbm} dBm)'}',
    'Velocidad de enlace Wi-Fi': _status.linkSpeedMbps == null
        ? 'No informada'
        : '${_status.linkSpeedMbps} Mbps (enlace, no rendimiento medido)',
    'Observación Wi-Fi': stabilityLabel,
    'Cortes Wi-Fi observados': '$_disconnects',
    'Cambios de enlace Wi-Fi': '$_linkChanges',
    'Ruta principal Wi-Fi':
        _status.defaultRouteWifi?.toString() ?? 'No informada',
    'Internet validado en Wi-Fi':
        _status.internetValidated?.toString() ??
        'No informado; no es requisito LAN',
    'Última observación Wi-Fi':
        _lastUpdatedAt?.toIso8601String() ?? 'Sin consulta',
    'Error al observar Wi-Fi': ?_error,
  };

  Future<void> start() async {
    if (_disposed || _observing) return;
    _observing = true;
    final generation = ++_generation;
    _connectedSince = null;
    _disconnects = 0;
    _linkChanges = 0;
    _reportedObservation = false;
    _lastUpdatedAt = null;
    _status = const WifiNetworkStatus();
    _error = null;
    await refresh();
    if (!_current(generation)) return;
    _attachBackend(generation);
    if (_error != null && _timer == null) {
      _timer ??= Timer.periodic(sampleInterval, (_) {
        unawaited(refresh());
      });
    }
  }

  void _attachBackend(int generation) {
    if (!_current(generation) || !_status.supported || _subscription != null) {
      return;
    }
    _subscription = _service.watch().listen(
      (value) {
        if (_current(generation)) {
          ++_eventRevision;
          _accept(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_current(generation)) _failure(error, stackTrace);
      },
    );
    _timer ??= Timer.periodic(sampleInterval, (_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_disposed || !_observing || _checking) return;
    final generation = _generation;
    final eventRevision = _eventRevision;
    _checking = true;
    notifyListeners();
    try {
      final value = await _service.read().timeout(const Duration(seconds: 3));
      if (_current(generation) && eventRevision == _eventRevision) {
        _accept(value);
        _attachBackend(generation);
      }
    } catch (error, stackTrace) {
      if (_current(generation) && eventRevision == _eventRevision) {
        _failure(error, stackTrace);
      }
    } finally {
      if (_current(generation)) {
        _checking = false;
        notifyListeners();
      }
    }
  }

  void _accept(WifiNetworkStatus value) {
    final previous = _status;
    final previousTime = _lastUpdatedAt;
    _status = value;
    _lastUpdatedAt = _now();
    _error = null;
    final linkChanged =
        previous.connected &&
        value.connected &&
        previous.networkHandle != null &&
        value.networkHandle != null &&
        previous.networkHandle != value.networkHandle;
    if (previous.connected && !value.connected && value.supported) {
      ++_disconnects;
    }
    if (linkChanged) ++_linkChanges;
    if (!value.connected) {
      _connectedSince = null;
      _reportedObservation = false;
    } else if (_connectedSince == null || !previous.connected || linkChanged) {
      _connectedSince = _now();
      _reportedObservation = false;
    }
    if (previousTime == null ||
        previous.connected != value.connected ||
        linkChanged ||
        previous.supported != value.supported ||
        previous.wifiEnabled != value.wifiEnabled ||
        previous.signalLabel != value.signalLabel ||
        previous.defaultRouteWifi != value.defaultRouteWifi) {
      _log.add(
        channel: ConnectionChannel.network,
        level: value.connected
            ? ConnectionLogLevel.success
            : ConnectionLogLevel.info,
        humanMessage: !value.supported
            ? 'La observación Wi-Fi no está disponible en esta plataforma.'
            : value.connected
            ? 'Android informa un enlace Wi-Fi conectado.'
            : value.wifiEnabled
            ? 'Wi-Fi activado, sin un enlace conectado.'
            : 'Wi-Fi desactivado en el teléfono.',
        phase: 'wifi_observation',
        technicalMessage: snapshot.entries
            .map((row) => '${row.key}=${row.value}')
            .join('\n'),
      );
    }
    if (!_reportedObservation &&
        value.connected &&
        observedConnectedDuration >= observationThreshold) {
      _reportedObservation = true;
      _log.add(
        channel: ConnectionChannel.network,
        humanMessage: stabilityLabel,
        phase: 'wifi_observation_window',
        technicalMessage:
            'No es una prueba de alcance de ESP32/laptop ni de Internet.',
      );
    }
    notifyListeners();
  }

  void _failure(Object error, StackTrace stackTrace) {
    _error =
        'No se pudo consultar el estado Wi-Fi. Actualiza la observación o vuelve a abrir la app.';
    _status = const WifiNetworkStatus();
    _connectedSince = null;
    _reportedObservation = false;
    _log.add(
      channel: ConnectionChannel.network,
      level: ConnectionLogLevel.warning,
      humanMessage: _error!,
      errorCode: 'NETWORK_OBSERVATION_FAILED',
      phase: 'wifi_observation',
      technicalMessage: '${error.runtimeType}: $error\n$stackTrace',
    );
    notifyListeners();
  }

  Future<void> pause() async {
    if (_disposed) return;
    _observing = false;
    _probing = false;
    ++_generation;
    _checking = false;
    _timer?.cancel();
    _timer = null;
    final subscription = _subscription;
    _subscription = null;
    _connectedSince = null;
    notifyListeners();
    if (subscription != null) await _cancel(subscription);
  }

  Future<void> _cancel(
    StreamSubscription<WifiNetworkStatus> subscription,
  ) async {
    try {
      await subscription.cancel();
    } catch (error, stackTrace) {
      _log.add(
        channel: ConnectionChannel.network,
        level: ConnectionLogLevel.warning,
        humanMessage: 'No se pudo completar el cierre de la observación Wi-Fi.',
        technicalMessage: '${error.runtimeType}: $error\n$stackTrace',
        phase: 'wifi_cleanup',
      );
    }
  }

  Future<Map<Object?, Object?>> probeEndpoint(
    Uri endpoint, {
    String deviceLabel = 'el servidor',
  }) async {
    if (_disposed ||
        !_observing ||
        !_status.connected ||
        _probing ||
        EndpointValidation.parse(endpoint.toString()) == null) {
      return {'connected': false, 'errorCode': 'WIFI_PROBE_UNAVAILABLE'};
    }
    final generation = _generation;
    _probing = true;
    notifyListeners();
    _log.add(
      channel: ConnectionChannel.network,
      humanMessage:
          'Comprobando el puerto de $deviceLabel a través de la Wi-Fi.',
      endpoint: endpoint.toString(),
      phase: 'wifi_tcp_probe',
    );
    try {
      Map<Object?, Object?> result;
      try {
        result = await _service.probeEndpointOnWifi(endpoint);
      } catch (error, stackTrace) {
        result = {
          'connected': false,
          'errorCode': 'WIFI_PROBE_FAILED',
          'technicalMessage': '${error.runtimeType}: $error\n$stackTrace',
        };
      }
      if (!_current(generation)) {
        return {'connected': false, 'errorCode': 'PROBE_CANCELLED'};
      }
      final code = result['errorCode'] as String?;
      final human = result['connected'] == true
          ? 'El puerto de $deviceLabel respondió por Wi-Fi. Esto confirma TCP; aún falta validar WebSocket y su protocolo.'
          : switch (code) {
              'HOST_UNREACHABLE' =>
                'El teléfono no puede alcanzar a $deviceLabel por Wi-Fi. Revisa la IP actual, equipo encendido, misma LAN y posible aislamiento de clientes.',
              'CONNECTION_REFUSED' =>
                'La dirección respondió por Wi-Fi, pero el puerto de $deviceLabel rechazó la conexión. Comprueba que el servidor esté escuchando.',
              'CONNECT_TIMEOUT' =>
                'El puerto de $deviceLabel no respondió por Wi-Fi dentro del tiempo permitido. Revisa IP, servidor y comunicación entre clientes.',
              'HOST_LOOKUP_FAILED' =>
                'No se pudo resolver el nombre de $deviceLabel mediante la Wi-Fi. Revisa el host o usa su IP local.',
              _ =>
                'No se pudo comprobar el puerto de $deviceLabel por Wi-Fi. Consulta los detalles técnicos.',
            };
      _log.add(
        channel: ConnectionChannel.network,
        level: result['connected'] == true
            ? ConnectionLogLevel.success
            : ConnectionLogLevel.warning,
        humanMessage: human,
        technicalMessage: result.toString(),
        errorCode: code,
        endpoint: endpoint.toString(),
        phase: 'wifi_tcp_probe',
      );
      return {...result, 'humanMessage': human};
    } finally {
      if (_current(generation)) {
        _probing = false;
        notifyListeners();
      }
    }
  }

  bool _current(int generation) =>
      !_disposed && _observing && generation == _generation;
  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(_cancel(subscription));
    super.dispose();
  }
}
