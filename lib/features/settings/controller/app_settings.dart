import 'package:flutter/material.dart';

enum BlanquitaVisualTheme { original, hamburger, custom }

enum BlanquitaFont { outfit, system }

enum BlanquitaTextSize { small, normal, large }

enum BlanquitaDensity { compact, normal, large }

enum GlassIntensity { low, medium, high }

class AppSettings {
  const AppSettings({
    this.visualTheme = BlanquitaVisualTheme.hamburger,
    this.font = BlanquitaFont.outfit,
    this.textSize = BlanquitaTextSize.normal,
    this.density = BlanquitaDensity.normal,
    this.customAccent = 0xFFFFC928,
    this.shadowsEnabled = true,
    this.assistantEnabled = true,
    this.assistantTips = true,
    this.assistantAlerts = true,
    this.assistantTechnical = true,
    this.assistantAnimations = true,
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
    this.visionWebsocketUrl = '',
    this.visionAutoReconnect = true,
    this.visionHeartbeatTimeout = const Duration(seconds: 5),
    this.visionMinimumConfidence = 0.8,
  });

  final BlanquitaVisualTheme visualTheme;
  final BlanquitaFont font;
  final BlanquitaTextSize textSize;
  final BlanquitaDensity density;
  final int customAccent;
  final bool shadowsEnabled;
  final bool assistantEnabled;
  final bool assistantTips;
  final bool assistantAlerts;
  final bool assistantTechnical;
  final bool assistantAnimations;
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
  final String visionWebsocketUrl;
  final bool visionAutoReconnect;
  final Duration visionHeartbeatTimeout;
  final double visionMinimumConfidence;

  AppSettings copyWith({
    BlanquitaVisualTheme? visualTheme,
    BlanquitaFont? font,
    BlanquitaTextSize? textSize,
    BlanquitaDensity? density,
    int? customAccent,
    bool? shadowsEnabled,
    bool? assistantEnabled,
    bool? assistantTips,
    bool? assistantAlerts,
    bool? assistantTechnical,
    bool? assistantAnimations,
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
    String? visionWebsocketUrl,
    bool? visionAutoReconnect,
    Duration? visionHeartbeatTimeout,
    double? visionMinimumConfidence,
  }) {
    return AppSettings(
      visualTheme: visualTheme ?? this.visualTheme,
      font: font ?? this.font,
      textSize: textSize ?? this.textSize,
      density: density ?? this.density,
      customAccent: customAccent ?? this.customAccent,
      shadowsEnabled: shadowsEnabled ?? this.shadowsEnabled,
      assistantEnabled: assistantEnabled ?? this.assistantEnabled,
      assistantTips: assistantTips ?? this.assistantTips,
      assistantAlerts: assistantAlerts ?? this.assistantAlerts,
      assistantTechnical: assistantTechnical ?? this.assistantTechnical,
      assistantAnimations: assistantAnimations ?? this.assistantAnimations,
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
      visionWebsocketUrl: visionWebsocketUrl ?? this.visionWebsocketUrl,
      visionAutoReconnect: visionAutoReconnect ?? this.visionAutoReconnect,
      visionHeartbeatTimeout:
          visionHeartbeatTimeout ?? this.visionHeartbeatTimeout,
      visionMinimumConfidence:
          visionMinimumConfidence ?? this.visionMinimumConfidence,
    );
  }
}
