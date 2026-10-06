import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/websocket/machine_controller.dart';
import '../features/settings/controller/settings_controller.dart';
import '../features/vision/controller/vision_controller.dart';
import 'navigation/main_shell.dart';
import 'theme/app_theme.dart';

class BlanquitaApp extends StatefulWidget {
  const BlanquitaApp({
    super.key,
    required this.settingsController,
    required this.machineController,
    required this.visionController,
    this.autoConnect = true,
  });

  final SettingsController settingsController;
  final MachineController machineController;
  final VisionController visionController;
  final bool autoConnect;

  @override
  State<BlanquitaApp> createState() => _BlanquitaAppState();
}

class _BlanquitaAppState extends State<BlanquitaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoConnect) {
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) {
          widget.machineController.connect();
          if (widget
              .settingsController
              .settings
              .visionWebsocketUrl
              .isNotEmpty) {
            widget.visionController.connect();
          }
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.machineController.handleAppResumed();
      widget.visionController.handleAppResumed();
    } else {
      widget.machineController.handleAppInactive();
      widget.visionController.handleAppInactive();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(
          value: widget.settingsController,
        ),
        ChangeNotifierProvider<MachineController>.value(
          value: widget.machineController,
        ),
        ChangeNotifierProvider<VisionController>.value(
          value: widget.visionController,
        ),
      ],
      child: Consumer<SettingsController>(
        builder: (context, controller, _) {
          final settings = controller.settings;
          final overlays = settings.themeMode == ThemeMode.light
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlays.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
            ),
            child: MaterialApp(
              title: 'BLANQUITA',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: settings.themeMode,
              home: const MainShell(),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.machineController.dispose();
    widget.visionController.dispose();
    widget.settingsController.dispose();
    super.dispose();
  }
}
