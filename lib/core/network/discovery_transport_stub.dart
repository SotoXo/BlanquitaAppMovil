/// Browsers cannot open raw UDP sockets. Manual WebSocket remains available.
class DiscoveryTransport {
  DiscoveryTransport({
    required int port,
    required Duration timeout,
    required Duration retryInterval,
    required String broadcastAddress,
  });

  Future<Uri?> discover({
    required List<int> request,
    required Uri? Function(List<int>, String) parseResponse,
  }) async => null;

  void cancel() {}
  void dispose() {}
}
