import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/vision_message.dart';
import 'vision_protocol_parser.dart';

/// Owns vision sockets only. Each attempt has its own session, so an obsolete
/// connection cannot close or deliver messages to a newer connection.
class RemoteVisionService {
  RemoteVisionService({WebSocketChannel Function(Uri)? channelFactory})
    : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final WebSocketChannel Function(Uri) _channelFactory;

  VisionSession open(Uri uri) => VisionSession(_channelFactory(uri));

  static bool isValidUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'ws' || uri.scheme == 'wss') &&
        uri.host.isNotEmpty &&
        !uri.hasFragment &&
        uri.userInfo.isEmpty;
  }
}

class VisionSession {
  VisionSession(this._channel);
  final WebSocketChannel _channel;
  Stream<dynamic> get messages => _channel.stream;
  Future<void> get ready => _channel.ready;
  Future<void> close() async {
    await _channel.sink.close();
  }

  void send(VisionCommand command, String messageId, DateTime timestamp) {
    _channel.sink.add(
      jsonEncode({
        'protocol': VisionProtocolParser.protocol,
        'version': VisionProtocolParser.version,
        'type': command.wireName,
        'messageId': messageId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'payload': <String, Object?>{},
      }),
    );
  }
}
