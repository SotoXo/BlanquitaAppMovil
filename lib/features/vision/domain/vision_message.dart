import 'vision_report.dart';
import 'vision_status.dart';

enum VisionMessageType {
  hello('vision.hello'),
  ready('vision.ready'),
  status('vision.status'),
  report('vision.report'),
  error('vision.error'),
  heartbeat('vision.heartbeat'),
  cameraStatus('camera.status'),
  calibrationStatus('calibration.status');

  const VisionMessageType(this.wireName);
  final String wireName;
}

enum VisionCommand {
  start('vision.start'),
  stop('vision.stop'),
  ping('vision.ping');

  const VisionCommand(this.wireName);
  final String wireName;
}

class VisionMessage {
  const VisionMessage({
    required this.type,
    required this.messageId,
    required this.timestamp,
    this.status = const VisionStatus(),
    this.report,
    this.error,
    this.replyTo,
    this.alerts,
  });

  final VisionMessageType type;
  final String messageId;
  final DateTime timestamp;
  final VisionStatus status;
  final VisionReport? report;
  final String? error;
  final String? replyTo;
  final List<String>? alerts;
}
