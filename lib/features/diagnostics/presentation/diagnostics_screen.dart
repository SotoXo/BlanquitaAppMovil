import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/machine_state.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/motion_reveal.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_widgets.dart';
import '../../vision/controller/vision_controller.dart';
import '../../vision/presentation/vision_widgets.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final machine = context.watch<MachineController>();
    final state = machine.state;
    final vision = context.watch<VisionController>();
    final vs = vision.state;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Diagnósticos'),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      eyebrow: 'Telemetría local',
                      title: 'Estado técnico',
                      subtitle:
                          'Lectura directa de conexión, sensores y eventos del controlador.',
                      trailing: ConnectionBadge(phase: state.connection),
                    ),
                    const SizedBox(height: 20),
                    const SectionLabel('ESP32 · Control'),
                    const SizedBox(height: 10),
                    MotionReveal(
                      child: _TransportConsole(machine: machine, state: state),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 680;
                        final sensors = _DiagnosticModule(
                          title: 'Sensores',
                          code: 'I/O',
                          icon: CupertinoIcons.waveform_path_ecg,
                          rows: {
                            'Plato': _boolLabel(
                              state.plateDetected,
                              'Detectado',
                              'Libre',
                            ),
                            'Final de carrera': _boolLabel(
                              state.finalLimitActive,
                              'Activado',
                              'Libre',
                            ),
                            'Último paquete': state.lastSensorPacket ?? '—',
                          },
                        );
                        final machineModule = _DiagnosticModule(
                          title: 'Máquina',
                          code: 'CTRL',
                          icon: CupertinoIcons.slider_horizontal_3,
                          rows: {
                            'Movimiento':
                                state.activeMovement?.label ?? 'Detenido',
                            'Secuencia': state.sequence.name,
                            'Paso': state.sequenceStep?.toString() ?? '—',
                            'Pinza': state.gripper.name,
                            'Estado': state.lastStatus,
                          },
                        );

                        if (compact) {
                          return Column(
                            children: [
                              MotionReveal(
                                delay: const Duration(milliseconds: 60),
                                child: sensors,
                              ),
                              const SizedBox(height: 14),
                              MotionReveal(
                                delay: const Duration(milliseconds: 110),
                                child: machineModule,
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: sensors),
                            const SizedBox(width: 14),
                            Expanded(child: machineModule),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    MotionReveal(
                      delay: const Duration(milliseconds: 150),
                      child: _EventConsole(machine: machine),
                    ),
                    const SizedBox(height: 24),
                    const SectionLabel('Laptop · Visión'),
                    const SizedBox(height: 10),
                    VisionReadouts(
                      title: 'Vision Server',
                      rows: {
                        'Endpoint':
                            vision.connectionWebsocketUrl ??
                            (vision.endpoint.isEmpty
                                ? 'Sin configurar'
                                : vision.endpoint),
                        'Dirección detectada': vision.detectedAddress ?? '—',
                        'Discovery': vision.discoveryStatusLabel,
                        'Conexión': visionConnectionLabel(vs),
                        'Ready': vs.ready ? 'Sí' : 'No',
                        'Último mensaje': vs.lastMessage ?? '—',
                        'Recepción': visionTime(vs.lastMessageAt),
                        'Último heartbeat': visionTime(vs.lastHeartbeat),
                        'Último reporte': visionTime(vs.lastReport?.timestamp),
                        'ID reporte': vs.lastReport?.id ?? '—',
                        'Edad reporte': visionAge(vs.reportAge),
                        'Stale': vs.stale ? 'Sí' : 'No',
                        'Reporte caducado': vs.reportStale ? 'Sí' : 'No',
                        'Latencia': vs.latency == null
                            ? '—'
                            : '${vs.latency!.toStringAsFixed(1)} ms',
                        'Error': vs.error ?? '—',
                        'Cámara': visionStatusLabel(vs.cameraStatus),
                        'Nombre cámara': vs.cameraName ?? '—',
                        'Detector': visionStatusLabel(vs.detectorStatus),
                        'Calibración': visionStatusLabel(vs.calibrationStatus),
                        'Intentos reconexión': vision.reconnectAttempts
                            .toString(),
                      },
                    ),
                    const SizedBox(height: 14),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Eventos de visión',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          if (vision.diagnostics.isEmpty)
                            const Text('Sin eventos de visión'),
                          for (final entry in vision.diagnostics.take(20))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                entry,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _boolLabel(bool? value, String yes, String no) => value == null
      ? 'Sin datos'
      : value
      ? yes
      : no;
}

class _TransportConsole extends StatelessWidget {
  const _TransportConsole({required this.machine, required this.state});

  final MachineController machine;
  final MachineState state;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      emphasis: GlassEmphasis.prominent,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _ModuleIcon(
                icon: CupertinoIcons.antenna_radiowaves_left_right,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canal WebSocket ESP32',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      machine.settingsWebsocketUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _technicalStyle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Device ID: ${machine.selectedDevice?.deviceId ?? 'Sin seleccionar'}',
          ),
          Text('IP actual: ${machine.deviceAddress ?? 'Sin dirección'}'),
          Text('Estado: ${machine.linkPhase.label}'),
          Text('Autenticación: ${machine.authenticationLabel}'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PacketReadout(
                  label: 'ÚLTIMO RX',
                  value: state.lastMessage ?? '—',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PacketReadout(
                  label: 'ÚLTIMO TX',
                  value: state.lastCommand ?? '—',
                ),
              ),
            ],
          ),
          if (state.connectionError case final error?) ...[
            const SizedBox(height: 10),
            _PacketReadout(label: 'ERROR', value: error, critical: true),
          ],
        ],
      ),
    );
  }
}

