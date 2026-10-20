import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/settings/controller/app_settings.dart';
import '../../features/vision/domain/vision_endpoint.dart';
import '../models/esp32_device.dart';

class SettingsRepository {
  const SettingsRepository(this._preferences);

  final SharedPreferences _preferences;

  Future<void> migrateVisionEndpoint() async {
    final stored = _preferences.getString(_Keys.visionWebsocketUrl) ?? '';
    if (stored.trim().isNotEmpty && VisionEndpoint.isValid(stored)) {
      final normalized = VisionEndpoint.normalize(stored);
      if (stored != normalized) {
        await _preferences.setString(_Keys.visionWebsocketUrl, normalized);
      }
    }
    final oldTimeout = _preferences.getInt(_Keys.visionHeartbeatTimeout);
    if (oldTimeout != null && oldTimeout < 6000) {
      await _preferences.setInt(_Keys.visionHeartbeatTimeout, 6000);
    }
  }

  AppSettings load() {
    return AppSettings(
      websocketUrl: _preferences.getString(_Keys.websocketUrl) ?? '',
      esp32LaboratoryMode: _preferences.getBool(_Keys.laboratoryMode) ?? false,
      selectedEsp32: _loadDevice(),
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
      visionWebsocketUrl: _visionEndpoint(),
      visionAutoReconnect:
          _preferences.getBool(_Keys.visionAutoReconnect) ?? true,
      visionHeartbeatTimeout: Duration(
        milliseconds:
            (_preferences.getInt(_Keys.visionHeartbeatTimeout) ?? 6000).clamp(
              6000,
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
      _preferences.setBool(_Keys.laboratoryMode, settings.esp32LaboratoryMode),
      if (settings.selectedEsp32 == null)
        _preferences.remove(_Keys.selectedEsp32)
      else
        _preferences.setString(
          _Keys.selectedEsp32,
          jsonEncode(settings.selectedEsp32!.toJson()),
        ),
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
        _normalizeStoredVisionUrl(settings.visionWebsocketUrl),
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

  Esp32Device? _loadDevice() {
    try {
      return Esp32Device.fromJson(
        jsonDecode(_preferences.getString(_Keys.selectedEsp32) ?? 'null'),
      );
    } on FormatException {
      return null;
    }
  }

  String _visionEndpoint() => _normalizeStoredVisionUrl(
    _preferences.getString(_Keys.visionWebsocketUrl) ?? '',
  );

  String _normalizeStoredVisionUrl(String value) =>
      value.trim().isEmpty || VisionEndpoint.isValid(value)
      ? VisionEndpoint.normalize(value)
      : value.trim(); // Keep invalid historic input editable, never open it.

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

abstract final class _Keys {
  static const laboratoryMode = 'esp32.laboratory_mode';
  static const selectedEsp32 = 'esp32.selected_device';
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
