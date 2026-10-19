import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class Esp32CredentialStore {
  Future<String?> read(String deviceId);
  Future<void> write(String deviceId, String secret);
  Future<void> delete(String deviceId);
}

class SecureEsp32CredentialStore implements Esp32CredentialStore {
  const SecureEsp32CredentialStore();
  static const _storage = FlutterSecureStorage();
  String _key(String id) => 'blanquita.esp32.v2.$id';
  @override
  Future<String?> read(String deviceId) => _storage.read(key: _key(deviceId));
  @override
  Future<void> write(String deviceId, String secret) =>
      _storage.write(key: _key(deviceId), value: secret);
  @override
  Future<void> delete(String deviceId) => _storage.delete(key: _key(deviceId));
}
