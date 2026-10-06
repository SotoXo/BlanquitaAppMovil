import 'dart:async';
import 'package:flutter/foundation.dart';

enum ConnectionChannel { system, control, vision, network }

enum ConnectionLogLevel { info, success, warning, error, critical }

/// Remove credentials, query values and fragments before storing diagnostics.
String redactConnectionText(String text) =>
    text.replaceAllMapped(RegExp(r'(?:wss?|https?)://[^\s<>]+'), (match) {
      final uri = Uri.tryParse(match[0]!);
      if (uri == null) return '[endpoint inválido]';
      return uri
          .removeFragment()
          .replace(userInfo: '', query: '')
          .toString()
          .replaceFirst(RegExp(r'\?$'), '');
    });

class ConnectionLogEntry {
  ConnectionLogEntry({
    required this.timestamp,
    required this.channel,
    required this.level,
    required this.humanMessage,
    required this.technicalMessage,
    this.errorCode,
    this.endpoint,
    this.phase,
    this.attempt,
  });
  final DateTime timestamp;
  final ConnectionChannel channel;
  final ConnectionLogLevel level;
  final String humanMessage;
  final String technicalMessage;
  final String? errorCode;
  final String? endpoint;
  final String? phase;
  final int? attempt;

  String get formatted =>
      '[${timestamp.toIso8601String()}] '
      '${channel.name.toUpperCase()} ${level.name.toUpperCase()}\n'
      '$humanMessage\n'
      'channel=${channel.name} phase=${phase ?? "—"} attempt=${attempt ?? "—"}\n'
      '${endpoint == null ? "" : "endpoint=$endpoint\n"}'
      '${errorCode == null ? "" : "ERROR_CODE=$errorCode\n"}'
      '$technicalMessage';
}

class ConnectionLog extends ChangeNotifier {
  static final shared = ConnectionLog();
  static const capacity = 240;
  final List<ConnectionLogEntry> _entries = [];
  bool _notificationScheduled = false;
  bool _disposed = false;
  List<ConnectionLogEntry> get entries => List.unmodifiable(_entries);

  void add({
    required ConnectionChannel channel,
    ConnectionLogLevel level = ConnectionLogLevel.info,
    required String humanMessage,
    String technicalMessage = '',
    String? errorCode,
    String? endpoint,
    String? phase,
    int? attempt,
  }) {
    final entry = ConnectionLogEntry(
      timestamp: DateTime.now(),
      channel: channel,
      level: level,
      humanMessage: redactConnectionText(humanMessage),
      technicalMessage: redactConnectionText(technicalMessage),
      errorCode: errorCode,
      endpoint: endpoint == null ? null : redactConnectionText(endpoint),
      phase: phase,
      attempt: attempt,
    );
    _entries.insert(0, entry);
    if (_entries.length > capacity) _entries.removeLast();
    if (kDebugMode) {
      debugPrint(
        '[BLANQUITA][${channel.name.toUpperCase()}]'
        '[${level.name.toUpperCase()}] ${entry.formatted}',
      );
    }
    _scheduleNotification();
  }

  void clear() {
    _entries.clear();
    _scheduleNotification();
  }

  // Error reports can arrive while the widget tree is building/deactivating.
  // Store immediately, but notify after that synchronous lifecycle completes.
  void _scheduleNotification() {
    if (_notificationScheduled || _disposed) return;
    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String export({
    Map<String, String> app = const {},
    Map<String, String> control = const {},
    Map<String, String> vision = const {},
  }) {
    final buffer = StringBuffer(
      'BLANQUITA CONNECTION DIAGNOSTICS\n'
      'Generated: ${DateTime.now().toIso8601String()}\n',
    );
    for (final section in {
      'APP': app,
      'CONTROL': control,
      'VISION': vision,
    }.entries) {
      buffer.writeln('\n${section.key}');
      for (final row in section.value.entries) {
        buffer.writeln('${row.key}: ${redactConnectionText(row.value)}');
      }
    }
    buffer.writeln('\nEVENTS');
    for (final entry in _entries.reversed) {
      buffer.writeln('${entry.formatted}\n');
    }
    return buffer.toString();
  }
}
