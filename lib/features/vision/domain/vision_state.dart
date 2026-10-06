import 'position_estimate.dart';
import 'vision_report.dart';
import 'vision_status.dart';

enum VisionConnection {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class VisionState {
  const VisionState({
    this.connection = VisionConnection.disconnected,
    this.status = const VisionStatus(),
    this.lastReport,
    this.lastHeartbeat,
    this.lastMessage,
    this.lastMessageAt,
    this.lastReportReceivedAt,
    this.error,
    this.stale = false,
    this.reportStale = false,
    this.reportAge,
    this.alerts = const [],
  });

  final VisionConnection connection;
  final VisionStatus status;
  final VisionReport? lastReport;

  /// Local reception times are used for connection liveness.
  final DateTime? lastHeartbeat;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? lastReportReceivedAt;
  final String? error;
  final bool stale;
  final bool reportStale;

  /// Report age uses the server timestamp; LAN clocks should be synchronized.
  final Duration? reportAge;
  final List<String> alerts;

  bool get isConnected => connection == VisionConnection.connected;
  bool get ready => isConnected && !stale && status.ready == true;
  String? get cameraStatus => status.cameraStatus;
  String? get cameraName => status.cameraName;
  String? get detectorStatus => status.detectorStatus;
  String? get calibrationStatus => status.calibrationStatus;
  double? get fps => status.fps;
  double? get latency => status.latency;
  PositionEstimate? get position =>
      lastReport?.detected == false ? null : lastReport?.position;

  VisionState copyWith({
    VisionConnection? connection,
    VisionStatus? status,
    VisionReport? lastReport,
    DateTime? lastHeartbeat,
    String? lastMessage,
    DateTime? lastMessageAt,
    DateTime? lastReportReceivedAt,
    String? error,
    bool clearError = false,
    bool? stale,
    bool? reportStale,
    Duration? reportAge,
    List<String>? alerts,
  }) => VisionState(
    connection: connection ?? this.connection,
    status: status ?? this.status,
    lastReport: lastReport ?? this.lastReport,
    lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    lastReportReceivedAt: lastReportReceivedAt ?? this.lastReportReceivedAt,
    error: clearError ? null : error ?? this.error,
    stale: stale ?? this.stale,
    reportStale: reportStale ?? this.reportStale,
    reportAge: reportAge ?? this.reportAge,
    alerts: alerts ?? this.alerts,
  );
}
