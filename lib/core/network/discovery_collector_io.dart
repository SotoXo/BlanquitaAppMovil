import 'dart:async';
import 'dart:io';

/// Collects throughout the entire window. Cancellation discards partial results.
class DiscoveryCollector {
  void Function()? _cancel;
  bool _disposed = false;

  Future<List<T>> collect<T>({
    required int port,
    required Duration timeout,
    required Duration retryInterval,
    required String broadcastAddress,
    required List<int> request,
    required T? Function(List<int>, String) parse,
  }) async {
    cancel();
    if (_disposed) return [];
    final pending = Completer<List<T>>();
    final results = <T>[];
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    Timer? retry;
    Timer? deadline;
    void finish({bool discard = false}) {
      if (pending.isCompleted) return;
      deadline?.cancel();
      retry?.cancel();
      if (subscription != null) unawaited(subscription.cancel());
      socket?.close();
      pending.complete(discard ? [] : results);
      _cancel = null;
    }

    _cancel = () => finish(discard: true);
    deadline = Timer(timeout, finish);
    try {
      final opened = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      if (pending.isCompleted) {
        opened.close();
        return pending.future;
      }
      socket = opened;
      opened.broadcastEnabled = true;
      opened.writeEventsEnabled = false;
      subscription = opened.listen(
        (event) {
          if (pending.isCompleted) return;
          if (event == RawSocketEvent.read) {
            Datagram? packet;
            var readCount = 0;
            while (readCount++ < 256 && (packet = opened.receive()) != null) {
              if (packet!.data.length > 256 || results.length >= 128) continue;
              final candidate = parse(packet.data, packet.address.address);
              if (candidate != null) results.add(candidate);
            }
          }
        },
        onError: (Object _) => finish(discard: true),
        onDone: finish,
      );
      var attempts = 0;
      void send() {
        if (pending.isCompleted) return;
        try {
          opened.send(request, InternetAddress(broadcastAddress), port);
          if (++attempts >= 3) retry?.cancel();
        } catch (_) {
          finish(discard: true);
        }
      }

      retry = Timer.periodic(retryInterval, (_) => send());
      send();
    } catch (_) {
      finish(discard: true);
    }
    return pending.future;
  }

  void cancel() => _cancel?.call();
  void dispose() {
    _disposed = true;
    cancel();
  }
}
