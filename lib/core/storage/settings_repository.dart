import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/settings/controller/app_settings.dart';

class SettingsRepository {
  const SettingsRepository(this._preferences);

  final SharedPreferences _preferences;

  AppSettings load() {
    return AppSettings(
      websocketUrl: _preferences.getString(_Keys.websocketUrl) ?? '',
      autoReconnect: _preferences.getBool(_Keys.autoReconnect) ?? true,
      hapticsEnabled: _preferences.getBool(_Keys.hapticsEnabled) ?? true,
      confirmSequence: _preferences.getBool(_Keys.confirmSequence) ?? true,
      glassEnabled: _preferences.getBool(_Keys.glassEnabled) ?? true,
      glassIntensity: _enumByName(
        GlassIntensity.values,
        _preferences.getString(_Keys.glassIntensity),
        GlassIntensity.medium,
      ),
      reduceMotion: _preferences.getBool(_Keys.reduceMotion) ?? false,
      performanceMode: _preferences.getBool(_Keys.performanceMode) ?? false,
      themeMode: _enumByName(
        ThemeMode.values,
        _preferences.getString(_Keys.themeMode),
        ThemeMode.dark,
      ),
      showWarnings: _preferences.getBool(_Keys.showWarnings) ?? true,
      strongLimitFeedback:
          _preferences.getBool(_Keys.strongLimitFeedback) ?? true,
      connectionLossAlerts:
          _preferences.getBool(_Keys.connectionLossAlerts) ?? true,
      visualSensitivity:
          _preferences.getDouble(_Keys.visualSensitivity) ?? 0.65,
      visionWebsocketUrl:
          _preferences.getString(_Keys.visionWebsocketUrl) ?? '',
      visionAutoReconnect:
          _preferences.getBool(_Keys.visionAutoReconnect) ?? true,
      visionHeartbeatTimeout: Duration(
        milliseconds:
            (_preferences.getInt(_Keys.visionHeartbeatTimeout) ?? 5000).clamp(
              1000,
              60000,
            ),
      ),
      visionMinimumConfidence:
          (_preferences.getDouble(_Keys.visionMinimumConfidence) ?? 0.8).clamp(
            0.0,
            1.0,
          ),
    );
  }

  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _preferences.setString(_Keys.websocketUrl, settings.websocketUrl),
      _preferences.setBool(_Keys.autoReconnect, settings.autoReconnect),
      _preferences.setBool(_Keys.hapticsEnabled, settings.hapticsEnabled),
      _preferences.setBool(_Keys.confirmSequence, settings.confirmSequence),
      _preferences.setBool(_Keys.glassEnabled, settings.glassEnabled),
      _preferences.setString(
        _Keys.glassIntensity,
        settings.glassIntensity.name,
      ),
      _preferences.setBool(_Keys.reduceMotion, settings.reduceMotion),
      _preferences.setBool(_Keys.performanceMode, settings.performanceMode),
      _preferences.setString(_Keys.themeMode, settings.themeMode.name),
      _preferences.setBool(_Keys.showWarnings, settings.showWarnings),
      _preferences.setBool(
        _Keys.strongLimitFeedback,
        settings.strongLimitFeedback,
      ),
      _preferences.setBool(
        _Keys.connectionLossAlerts,
        settings.connectionLossAlerts,
      ),
      _preferences.setDouble(
        _Keys.visualSensitivity,
        settings.visualSensitivity,
      ),
      _preferences.setString(
        _Keys.visionWebsocketUrl,
        settings.visionWebsocketUrl,
      ),
      _preferences.setBool(
        _Keys.visionAutoReconnect,
        settings.visionAutoReconnect,
      ),
      _preferences.setInt(
        _Keys.visionHeartbeatTimeout,
        settings.visionHeartbeatTimeout.inMilliseconds,
      ),
      _preferences.setDouble(
        _Keys.visionMinimumConfidence,
        settings.visionMinimumConfidence,
      ),
    ]);
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

abstract final class _Keys {
  static const websocketUrl = 'connection.websocket_url';
  static const autoReconnect = 'connection.auto_reconnect';
  static const hapticsEnabled = 'control.haptics';
  static const confirmSequence = 'control.confirm_sequence';
  static const glassEnabled = 'appearance.glass';
  static const glassIntensity = 'appearance.glass_intensity';
  static const reduceMotion = 'appearance.reduce_motion';
  static const performanceMode = 'appearance.performance_mode';
  static const themeMode = 'appearance.theme_mode';
  static const showWarnings = 'safety.show_warnings';
  static const strongLimitFeedback = 'safety.strong_limit_feedback';
  static const connectionLossAlerts = 'safety.connection_loss_alerts';
  static const visualSensitivity = 'control.visual_sensitivity';
  static const visionWebsocketUrl = 'vision.websocket_url';
  static const visionAutoReconnect = 'vision.auto_reconnect';
  static const visionHeartbeatTimeout = 'vision.heartbeat_timeout_ms';
  static const visionMinimumConfidence = 'vision.minimum_confidence';
}
