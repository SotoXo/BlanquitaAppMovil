import 'dart:io';

({String category, int? httpStatus}) visionErrorDetails(Object error) {
  if (error is WebSocketException) {
    return (
      category: error.httpStatusCode == null
          ? 'WebSocketException'
          : 'HTTP ${error.httpStatusCode}',
      httpStatus: error.httpStatusCode,
    );
  }
  if (error is HandshakeException) {
    return (category: 'HandshakeException', httpStatus: null);
  }
  if (error is SocketException) {
    final code = error.osError?.errorCode;
    final message = error.message.toLowerCase();
    return (
      category:
          [61, 111, 1225, 10061].contains(code) || message.contains('refused')
          ? 'Connection refused'
          : [60, 110, 10060].contains(code)
          ? 'Timeout TCP'
          : message.contains('host lookup') || message.contains('resolve')
          ? 'DNS'
          : 'SocketException',
      httpStatus: null,
    );
  }
  return (category: error.runtimeType.toString(), httpStatus: null);
}
