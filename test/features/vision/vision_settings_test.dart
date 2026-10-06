import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'vision settings persist independently and default to no fixed IP',
    () async {
      SharedPreferences.setMockInitialValues({
        'connection.websocket_url': 'ws://esp32:81/',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences);
      final settings = SettingsController(repository);
      addTearDown(settings.dispose);
      await settings.load();
      expect(settings.settings.visionWebsocketUrl, '');
      expect(settings.settings.visionAutoReconnect, true);
      expect(
        settings.settings.visionHeartbeatTimeout,
        const Duration(seconds: 5),
      );
      expect(settings.settings.visionMinimumConfidence, .8);
      await settings.setVisionWebsocketUrl(' ws://laptop:8765/ ');
      await settings.setVisionAutoReconnect(false);
      await settings.setVisionHeartbeatTimeout(const Duration(seconds: 10));
      await settings.setVisionMinimumConfidence(.92);
      final loaded = repository.load();
      expect(loaded.visionWebsocketUrl, 'ws://laptop:8765/');
      expect(loaded.visionAutoReconnect, false);
      expect(loaded.visionHeartbeatTimeout, const Duration(seconds: 10));
      expect(loaded.visionMinimumConfidence, .92);
      expect(loaded.websocketUrl, 'ws://esp32:81/');
      expect(loaded.autoReconnect, true);
    },
  );

  test(
    'persisted timeout and confidence are bounded for UI and liveness',
    () async {
      SharedPreferences.setMockInitialValues({
        'vision.heartbeat_timeout_ms': -1,
        'vision.minimum_confidence': 12.0,
      });
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );
      expect(
        repository.load().visionHeartbeatTimeout,
        const Duration(seconds: 1),
      );
      expect(repository.load().visionMinimumConfidence, 1);
    },
  );
}
