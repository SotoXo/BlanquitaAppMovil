import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/settings_repository.dart';
import 'core/websocket/machine_controller.dart';
import 'features/settings/controller/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final settingsController = SettingsController(
    SettingsRepository(preferences),
  );
  await settingsController.load();

  final machineController = MachineController(settingsController);

  runApp(
    BlanquitaApp(
      settingsController: settingsController,
      machineController: machineController,
    ),
  );
}
