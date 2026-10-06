/// Partial server telemetry. Null means that the server supplied no value.
class VisionStatus {
  const VisionStatus({
    this.ready,
    this.cameraStatus,
    this.cameraName,
    this.detectorStatus,
    this.calibrationStatus,
    this.fps,
    this.latency,
  });

  final bool? ready;
  final String? cameraStatus;
  final String? cameraName;
  final String? detectorStatus;
  final String? calibrationStatus;
  final double? fps;

  /// Round-trip latency in milliseconds, reported or measured via ping.
  final double? latency;

  VisionStatus merge(VisionStatus next) => VisionStatus(
    ready: next.ready ?? ready,
    cameraStatus: next.cameraStatus ?? cameraStatus,
    cameraName: next.cameraName ?? cameraName,
    detectorStatus: next.detectorStatus ?? detectorStatus,
    calibrationStatus: next.calibrationStatus ?? calibrationStatus,
    fps: next.fps ?? fps,
    latency: next.latency ?? latency,
  );
}
