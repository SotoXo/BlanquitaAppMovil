class WifiNetworkStatus {
  const WifiNetworkStatus({
    this.supported = false,
    this.wifiEnabled = false,
    this.connected = false,
    this.localIpv4,
    this.rssiDbm,
    this.linkSpeedMbps,
    this.defaultRouteWifi,
    this.internetValidated,
    this.networkHandle,
  });
  final bool supported;
  final bool wifiEnabled;
  final bool connected;
  final String? localIpv4;
  final int? rssiDbm;
  final int? linkSpeedMbps;
  final bool? defaultRouteWifi;
  final bool? internetValidated;
  final String? networkHandle;

  factory WifiNetworkStatus.fromMap(Map<Object?, Object?> value) {
    if (value['supported'] is! bool ||
        value['wifiEnabled'] is! bool ||
        value['connected'] is! bool) {
      throw const FormatException('Respuesta de estado Wi-Fi incompleta');
    }
    final rssi = (value['rssiDbm'] as num?)?.toInt();
    final speed = (value['linkSpeedMbps'] as num?)?.toInt();
    return WifiNetworkStatus(
      supported: value['supported'] as bool,
      wifiEnabled: value['wifiEnabled'] as bool,
      connected: value['connected'] as bool,
      localIpv4: value['localIpv4'] as String?,
      rssiDbm: rssi != null && rssi >= -126 && rssi < 0 ? rssi : null,
      linkSpeedMbps: speed != null && speed > 0 ? speed : null,
      defaultRouteWifi: value['defaultRouteWifi'] as bool?,
      internetValidated: value['internetValidated'] as bool?,
      networkHandle: value['networkHandle'] as String?,
    );
  }

  String get signalLabel => rssiDbm == null
      ? 'No informada'
      : rssiDbm! >= -60
      ? 'Fuerte'
      : rssiDbm! >= -70
      ? 'Media'
      : 'Débil';
}
