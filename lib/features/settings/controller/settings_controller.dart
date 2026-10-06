import 'package:flutter/material.dart';

import '../../../core/storage/settings_repository.dart';
import '../../../core/diagnostics/connection_log.dart';
import 'app_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repository);

  final SettingsRepository _repository;
  AppSettings _settings = const AppSettings();
  Future<void> _pendingSave = Future.value();
  bool _disposed = false;

  AppSettings get settings => _settings;

  Future<void> load() async {
    _settings = _repository.load();
    notifyListeners();
  }

  Future<void> _update(AppSettings next) {
    // Serialize snapshots so an earlier save cannot overwrite newer settings.
    _settings = next;
    final save = _pendingSave.then((_) async {
      try {
        await _repository.save(next);
        if (!_disposed && identical(_settings, next)) notifyListeners();
      } catch (error, stackTrace) {
        ConnectionLog.shared.add(
          channel: ConnectionChannel.system,
          level: ConnectionLogLevel.error,
          humanMessage: 'No se pudieron guardar los ajustes en el teléfono.',
          technicalMessage: '${error.runtimeType}: $error\n$stackTrace',
          errorCode: 'SETTINGS_SAVE_FAILED',
          phase: 'persistence',
        );
        rethrow;
      }
    });
    _pendingSave = save.catchError((Object _) {});
    return save;
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
  Future<void> setVisionWebsocketUrl(String value) =>
      _update(_settings.copyWith(visionWebsocketUrl: value.trim()));
  Future<void> setVisionAutoReconnect(bool value) =>
      _update(_settings.copyWith(visionAutoReconnect: value));
  Future<void> setVisionHeartbeatTimeout(Duration value) => _update(
    _settings.copyWith(
      visionHeartbeatTimeout: Duration(
        milliseconds: value.inMilliseconds.clamp(1000, 60000),
      ),
    ),
  );
  Future<void> setVisionMinimumConfidence(double value) => _update(
    _settings.copyWith(visionMinimumConfidence: value.clamp(0.0, 1.0)),
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
