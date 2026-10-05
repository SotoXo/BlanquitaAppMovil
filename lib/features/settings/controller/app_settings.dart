import 'package:flutter/material.dart';

enum GlassIntensity { low, medium, high }

class AppSettings {
  const AppSettings({
    this.websocketUrl = '',
    this.autoReconnect = true,
    this.hapticsEnabled = true,
    this.confirmSequence = true,
    this.glassEnabled = true,
    this.glassIntensity = GlassIntensity.medium,
    this.reduceMotion = false,
    this.performanceMode = false,
    this.themeMode = ThemeMode.dark,
    this.showWarnings = true,
    this.strongLimitFeedback = true,
    this.connectionLossAlerts = true,
    this.visualSensitivity = 0.65,
    this.cameraName = 'No configurada',
    this.visionTargetFps = 30,
  });

  final String websocketUrl;
  final bool autoReconnect;
  final bool hapticsEnabled;
  final bool confirmSequence;
  final bool glassEnabled;
  final GlassIntensity glassIntensity;
  final bool reduceMotion;
  final bool performanceMode;
  final ThemeMode themeMode;
  final bool showWarnings;
  final bool strongLimitFeedback;
  final bool connectionLossAlerts;
  final double visualSensitivity;
  final String cameraName;
  final int visionTargetFps;

  AppSettings copyWith({
    String? websocketUrl,
    bool? autoReconnect,
    bool? hapticsEnabled,
    bool? confirmSequence,
    bool? glassEnabled,
    GlassIntensity? glassIntensity,
    bool? reduceMotion,
    bool? performanceMode,
    ThemeMode? themeMode,
    bool? showWarnings,
    bool? strongLimitFeedback,
    bool? connectionLossAlerts,
    double? visualSensitivity,
    String? cameraName,
    int? visionTargetFps,
  }) {
    return AppSettings(
      websocketUrl: websocketUrl ?? this.websocketUrl,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      confirmSequence: confirmSequence ?? this.confirmSequence,
      glassEnabled: glassEnabled ?? this.glassEnabled,
      glassIntensity: glassIntensity ?? this.glassIntensity,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      performanceMode: performanceMode ?? this.performanceMode,
      themeMode: themeMode ?? this.themeMode,
      showWarnings: showWarnings ?? this.showWarnings,
      strongLimitFeedback: strongLimitFeedback ?? this.strongLimitFeedback,
      connectionLossAlerts: connectionLossAlerts ?? this.connectionLossAlerts,
      visualSensitivity: visualSensitivity ?? this.visualSensitivity,
      cameraName: cameraName ?? this.cameraName,
      visionTargetFps: visionTargetFps ?? this.visionTargetFps,
    );
  }
}