class _PacketReadout extends StatelessWidget {
  const _PacketReadout({
    required this.label,
    required this.value,
    this.critical = false,
  });

  final String label;
  final String value;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (critical ? AppColors.danger : AppColors.canvas).withValues(
          alpha: critical ? 0.11 : 0.48,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (critical ? AppColors.danger : AppColors.steel).withValues(
            alpha: 0.2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: critical ? AppColors.danger : AppColors.steel,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            maxLines: 2,
            style: _technicalStyle(context).copyWith(
              color: critical ? AppColors.danger : AppColors.coldWhite,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticModule extends StatelessWidget {
  const _DiagnosticModule({
    required this.title,
    required this.code,
    required this.icon,
    required this.rows,
  });

  final String title;
  final String code;
  final IconData icon;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ModuleIcon(icon: icon),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                code,
                style: _technicalStyle(context).copyWith(color: AppColors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final entry in rows.entries) _DiagnosticRow(entry: entry),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.entry});

  final MapEntry<String, String> entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.steel.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              entry.key,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.steel),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: SelectableText(
              entry.value,
              textAlign: TextAlign.right,
              style: _technicalStyle(context).copyWith(
                color: AppColors.coldWhite,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventConsole extends StatelessWidget {
  const _EventConsole({required this.machine});

  final MachineController machine;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _ModuleIcon(
                icon: CupertinoIcons.list_bullet_below_rectangle,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Registro de eventos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${machine.events.length}/${MachineController.maxEvents}',
                style: _technicalStyle(
                  context,
                ).copyWith(color: AppColors.steel),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Limpiar eventos',
                onPressed: machine.events.isEmpty ? null : machine.clearEvents,
                icon: const Icon(CupertinoIcons.trash, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (machine.events.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                'Sin eventos registrados',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.steel),
              ),
            )
          else
            for (var i = 0; i < machine.events.length; i++)
              _LogLine(event: machine.events[i]),
        ],
      ),
    );
  }
}

class _ModuleIcon extends StatelessWidget {
  const _ModuleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.cyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: AppColors.cyan, size: 19),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.event});
  final MachineEvent event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.level) {
      MachineEventLevel.info => AppColors.cyan,
      MachineEventLevel.success => AppColors.mint,
      MachineEventLevel.warning => AppColors.warning,
      MachineEventLevel.critical => AppColors.danger,
    };
    final time =
        '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.steel.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: StatusDot(color: color, size: 7),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              time,
              style: _technicalStyle(context).copyWith(color: AppColors.steel),
            ),
          ),
          Expanded(
            child: Text(
              event.message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _technicalStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelSmall?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: 0.35,
      ) ??
      const TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
}
