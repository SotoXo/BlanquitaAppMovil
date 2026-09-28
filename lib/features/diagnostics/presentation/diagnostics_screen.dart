import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/machine_state.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_widgets.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final machine = context.watch<MachineController>();
    final state = machine.state;
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      eyebrow: 'Estado en vivo',
                      title: 'Diagnóstico del sistema',
                      subtitle:
                          'Datos locales de conexión, sensores, máquina y los últimos eventos.',
                      trailing: ConnectionBadge(phase: state.connection),
                    ),
                    const SizedBox(height: 20),
                    _DiagnosticCard(
                      title: 'WebSocket',
                      icon: Icons.cable_rounded,
                      rows: {
                        'Estado': _connectionLabel(state.connection),
                        'URL': machine.settingsWebsocketUrl,
                        'Último RX': state.lastMessage ?? '—',
                        'Último TX': state.lastCommand ?? '—',
                        'Error': state.connectionError ?? 'Ninguno',
                      },
                    ),
                    const SizedBox(height: 14),
                    _DiagnosticCard(
                      title: 'Sensores',
                      icon: Icons.sensors_rounded,
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
                    ),
                    const SizedBox(height: 14),
                    _DiagnosticCard(
                      title: 'Máquina',
                      icon: Icons.precision_manufacturing_rounded,
                      rows: {
                        'Movimiento': state.activeMovement?.label ?? 'Detenido',
                        'Secuencia': state.sequence.name,
                        'Paso': state.sequenceStep?.toString() ?? '—',
                        'Pinza': state.gripper.name,
                        'Estado': state.lastStatus,
                      },
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                color: AppColors.cyan,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Eventos (${machine.events.length}/${MachineController.maxEvents})',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              TextButton(
                                onPressed: machine.events.isEmpty
                                    ? null
                                    : machine.clearEvents,
                                child: const Text('LIMPIAR'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (machine.events.isEmpty)
                            const Text('No hay eventos registrados.')
                          else
                            for (var i = 0; i < machine.events.length; i++) ...[
                              _LogLine(event: machine.events[i]),
                              if (i != machine.events.length - 1)
                                const Divider(height: 16),
                            ],
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

  static String _connectionLabel(ConnectionPhase phase) => switch (phase) {
    ConnectionPhase.disconnected => 'Desconectado',
    ConnectionPhase.connecting => 'Conectando',
    ConnectionPhase.connected => 'Conectado',
    ConnectionPhase.error => 'Error',
  };

  static String _boolLabel(bool? value, String yes, String no) => value == null
      ? 'Sin datos'
      : value
      ? yes
      : no;
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({
    required this.title,
    required this.icon,
    required this.rows,
  });
  final String title;
  final IconData icon;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.cyan),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        for (final entry in rows.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    entry.value,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
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
    return Row(
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.42),
            ),
          ),
        ),
        Expanded(
          child: Text(
            event.message,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
