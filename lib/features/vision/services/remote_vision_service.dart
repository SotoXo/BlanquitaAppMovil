import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/vision_message.dart';
import '../domain/vision_endpoint.dart';
import 'vision_transport.dart';
import 'vision_transport_web.dart'
    if (dart.library.io) 'vision_transport_io.dart';
import 'vision_protocol_parser.dart';

/// Owns vision sockets only. Each attempt has its own session, so an obsolete
/// connection cannot close or deliver messages to a newer connection.
class RemoteVisionService {
  RemoteVisionService({this.channelFactory});

  final WebSocketChannel Function(Uri)? channelFactory;

  VisionSession open(Uri uri) {
    final endpoint = VisionEndpoint.parse(uri.toString());
    final factory = channelFactory;
    return VisionSession(
      factory == null
          ? openVisionTransport(endpoint)
          : ChannelVisionTransport(factory(endpoint)),
    );
  }

  static bool isValidUrl(String value) {
    return VisionEndpoint.isValid(value);
  }
}

class VisionSession {
  VisionSession(this._transport);
  final VisionTransport _transport;
  Stream<dynamic> get messages => _transport.messages;
  Future<void> get ready => _transport.ready;
  int? get closeCode => _transport.closeCode;
  String? get closeReason => _transport.closeReason;
  Future<void> close() async {
    await _transport.close();
  }

  void send(VisionCommand command, String messageId, DateTime timestamp) {
    _transport.add(
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
