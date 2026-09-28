import 'package:flutter/material.dart';

import '../../../core/storage/settings_repository.dart';
import 'app_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repository);

  final SettingsRepository _repository;
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> load() async {
    _settings = _repository.load();
    notifyListeners();
  }

  Future<void> _update(AppSettings next) async {
    _settings = next;
    notifyListeners();
    await _repository.save(next);
  }

  Future<void> setWebsocketUrl(String value) =>
      _update(_settings.copyWith(websocketUrl: value.trim()));
  Future<void> setAutoReconnect(bool value) =>
      _update(_settings.copyWith(autoReconnect: value));
  Future<void> setHapticsEnabled(bool value) =>
      _update(_settings.copyWith(hapticsEnabled: value));
  Future<void> setConfirmSequence(bool value) =>
      _update(_settings.copyWith(confirmSequence: value));
  Future<void> setGlassEnabled(bool value) =>
      _update(_settings.copyWith(glassEnabled: value));
  Future<void> setGlassIntensity(GlassIntensity value) =>
      _update(_settings.copyWith(glassIntensity: value));
  Future<void> setReduceMotion(bool value) =>
      _update(_settings.copyWith(reduceMotion: value));
  Future<void> setPerformanceMode(bool value) =>
      _update(_settings.copyWith(performanceMode: value));
  Future<void> setThemeMode(ThemeMode value) =>
      _update(_settings.copyWith(themeMode: value));
  Future<void> setShowWarnings(bool value) =>
      _update(_settings.copyWith(showWarnings: value));
  Future<void> setStrongLimitFeedback(bool value) =>
      _update(_settings.copyWith(strongLimitFeedback: value));
  Future<void> setConnectionLossAlerts(bool value) =>
      _update(_settings.copyWith(connectionLossAlerts: value));
  Future<void> setVisualSensitivity(double value) =>
      _update(_settings.copyWith(visualSensitivity: value));
  Future<void> setCameraName(String value) =>
      _update(_settings.copyWith(cameraName: value));
  Future<void> setVisionTargetFps(int value) =>
      _update(_settings.copyWith(visionTargetFps: value));
}
