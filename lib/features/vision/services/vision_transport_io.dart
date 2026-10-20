import 'dart:async';
import 'dart:io';

import 'vision_transport.dart';

VisionTransport openVisionTransport(Uri uri) => _NativeVisionTransport(uri);

/// Own the TCP connection as well as the upgrade. Closing a channel sink alone
/// does not cancel WebSocket.connect while its HTTP handshake is pending.
class _NativeVisionTransport implements VisionTransport {
  _NativeVisionTransport(Uri uri) {
    _client.findProxy = (_) => 'DIRECT';
    _client.connectionFactory = (target, proxyHost, proxyPort) async {
      final task = await Socket.startConnect(target.host, target.port);
      _task = task;
      if (_closed) task.cancel();
      unawaited(
        task.socket.then<void>((socket) {
          _tcp = socket;
          if (_closed) socket.destroy();
        }, onError: (Object _, StackTrace stack) {}),
      );
      return task;
    };
    _opening = WebSocket.connect(uri.toString(), customClient: _client).then((
      socket,
    ) {
      _socket = socket;
      if (_closed) {
        _tcp?.destroy();
        throw StateError('Intento WebSocket cancelado');
      }
      return socket;
    });
    ready = _opening.then<void>((_) {});
  }

  final HttpClient _client = HttpClient();
  ConnectionTask<Socket>? _task;
  Socket? _tcp;
  WebSocket? _socket;
  bool _closed = false;
  late final Future<WebSocket> _opening;
  @override
  late final Future<void> ready;
  @override
  Stream<dynamic> get messages =>
      Stream<WebSocket>.fromFuture(_opening).asyncExpand((socket) => socket);
  @override
  int? get closeCode => _socket?.closeCode;
  @override
  String? get closeReason => _socket?.closeReason;
  @override
  void add(String message) => _socket!.add(message);
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _task?.cancel();
    _tcp?.destroy();
    _client.close(force: true);
    // Do not let the next attempt race a still-settling connect/upgrade future.
    try {
      await _opening;
    } catch (_) {
      // The original error is reported by ready/messages, before reconnection.
    }
  }
}
