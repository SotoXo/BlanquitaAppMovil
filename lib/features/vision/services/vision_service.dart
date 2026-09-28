import '../domain/position_estimate.dart';

/// Boundary for the future Camera -> Detector -> PositionEstimate pipeline.
/// No camera or detection implementation is registered in this phase.
abstract interface class VisionService {
  Stream<PositionEstimate?> get estimates;
  Future<void> start();
  Future<void> stop();
}

abstract interface class VisionDetector<TFrame> {
  Future<PositionEstimate?> estimate(TFrame frame);
}

abstract interface class CameraFrameSource<TFrame> {
  Stream<TFrame> get frames;
  Future<void> start();
  Future<void> stop();
}
