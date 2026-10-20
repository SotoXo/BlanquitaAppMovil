/// The desktop contract has one endpoint, shared by discovery, settings and IO.
abstract final class VisionEndpoint {
  static const port = 8765;
  static const path = '/vision';
  static const heartbeatTimeout = Duration(seconds: 6);

  static Uri fromHost(String host, {int port = VisionEndpoint.port}) {
    if (host.isEmpty || port < 1 || port > 65535) {
      throw const FormatException('Host o puerto de Vision inválido');
    }
    return Uri(scheme: 'ws', host: host, port: port, path: path);
  }

  static Uri parse(String value) {
    final specifiedPort = RegExp(
      r'^ws://(?:\[[^\]]+\]|[^/?#:@]+):(\d+)',
    ).firstMatch(value.trim())?[1];
    if (int.tryParse(specifiedPort ?? '') == 0) {
      throw const FormatException('Puerto Vision fuera de rango');
    }
    final uri = Uri.parse(value.trim());
    if (uri.scheme != 'ws' ||
        uri.host.isEmpty ||
        uri.host.contains(RegExp(r'\s')) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        (uri.path != '' &&
            uri.path != '/' &&
            uri.path != path &&
            uri.path != '$path/') ||
        (uri.hasFragment &&
            !((uri.path.isEmpty || uri.path == '/') &&
                (uri.fragment == path || uri.fragment == '$path/')))) {
      throw const FormatException(
        'Vision requiere ws://HOST:PUERTO/vision, sin query ni fragmento',
      );
    }
    return fromHost(uri.host, port: uri.hasPort ? uri.port : port);
  }

  static String normalize(String value) =>
      value.trim().isEmpty ? '' : parse(value).toString();

  static bool isValid(String value) {
    try {
      parse(value);
      return true;
    } on FormatException {
      return false;
    }
  }
}
