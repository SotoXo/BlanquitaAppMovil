import 'dart:convert';

import '../../../core/network/discovery_transport_stub.dart'
    if (dart.library.io) '../../../core/network/discovery_transport_io.dart';

/// UDP supplies a candidate only. A versioned vision.ready validates the server.
class VisionDiscoveryService {
  VisionDiscoveryService({
    int port = discoveryPort,
    Duration timeout = const Duration(seconds: 3),
    Duration retryInterval = const Duration(seconds: 1),
    String broadcastAddress = '255.255.255.255',
  }) : _transport = DiscoveryTransport(
         port: port,
         timeout: timeout,
         retryInterval: retryInterval,
         broadcastAddress: broadcastAddress,
       );

  static const discoveryPort = 4211;
  static const websocketPort = 8765;
  static const request = 'BLANQUITA_VISION_DISCOVER';
  static const response = 'BLANQUITA_VISION_HERE:8765';
  final DiscoveryTransport _transport;

  Future<Uri?> discover() => _transport.discover(
    request: utf8.encode(request),
    parseResponse: parseResponse,
  );

  void cancel() => _transport.cancel();
  void dispose() => _transport.dispose();

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
    if (octets.first == 0 || octets.first >= 224) return null;
    return Uri(
      scheme: 'ws',
      host: sourceAddress,
      port: websocketPort,
      path: '/',
    );
  }
}
