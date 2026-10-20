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
        const Duration(seconds: 6),
      );
      expect(settings.settings.visionMinimumConfidence, .8);
      await settings.setVisionWebsocketUrl(' ws://laptop:8765/vision ');
      await settings.setVisionAutoReconnect(false);
      await settings.setVisionHeartbeatTimeout(const Duration(seconds: 10));
      await settings.setVisionMinimumConfidence(.92);
      final loaded = repository.load();
      expect(loaded.visionWebsocketUrl, 'ws://laptop:8765/vision');
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
        const Duration(seconds: 6),
      );
      expect(repository.load().visionMinimumConfidence, 1);
    },
  );

  test(
    'loading migrates historic URL and 5 second heartbeat on disk',
    () async {
      SharedPreferences.setMockInitialValues({
        'vision.websocket_url': 'ws://192.168.137.233:8765/',
        'vision.heartbeat_timeout_ms': 5000,
      });
      final preferences = await SharedPreferences.getInstance();
      final settings = SettingsController(SettingsRepository(preferences));
      addTearDown(settings.dispose);
      await settings.load();
      expect(
        settings.settings.visionWebsocketUrl,
        'ws://192.168.137.233:8765/vision',
      );
      expect(
        preferences.getString('vision.websocket_url'),
        settings.settings.visionWebsocketUrl,
      );
      expect(preferences.getInt('vision.heartbeat_timeout_ms'), 6000);
      await settings.setVisionWebsocketUrl('ws://192.168.137.233:8765/vision/');
      expect(
        preferences.getString('vision.websocket_url'),
        'ws://192.168.137.233:8765/vision',
      );
      await settings.setVisionHeartbeatTimeout(const Duration(seconds: 5));
      expect(
        settings.settings.visionHeartbeatTimeout,
        const Duration(seconds: 6),
      );
    },
  );
}
