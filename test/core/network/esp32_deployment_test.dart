import 'package:blanquita/features/settings/controller/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/network/esp32_discovery_service.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/core/models/esp32_device.dart';

class _EmptyDiscovery extends Esp32DiscoveryService {
  @override
  Future<List<Esp32Device>> discoverDevices() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('multi-device deployment overrides persisted laboratory preference', () {
    const settings = AppSettings(esp32LaboratoryMode: true);
    expect(settings.laboratoryEnabled, !AppSettings.multiDeviceDeployment);
    expect(const AppSettings().laboratoryEnabled, false);
  });
  test(
    'deployment build cannot open legacy socket despite saved opt-in',
    () async {
      if (!AppSettings.multiDeviceDeployment) return;
      SharedPreferences.setMockInitialValues({
        'esp32.laboratory_mode': true,
        'connection.websocket_url': 'ws://10.1.1.2:81/',
        'connection.auto_reconnect': false,
      });
      final settings = SettingsController(
        SettingsRepository(await SharedPreferences.getInstance()),
      );
      await settings.load();
      final machine = MachineController(
        settings,
        discoveryService: _EmptyDiscovery(),
        channelFactory: (_) =>
            throw StateError('must never open a legacy socket'),
      );
      await machine.connect();
      expect(machine.hasValidConnection, false);
      expect(machine.laboratoryEnabled, false);
      machine.dispose();
      settings.dispose();
    },
  );
}
