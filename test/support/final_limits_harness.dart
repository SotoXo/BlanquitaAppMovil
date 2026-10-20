import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/vision/support/vision_test_channel.dart';

class FinalLimitsHarness {
  late SettingsController settings;
  late MachineController machine;
  final channels = <TestVisionChannel>[];

  TestVisionChannel get channel => channels.last;
  List<String> get sent => channel.sink.sent;

  Future<void> setup({bool haptics = false}) async {
    SharedPreferences.setMockInitialValues({
      'connection.websocket_url': 'ws://esp32.test:81/',
      'esp32.laboratory_mode': true,
      'connection.auto_reconnect': false,
      'control.haptics': haptics,
      'appearance.performance_mode': true,
      'appearance.reduce_motion': true,
    });
    settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await settings.load();
    machine = MachineController(
      settings,
      channelFactory: (_) {
        final channel = TestVisionChannel();
        channels.add(channel);
        return channel;
      },
    );
  }

  Future<void> connect({bool withReadings = true}) async {
    final pending = machine.connect();
    receive('READY');
    await pending;
    if (withReadings) freeLimits();
  }

  void receive(String payload) => channel.incoming.add(payload);
  void freeLimits() {
    for (final name in ['X_IZQ', 'X_DER', 'Z_ARRIBA', 'Z_ABAJO']) {
      receive('SENSOR:FC:$name:0');
    }
  }

  void reading(FinalLimit limit, bool active) =>
      receive('SENSOR:FC:${limit.protocolName}:${active ? 1 : 0}');

  Future<void> close() async {
    machine.dispose();
    settings.dispose();
    for (final channel in channels) {
      await channel.incoming.close();
    }
  }
}
