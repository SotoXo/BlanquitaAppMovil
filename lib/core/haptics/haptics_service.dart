import 'package:flutter/services.dart';

import '../../features/settings/controller/settings_controller.dart';

class HapticsService {
  const HapticsService(this._settings);

  final SettingsController _settings;

  bool get _enabled => _settings.settings.hapticsEnabled;

  Future<void> movementStart() async {
    if (_enabled) await HapticFeedback.lightImpact();
  }

  Future<void> movementStop() async {
    if (_enabled) await HapticFeedback.selectionClick();
  }

  Future<void> action() async {
    if (_enabled) await HapticFeedback.mediumImpact();
  }

  Future<void> critical() async {
    if (_enabled) await HapticFeedback.heavyImpact();
  }
}
