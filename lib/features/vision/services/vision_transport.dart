import 'package:web_socket_channel/web_socket_channel.dart';

abstract interface class VisionTransport {
  Stream<dynamic> get messages;
  Future<void> get ready;
  int? get closeCode;
  String? get closeReason;
  void add(String message);
  Future<void> close();
}

class ChannelVisionTransport implements VisionTransport {
  ChannelVisionTransport(this.channel);
  final WebSocketChannel channel;
  @override
  Stream<dynamic> get messages => channel.stream;
  @override
  Future<void> get ready => channel.ready;
  @override
  int? get closeCode => channel.closeCode;
  @override
  String? get closeReason => channel.closeReason;
  @override
  void add(String message) => channel.sink.add(message);
  @override
  Future<void> close() async {
    await channel.sink.close();
  }
}
