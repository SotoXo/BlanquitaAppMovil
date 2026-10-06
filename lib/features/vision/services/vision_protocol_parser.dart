import 'dart:convert';

import '../domain/position_estimate.dart';
import '../domain/vision_message.dart';
import '../domain/vision_report.dart';
import '../domain/vision_status.dart';

class VisionParseResult {
  const VisionParseResult({this.message, this.error, this.ignored = false});
  final VisionMessage? message;
  final String? error;
  final bool ignored;
}

class VisionProtocolParser {
  const VisionProtocolParser();
  static const protocol = 'blanquita-vision';
  static const version = 1;

  VisionParseResult parse(Object? raw) {
    try {
      if (raw is! String) {
        throw const FormatException('Se esperaba JSON de texto');
      }
      final envelope = _map(jsonDecode(raw), 'mensaje');
      if (envelope['protocol'] != protocol) {
        throw const FormatException('Protocolo de visión incorrecto');
      }
      if (envelope['version'] is! int || envelope['version'] != version) {
        throw const FormatException('Versión de visión no soportada');
      }
      final name = _string(envelope, 'type', required: true)!;
      final id = _string(envelope, 'messageId', required: true)!;
      final timestamp = _timestamp(
        _string(envelope, 'timestamp', required: true)!,
      );
      final payload = _map(envelope['payload'], 'payload');
      final types = VisionMessageType.values.where(
        (value) => value.wireName == name,
      );
      if (types.isEmpty) return const VisionParseResult(ignored: true);
      final type = types.first;
      final status = VisionStatus(
        ready:
            _boolean(payload, 'ready') ??
            (type == VisionMessageType.ready ? true : null),
        cameraStatus: _string(
          payload,
          type == VisionMessageType.cameraStatus ? 'status' : 'cameraStatus',
        ),
        cameraName: _string(
          payload,
          type == VisionMessageType.cameraStatus ? 'name' : 'cameraName',
        ),
        detectorStatus: _string(payload, 'detectorStatus'),
        calibrationStatus: _string(
          payload,
          type == VisionMessageType.calibrationStatus
              ? 'status'
              : 'calibrationStatus',
        ),
        fps: _number(payload, 'fps', minimum: 0),
        latency: _number(payload, 'latency', minimum: 0),
      );
      final alerts = _alerts(payload);
      VisionReport? report;
      if (type == VisionMessageType.report) {
        final confidence = _number(
          payload,
          'confidence',
          minimum: 0,
          maximum: 1,
        );
        PositionEstimate? position;
        if (payload['position'] != null) {
          final coordinates = _map(payload['position'], 'position');
          final x = _number(coordinates, 'x');
          final z = _number(coordinates, 'z');
          if (x != null || z != null) {
            position = PositionEstimate(
              x: x,
              z: z,
              confidence: confidence,
              timestamp: timestamp,
            );
          }
        }
        report = VisionReport(
          id: id,
          timestamp: timestamp,
          detected: _boolean(payload, 'detected'),
          object: _string(payload, 'object'),
          position: position,
          confidence: confidence,
          status: status,
          alerts: alerts ?? const [],
        );
      }
      return VisionParseResult(
        message: VisionMessage(
          type: type,
          messageId: id,
          timestamp: timestamp,
          status: status,
          report: report,
          alerts: alerts,
          error: type == VisionMessageType.error
              ? _string(payload, 'message') ??
                    _string(payload, 'code') ??
                    'Error del Vision Server'
              : null,
          replyTo: _string(payload, 'replyTo'),
        ),
      );
    } on FormatException catch (error) {
      return VisionParseResult(error: error.message);
    }
  }

  Map<String, dynamic> _map(Object? value, String field) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$field debe ser un objeto');
    }
    return value;
  }

  String? _string(
    Map<String, dynamic> map,
    String field, {
    bool required = false,
  }) {
    final value = map[field];
    if (value == null && !required) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field debe ser texto no vacío');
    }
    return value;
  }

  bool? _boolean(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value == null) return null;
    if (value is! bool) throw FormatException('$field debe ser booleano');
    return value;
  }

  double? _number(
    Map<String, dynamic> map,
    String field, {
    double? minimum,
    double? maximum,
  }) {
    final value = map[field];
    if (value == null) return null;
    if (value is! num ||
        !value.isFinite ||
        (minimum != null && value < minimum) ||
        (maximum != null && value > maximum)) {
      throw FormatException('$field tiene un valor numérico inválido');
    }
    return value.toDouble();
  }

  List<String>? _alerts(Map<String, dynamic> map) {
    final value = map['alerts'];
    if (value == null) return null;
    if (value is! List || value.any((item) => item is! String)) {
      throw const FormatException('alerts debe ser una lista de textos');
    }
    return List<String>.unmodifiable(value.cast<String>());
  }

  DateTime _timestamp(String value) {
    final parts = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?$',
    ).firstMatch(value);
    final parsed = DateTime.tryParse(value);
    if (parts == null || parsed == null) {
      throw const FormatException('timestamp ISO-8601 inválido');
    }
    final year = int.parse(parts[1]!);
    final month = int.parse(parts[2]!);
    final day = int.parse(parts[3]!);
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateTime.utc(year, month + 1, 0).day ||
        int.parse(parts[4]!) > 23 ||
        int.parse(parts[5]!) > 59 ||
        int.parse(parts[6]!) > 59) {
      throw const FormatException('timestamp fuera de rango');
    }
    return parsed;
  }
}
