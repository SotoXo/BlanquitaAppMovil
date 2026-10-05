import 'dart:async';
import 'dart:io';

class DiscoveryTransport {
  DiscoveryTransport({
    required this.port,
    required this.timeout,
    required this.retryInterval,
    required this.broadcastAddress,
  });

  final int port;
  final Duration timeout;
  final Duration retryInterval;
  final String broadcastAddress;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Timer? _deadline;
  Timer? _retry;
  Completer<Uri?>? _pending;
  int _generation = 0;
  bool _disposed = false;

  Future<Uri?> discover({
    required List<int> request,
    required Uri? Function(List<int>, String) parseResponse,
  }) {
    cancel();
    if (_disposed) return Future.value();
    final generation = _generation;
    final pending = Completer<Uri?>();
    _pending = pending;
    _deadline = Timer(timeout, () => _finish(null));
    unawaited(_listen(generation, request, parseResponse));
    return pending.future;
  }

  Future<void> _listen(
    int generation,
    List<int> request,
    Uri? Function(List<int>, String) parseResponse,
  ) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      if (generation != _generation || _pending == null || _disposed) {
        socket.close();
        return;
      }
      _socket = socket;
      socket.broadcastEnabled = true;
      socket.writeEventsEnabled = false;
      _subscription = socket.listen(
        (event) {
          if (generation != _generation) return;
          if (event == RawSocketEvent.read) {
            Datagram? packet;
            while ((packet = socket.receive()) != null) {
              final candidate = parseResponse(
                packet!.data,
                packet.address.address,
              );
              if (candidate != null) {
                _finish(candidate);
                return;
              }
            }
          } else if (event == RawSocketEvent.closed) {
            _finish(null);
          }
        },
        onError: (Object _) {
          if (generation == _generation) _finish(null);
        },
        onDone: () {
          if (generation == _generation) _finish(null);
        },
      );
      final destination = InternetAddress(broadcastAddress);
      var attempts = 0;
      void send() {
        if (generation != _generation || _pending == null) return;
        try {
          socket.send(request, destination, port);
          attempts++;
          if (attempts >= 3) _retry?.cancel();
        } catch (_) {
          _finish(null);
        }
      }

      send();
      if (_pending != null && generation == _generation) {
        _retry = Timer.periodic(retryInterval, (_) => send());
      }
    } catch (_) {
      if (generation == _generation) _finish(null);
    }
  }

  void _finish(Uri? result) {
    ++_generation;
    _deadline?.cancel();
    _retry?.cancel();
    _deadline = null;
    _retry = null;
    final pending = _pending;
    _pending = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _socket?.close();
    _socket = null;
    if (pending != null && !pending.isCompleted) pending.complete(result);
  }

  void cancel() => _finish(null);

  void dispose() {
    _disposed = true;
    cancel();
  }
}
