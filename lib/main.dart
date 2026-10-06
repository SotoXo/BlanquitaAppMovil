import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/settings_repository.dart';
import 'core/diagnostics/connection_log.dart';
import 'core/websocket/machine_controller.dart';
import 'features/settings/controller/settings_controller.dart';
import 'features/vision/controller/vision_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final originalErrorHandler = FlutterError.onError;
  var reportingFrameworkError = false;
  FlutterError.onError = (details) {
    if (!reportingFrameworkError) {
      reportingFrameworkError = true;
      try {
        ConnectionLog.shared.add(
          channel: ConnectionChannel.system,
          level: ConnectionLogLevel.critical,
          humanMessage:
              'Se produjo un error de interfaz. Copia la bitácora para revisar el contexto.',
          technicalMessage: '${details.exceptionAsString()}\n${details.stack}',
          errorCode: 'FLUTTER_FRAMEWORK_ERROR',
          phase: 'widgets',
        );
      } finally {
        reportingFrameworkError = false;
      }
    }
    originalErrorHandler?.call(details);
  };

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
      visionController: VisionController(settingsController),
    ),
  );
}
