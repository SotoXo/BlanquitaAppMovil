import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class TestVisionSink implements WebSocketSink {
  TestVisionSink({this.closeDelay});
  final Future<void>? closeDelay;
  final sent = <String>[];
  bool closed = false;
  final _done = Completer<void>();
  @override
  void add(dynamic data) => sent.add(data as String);
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
    if (closeDelay != null) await closeDelay;
    if (!_done.isCompleted) _done.complete();
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
  TestVisionChannel({Future<void>? handshake, TestVisionSink? sink})
    : ready = handshake ?? Future.value(),
      sink = sink ?? TestVisionSink();
  final incoming = StreamController<dynamic>(sync: true);
  @override
  final TestVisionSink sink;
  @override
  final Future<void> ready;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
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

  void establish(DateTime timestamp) {
    receive('vision.hello', timestamp);
    receive('vision.ready', timestamp);
    receive('vision.heartbeat', timestamp);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
