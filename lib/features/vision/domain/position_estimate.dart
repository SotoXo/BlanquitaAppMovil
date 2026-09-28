class PositionEstimate {
  const PositionEstimate({
    required this.timestamp,
    this.x,
    this.z,
    this.confidence,
  });

  final double? x;
  final double? z;
  final double? confidence;
  final DateTime timestamp;

  bool get hasPosition => x != null && z != null;
}
