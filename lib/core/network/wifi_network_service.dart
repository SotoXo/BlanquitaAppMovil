import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'wifi_network_status.dart';

/// Reads Android connectivity only. Does not scan, connect or bind networks.
class WifiNetworkService {
  WifiNetworkService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    bool? platformSupported,
  }) : _method = methodChannel ?? const MethodChannel('blanquita/network'),
       _events = eventChannel ?? const EventChannel('blanquita/network/events'),
       _supported =
           platformSupported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  final MethodChannel _method;
  final EventChannel _events;
  final bool _supported;

  Future<WifiNetworkStatus> read() async {
    if (!_supported) return const WifiNetworkStatus();
    try {
      final value = await _method.invokeMapMethod<Object?, Object?>(
        'getWifiStatus',
      );
      if (value == null) {
        throw const FormatException('Sin respuesta de Android');
      }
      return WifiNetworkStatus.fromMap(value);
    } on MissingPluginException {
      return const WifiNetworkStatus();
    }
  }

  Stream<WifiNetworkStatus> watch() => !_supported
      ? const Stream.empty()
      : _events.receiveBroadcastStream().map(
          (value) => WifiNetworkStatus.fromMap(value as Map<Object?, Object?>),
        );

  /// Diagnostic TCP reachability of one configured endpoint via Wi-Fi.
  /// This neither validates WebSocket nor sends protocol/control commands.
  Future<Map<Object?, Object?>> probeEndpointOnWifi(Uri endpoint) async {
    if (!_supported) {
      return {'connected': false, 'errorCode': 'UNSUPPORTED_PLATFORM'};
    }
    return await _method
            .invokeMapMethod<Object?, Object?>('probeWifiTcp', {
              'host': endpoint.host,
              'port': endpoint.hasPort
                  ? endpoint.port
                  : endpoint.scheme == 'wss'
                  ? 443
                  : 80,
            })
            .timeout(const Duration(seconds: 5)) ??
        {'connected': false, 'errorCode': 'NO_RESPONSE'};
  }
}
