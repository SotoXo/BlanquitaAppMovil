enum Esp32LinkPhase {
  found('Encontrado'),
  connecting('Conectando'),
  identityVerified('Identidad verificada'),
  authenticating('Autenticando'),
  authorized('Autorizado'),
  laboratory('Laboratorio: READY sin autenticación'),
  disconnected('Desconectado'),
  error('Error');

  const Esp32LinkPhase(this.label);
  final String label;
}

class Esp32Device {
  const Esp32Device({
    required this.deviceId,
    required this.name,
    required this.deviceType,
    required this.ip,
    this.port = 81,
    this.connection = Esp32LinkPhase.found,
  });

  static const cartesianType = 'cartesian-controller';
  static bool validId(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{1,64}$').stringMatch(value) == value;

  final String deviceId;
  final String name;
  final String deviceType;
  final String ip;
  final int port;
  final Esp32LinkPhase connection;

  Uri get uri => Uri(scheme: 'ws', host: ip, port: port, path: '/');

  Esp32Device copyWith({String? ip, Esp32LinkPhase? connection}) => Esp32Device(
    deviceId: deviceId,
    name: name,
    deviceType: deviceType,
    ip: ip ?? this.ip,
    port: port,
    connection: connection ?? this.connection,
  );

  Map<String, Object> toJson() => {
    'deviceId': deviceId,
    'name': name,
    'deviceType': deviceType,
    'ip': ip,
    'port': port,
  };

  static Esp32Device? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['deviceId'];
    final name = value['name'];
    final type = value['deviceType'];
    final ip = value['ip'];
    final port = value['port'];
    if (id is! String ||
        !validId(id) ||
        name is! String ||
        name.isEmpty ||
        name.length > 100 ||
        type != cartesianType ||
        ip is! String ||
        ip.isEmpty ||
        port != 81) {
      return null;
    }
    return Esp32Device(
      deviceId: id,
      name: name,
      deviceType: type as String,
      ip: ip,
      port: port as int,
      connection: Esp32LinkPhase.disconnected,
    );
  }
}
