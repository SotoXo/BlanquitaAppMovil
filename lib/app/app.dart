import '../features/settings/controller/app_settings.dart';
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
import 'presentation/blanquita_splash.dart';
import 'design/blanquita_design.dart';
import 'design/visual_transition.dart';

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
  Timer? _startupTimer;
  bool _startupPending = false;
  bool _inactive = false;

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
      _startupPending = true;
      _startupTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted && !_inactive) _startConnections();
      });
    }
  }

  void _startConnections() {
    _startupPending = false;
    _startupTimer?.cancel();
    // Empty endpoints enter discovery; neither flow waits for the other.
    unawaited(widget.machineController.connect());
    unawaited(widget.visionController.connect());
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
      _inactive = false;
      widget.machineController.handleAppResumed();
      widget.visionController.handleAppResumed();
      if (_startupPending) _startConnections();
    } else {
      unawaited(_wifiController.pause());
      _inactive = true;
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
      child: Selector<SettingsController, AppSettings>(
        selector: (_, controller) => controller.settings,
        shouldRebuild: (a, b) =>
            a.themeMode != b.themeMode ||
            a.visualTheme != b.visualTheme ||
            a.font != b.font ||
            a.textSize != b.textSize ||
            a.density != b.density ||
            a.customAccent != b.customAccent ||
            a.reduceMotion != b.reduceMotion ||
            a.performanceMode != b.performanceMode ||
            a.shadowsEnabled != b.shadowsEnabled,
        child: const StartupPresentation(child: MainShell()),
        builder: (context, settings, shell) {
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
              title: 'BLANQUITA ALFRESI',
              debugShowCheckedModeBanner: false,
              theme: BlanquitaDesign.build(settings, Brightness.light),
              darkTheme: BlanquitaDesign.build(settings, Brightness.dark),
              themeMode: settings.themeMode,
              themeAnimationDuration:
                  settings.reduceMotion ||
                      settings.performanceMode ||
                      MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : BlanquitaDesign.theme,
              themeAnimationCurve: BlanquitaDesign.curve,
              builder: (context, child) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(
                    textScaler: BlanquitaTextScaler(
                      media.textScaler,
                      BlanquitaDesign.textScale(settings),
                    ),
                    disableAnimations:
                        media.disableAnimations ||
                        settings.reduceMotion ||
                        settings.performanceMode,
                  ),
                  child: VisualTransition(
                    theme: settings.visualTheme,
                    child: child!,
                  ),
                );
              },
              home: shell,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _wifiController.dispose();
    widget.machineController.dispose();
    widget.visionController.dispose();
    widget.settingsController.dispose();
    super.dispose();
  }
}
