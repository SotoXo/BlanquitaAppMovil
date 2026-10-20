import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/vision_error_details.dart'
    if (dart.library.io) '../services/vision_error_details_io.dart';

class VisionNetworkFailure {
  VisionNetworkFailure({
    required Object error,
    required this.stack,
    required this.uri,
    required this.timestamp,
    required this.attempt,
    required this.previousState,
    String? category,
  }) {
    while (error is WebSocketChannelException && error.inner != null) {
      error = error.inner!;
    }
    final details = visionErrorDetails(error);
    type = error.runtimeType.toString();
    message = error.toString();
    httpStatus = details.httpStatus;
    this.category =
        category ??
        (error is FormatException || error is ArgumentError
            ? 'URI inválida'
            : error is TimeoutException
            ? 'Timeout TCP/upgrade'
            : message.toLowerCase().contains('cleartext') ||
                  message.toLowerCase().contains('network security')
            ? 'Cleartext/network security'
            : details.category);
  }

  final StackTrace stack;
  final String uri;
  final DateTime timestamp;
  final int attempt;
  final String previousState;
  late final String category;
  late final String type;
  late final String message;
  late final int? httpStatus;

  String get summary => '$category · $message';
  @override
  String toString() =>
      'VISION_WS_ERROR timestamp=${timestamp.toIso8601String()} '
      'attempt=$attempt previousState=$previousState\n'
      'effective URI: $uri\ncategory: $category\n'
      'exception type: $type\nexception message: $message\n'
      'HTTP status: ${httpStatus ?? 'no disponible'}\n'
      'HTTP headers/reason: no expuestos por dart:io WebSocket.connect\n'
      'stack trace:\n$stack';
}
