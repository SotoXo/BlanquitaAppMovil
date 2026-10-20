import 'dart:convert';
import 'package:blanquita/core/models/esp32_device.dart';
import 'package:blanquita/core/storage/esp32_credential_store.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/esp32_test_peer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'secure store adapter persists a credential and removes only requested identity',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const first = SecureEsp32CredentialStore();
      await first.write(testDeviceId, testSecret);
      await first.write('another', 'f' * 64);
      const reopened = SecureEsp32CredentialStore();
      expect(await reopened.read(testDeviceId), testSecret);
      await reopened.delete(testDeviceId);
      expect(await first.read(testDeviceId), isNull);
      expect(await first.read('another'), 'f' * 64);
    },
  );
  test(
    'public identity and custom name persist without IP becoming identity',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settings = SettingsController(SettingsRepository(preferences));
      await settings.load();
      const device = Esp32Device(
        deviceId: testDeviceId,
        name: 'Cartesiano principal',
        deviceType: Esp32Device.cartesianType,
        ip: '10.4.5.6',
      );
      await settings.selectEsp32(device);
      await settings.selectEsp32(device.copyWith(ip: '172.20.10.4'));
      final loaded = SettingsRepository(preferences).load();
      expect(loaded.selectedEsp32!.deviceId, testDeviceId);
      expect(loaded.selectedEsp32!.name, 'Cartesiano principal');
      expect(loaded.selectedEsp32!.ip, '172.20.10.4');
      expect(loaded.laboratoryEnabled, false);
      settings.dispose();
    },
  );
  test(
    'corrupt public identity fails closed and never enables laboratory by itself',
    () async {
      for (final text in [
        '{',
        '[]',
        jsonEncode({'deviceId': 4, 'port': 81}),
      ]) {
        SharedPreferences.setMockInitialValues({'esp32.selected_device': text});
        final loaded = SettingsRepository(
          await SharedPreferences.getInstance(),
        ).load();
        expect(loaded.selectedEsp32, isNull);
        expect(loaded.laboratoryEnabled, false);
      }
    },
  );
}
