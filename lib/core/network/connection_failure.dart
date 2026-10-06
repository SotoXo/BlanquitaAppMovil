import 'dart:async';

import '../diagnostics/connection_log.dart';

abstract final class EndpointValidation {
  static Uri? parse(String value) {
    try {
      final authority =
          RegExp(r'^wss?://([^/?#]*)').firstMatch(value.trim())?.group(1) ?? '';
      final hostSuffix = authority.startsWith('[')
          ? authority.substring(authority.indexOf(']') + 1)
          : authority.contains(':')
          ? authority.substring(authority.lastIndexOf(':'))
          : '';
      if (hostSuffix.startsWith(':')) {
        final port = int.tryParse(hostSuffix.substring(1));
        if (port == null || port < 1 || port > 65535) return null;
      }
      final uri = Uri.tryParse(value.trim());
      if (uri == null ||
          !['ws', 'wss'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          ['0.0.0.0', '::', '[::]'].contains(uri.host) ||
          uri.hasFragment ||
          uri.userInfo.isNotEmpty ||
          (uri.hasPort && (uri.port < 1 || uri.port > 65535)) ||
          RegExp(r'\s').hasMatch(value.trim())) {
        return null;
      }
      return uri;
    } on FormatException {
      return null;
    }
  }
}

class ConnectionFailure {
  const ConnectionFailure(this.code, this.humanMessage, this.technicalMessage);
  final String code;
  final String humanMessage;
  final String technicalMessage;

  static ConnectionFailure classify(Object error, {required String device}) {
    final text = error.toString().toLowerCase();
    final code = error is TimeoutException
        ? 'CONNECT_TIMEOUT'
        : text.contains('refused') ||
              text.contains('errno = 111') ||
              text.contains('10061')
        ? 'CONNECTION_REFUSED'
        : text.contains('unreachable') ||
              text.contains('no route') ||
              text.contains('10065')
        ? 'HOST_UNREACHABLE'
        : text.contains('failed host lookup') ||
              text.contains('name or service')
        ? 'HOST_LOOKUP_FAILED'
        : text.contains('handshake') ||
              text.contains('not upgraded') ||
              text.contains('websocketexception')
        ? 'HANDSHAKE_FAILED'
        : 'TRANSPORT_ERROR';
    final human = switch (code) {
      'CONNECT_TIMEOUT' =>
        'No fue posible establecer comunicación con $device. Verifica la misma red local y la dirección.',
      'CONNECTION_REFUSED' =>
        '$device rechazó la conexión. Revisa que el servidor WebSocket escuche en el puerto configurado.',
      'HOST_UNREACHABLE' =>
        'El teléfono no puede alcanzar a $device. Comprueba la misma red y el posible aislamiento de clientes del router.',
      'HOST_LOOKUP_FAILED' =>
        'No se pudo resolver el nombre de $device. Revisa el host o configura su IP local.',
      'HANDSHAKE_FAILED' =>
        '$device no aceptó el protocolo WebSocket. Revisa la URL, puerto y ruta del servidor.',
      _ =>
        'Se interrumpió la comunicación con $device. Revisa el servidor y la red local.',
    };
    return ConnectionFailure(
      code,
      human,
      redactConnectionText('${error.runtimeType}: $error'),
    );
  }
}
