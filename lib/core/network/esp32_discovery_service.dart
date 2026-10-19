import 'dart:convert';

import '../models/esp32_device.dart';
import 'discovery_collector_stub.dart'
    if (dart.library.io) 'discovery_collector_io.dart';

import 'discovery_transport_stub.dart'
    if (dart.library.io) 'discovery_transport_io.dart';

/// UDP candidates are untrusted; only the V2 handshake proves identity.
class Esp32DiscoveryService {
  Esp32DiscoveryService({
    int port = discoveryPort,
    Duration timeout = const Duration(seconds: 3),
    Duration retryInterval = const Duration(seconds: 1),
    String broadcastAddress = '255.255.255.255',
  }) : _port = port,
       _timeout = timeout,
       _retryInterval = retryInterval,
       _broadcastAddress = broadcastAddress,
       _transport = DiscoveryTransport(
         port: port,
         timeout: timeout,
         retryInterval: retryInterval,
         broadcastAddress: broadcastAddress,
       );

  static const discoveryPort = 4210;
  static const request = 'BLANQUITA_DISCOVER';
  static const response = 'BLANQUITA_HERE:81';
  static const requestV2 = 'BLANQUITA_DISCOVER_V2';
  final DiscoveryTransport _transport;
  final _collector = DiscoveryCollector();
  final int _port;
  final Duration _timeout;
  final Duration _retryInterval;
  final String _broadcastAddress;

  Future<List<Esp32Device>> discoverDevices() async {
    final results = await _collector.collect<Esp32Device>(
      port: _port,
      timeout: _timeout,
      retryInterval: _retryInterval,
      broadcastAddress: _broadcastAddress,
      request: utf8.encode(requestV2),
      parse: parseV2Response,
    );
    final unique = <String, Esp32Device>{};
    for (final device in results) {
      unique['${device.deviceId}|${device.ip}|${device.port}'] = device;
    }
    return unique.values.toList();
  }

  static Esp32Device? parseV2Response(List<int> data, String sourceAddress) {
    if (data.length > 256) return null;
    try {
      final fields = utf8.decode(data).split('|');
      if (fields.length != 4 ||
          fields[0] != 'BLANQUITA_HERE_V2' ||
          !Esp32Device.validId(fields[1]) ||
          fields[2] != Esp32Device.cartesianType ||
          fields[3] != '81' ||
          parseResponse(utf8.encode(response), sourceAddress) == null) {
        return null;
      }
      return Esp32Device(
        deviceId: fields[1],
        name: 'BLANQUITA ${fields[1]}',
        deviceType: fields[2],
        ip: sourceAddress,
      );
    } on FormatException {
      return null;
    }
  }

  Future<Uri?> discover() => _transport.discover(
    request: utf8.encode(request),
    parseResponse: parseResponse,
  );

  void cancel() {
    _transport.cancel();
    _collector.cancel();
  }

  void dispose() {
    _transport.dispose();
    _collector.dispose();
  }

  static Uri? parseResponse(List<int> data, String sourceAddress) {
    try {
      if (utf8.decode(data) != response) return null;
    } on FormatException {
      return null;
    }
    final parts = sourceAddress.split('.');
    if (parts.length != 4) return null;
    final octets = <int>[];
    for (final part in parts) {
      if (!RegExp(r'^(0|[1-9]\d{0,2})$').hasMatch(part)) return null;
      final octet = int.parse(part);
      if (octet > 255) return null;
      octets.add(octet);
    }
    if (octets.first == 0 || octets.first >= 224) {
      return null;
    }
    return Uri(scheme: 'ws', host: sourceAddress, port: 81, path: '/');
  }
}
