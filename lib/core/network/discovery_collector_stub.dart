class DiscoveryCollector {
  Future<List<T>> collect<T>({
    required int port,
    required Duration timeout,
    required Duration retryInterval,
    required String broadcastAddress,
    required List<int> request,
    required T? Function(List<int>, String) parse,
  }) async => [];
  void cancel() {}
  void dispose() {}
}
