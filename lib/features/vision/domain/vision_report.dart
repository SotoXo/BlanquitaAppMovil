import 'position_estimate.dart';
import 'vision_status.dart';

class VisionReport {
  const VisionReport({
    required this.id,
    required this.timestamp,
    this.detected,
    this.object,
    this.position,
    this.confidence,
    this.status = const VisionStatus(),
    this.alerts = const [],
  });

  final String id;
  final DateTime timestamp;
  final bool? detected;
  final String? object;
  final PositionEstimate? position;
  final double? confidence;
  final VisionStatus status;
  final List<String> alerts;
}
