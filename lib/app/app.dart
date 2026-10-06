import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/websocket/machine_controller.dart';
import '../core/diagnostics/connection_log.dart';
import '../core/network/wifi_network_controller.dart';
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
    this.wifiController,
  });

  final SettingsController settingsController;
  final MachineController machineController;
  final VisionController visionController;
  final bool autoConnect;
  final WifiNetworkController? wifiController;

  @override
  State<BlanquitaApp> createState() => _BlanquitaAppState();
}

class _BlanquitaAppState extends State<BlanquitaApp>
    with WidgetsBindingObserver {
  late final WifiNetworkController _wifiController;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wifiController = widget.wifiController ?? WifiNetworkController();
    unawaited(_wifiController.start());
    ConnectionLog.shared.add(
      channel: ConnectionChannel.system,
      humanMessage: 'Aplicación iniciada',
      phase: 'startup',
      technicalMessage:
          'Dos clientes WebSocket independientes; red esperada CARTESIANO',
    );
    if (widget.autoConnect) {
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) {
          if (widget.settingsController.settings.websocketUrl.isNotEmpty) {
            widget.machineController.connect();
          }
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
    ConnectionLog.shared.add(
      channel: ConnectionChannel.system,
      humanMessage: state == AppLifecycleState.resumed
          ? 'Aplicación volvió a primer plano'
          : 'Aplicación cambió de estado: ${state.name}',
      phase: state.name,
      technicalMessage: 'lifecycle=${state.name}',
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(_wifiController.start());
      widget.machineController.handleAppResumed();
      widget.visionController.handleAppResumed();
    } else {
      unawaited(_wifiController.pause());
      widget.machineController.handleAppInactive();
      widget.visionController.handleAppInactive();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WifiNetworkController>.value(
          value: _wifiController,
        ),
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
              title: 'BLANQUITA Víctor',
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
    _wifiController.dispose();
    widget.machineController.dispose();
    widget.visionController.dispose();
    widget.settingsController.dispose();
    super.dispose();
  }
}
