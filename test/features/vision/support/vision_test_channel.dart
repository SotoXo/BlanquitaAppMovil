import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class TestVisionSink implements WebSocketSink {
  final sent = <String>[];
  bool closed = false;
  Object? closeError;
  final _done = Completer<void>();
  @override
  void add(dynamic data) => sent.add(data as String);
  @override
  Future<void> close([int? closeCode, String? closeReason]) {
    closed = true;
    if (!_done.isCompleted) _done.complete();
    if (closeError != null) return Future<void>.error(closeError!);
    return Future<void>.value();
  }

  @override
  Future<void> get done => _done.future;
  @override
  void addError(Object error, [StackTrace? stackTrace]) => throw error;
  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final item in stream) {
      add(item);
    }
  }
}

class TestVisionChannel implements WebSocketChannel {
  TestVisionChannel({Future<void>? handshake})
    : ready = handshake ?? Future.value();
  final incoming = StreamController<dynamic>(sync: true);
  @override
  final TestVisionSink sink = TestVisionSink();
  @override
  final Future<void> ready;
  @override
  Stream<dynamic> get stream => incoming.stream;
  void receive(
    String type,
    DateTime timestamp, [
    Map<String, Object?> payload = const {},
  ]) {
    incoming.add(
      jsonEncode({
        'protocol': 'blanquita-vision',
        'version': 1,
        'type': type,
        'messageId': 'server-${timestamp.microsecondsSinceEpoch}',
        'timestamp': timestamp.toUtc().toIso8601String(),
        'payload': payload,
      }),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
