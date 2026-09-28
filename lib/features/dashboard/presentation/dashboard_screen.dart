import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/machine_state.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../features/settings/controller/settings_controller.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_widgets.dart';
import '../widgets/cartesian_visualizer.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final machine = context.watch<MachineController>();
    final state = machine.state;
    final preferences = context.watch<SettingsController>().settings;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 132),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  eyebrow: 'Supervisión cartesiana',
                  title: 'BLANQUITA',
                  subtitle:
                      'Estado operativo y telemetría del ESP32 principal.',
                  trailing: ConnectionBadge(phase: state.connection),
                ),
                const SizedBox(height: 22),
                if (state.finalLimitActive == true) ...[
                  const SafetyBanner(
                    icon: Icons.warning_amber_rounded,
                    title: 'Final de carrera activado',
                    message:
                        'Movimiento y secuencia bloqueados hasta liberar el sensor.',
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 14),
                ] else if (!state.isConnected &&
                    preferences.showWarnings &&
                    preferences.connectionLossAlerts) ...[
                  SafetyBanner(
                    icon: Icons.wifi_off_rounded,
                    title: state.connection == ConnectionPhase.connecting
                        ? 'Buscando ESP32…'
                        : 'Sin conexión con BLANQUITA',
                    message:
                        'Conecta el teléfono a ${MachineController.wifiName} y vuelve a intentar.',
                    color: state.connection == ConnectionPhase.connecting
                        ? AppColors.warning
                        : AppColors.danger,
                    action: state.connection == ConnectionPhase.connecting
                        ? null
                        : machine.reconnect,
                  ),
                  const SizedBox(height: 14),
                ],
                GlassCard(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionLabel('Cartesiano 1'),
                                const SizedBox(height: 7),
                                Text(
                                  state.activeMovement?.label ??
                                      (state.sequenceActive
                                          ? 'Secuencia automática activa'
                                          : 'En reposo'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ),
                          _ModeChip(state: state),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 250,
                        child: CartesianVisualizer(state: state),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.035),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 9),
                            const Expanded(
                              child: Text(
                                'Representa actividad y dirección; no indica posición X/Z absoluta.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionLabel('Sensores'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SensorCard(
                        icon: Icons.dinner_dining_rounded,
                        label: 'Plato',
                        value: _plateLabel(state.plateDetected),
                        color: state.plateDetected == null
                            ? Colors.blueGrey
                            : state.plateDetected!
                            ? AppColors.mint
                            : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SensorCard(
                        icon: Icons.sensors_rounded,
                        label: 'Final de carrera',
                        value: _limitLabel(state.finalLimitActive),
                        color: state.finalLimitActive == null
                            ? Colors.blueGrey
                            : state.finalLimitActive!
                            ? AppColors.danger
                            : AppColors.mint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 680;
                    final machineCard = _MachineStatusCard(state: state);
                    final connectionCard = _ConnectionCard(
                      state: state,
                      websocketUrl: context
                          .read<MachineController>()
                          .settingsWebsocketUrl,
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          machineCard,
                          const SizedBox(height: 14),
                          connectionCard,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: machineCard),
                        const SizedBox(width: 14),
                        Expanded(child: connectionCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _RecentEvents(events: machine.events.take(5).toList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _plateLabel(bool? value) => value == null
      ? 'Sin datos'
      : value
      ? 'Detectado'
      : 'Libre';
  static String _limitLabel(bool? value) => value == null
      ? 'Sin datos'
      : value
      ? 'Activado'
      : 'Libre';
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.state});
  final MachineState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = state.finalLimitActive == true
        ? ('BLOQUEADO', AppColors.danger)
        : state.sequenceActive
        ? ('AUTO', AppColors.violet)
        : state.activeMovement != null
        ? ('MANUAL', AppColors.cyan)
        : ('SEGURO', AppColors.mint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(16),
    borderColor: color.withValues(alpha: 0.24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            StatusDot(color: color, size: 8),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.58),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    ),
  );
}

class _MachineStatusCard extends StatelessWidget {
  const _MachineStatusCard({required this.state});
  final MachineState state;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Máquina'),
        const SizedBox(height: 16),
        _DataLine('Movimiento', state.activeMovement?.label ?? 'Detenido'),
        _DataLine('Pinza', _gripperLabel(state.gripper)),
        _DataLine('Secuencia', _sequenceLabel(state)),
        _DataLine('Último estado', state.lastStatus, last: true),
      ],
    ),
  );

  String _gripperLabel(GripperState value) => switch (value) {
    GripperState.unknown => 'Sin confirmar',
    GripperState.opening => 'Abriendo…',
    GripperState.open => 'Abierta',
    GripperState.closing => 'Cerrando…',
    GripperState.closed => 'Cerrada',
  };

  String _sequenceLabel(MachineState state) {
    if (state.sequenceStep != null) {
      return 'Paso ${state.sequenceStep}/8 · ${state.sequenceStepLabel ?? ''}';
    }
    return switch (state.sequence) {
      SequencePhase.idle => 'Inactiva',
      SequencePhase.requested => 'Solicitada',
      SequencePhase.running => 'En curso',
      SequencePhase.completed => 'Completada',
      SequencePhase.cancelled => 'Cancelada',
      SequencePhase.error => 'Con error',
    };
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.state, required this.websocketUrl});
  final MachineState state;
  final String websocketUrl;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Conexión'),
        const SizedBox(height: 16),
        _DataLine(
          'WebSocket',
          state.isConnected ? 'Conectado' : 'Desconectado',
        ),
        _DataLine('Destino', websocketUrl),
        _DataLine('Último RX', state.lastMessage ?? 'Sin mensajes'),
        _DataLine(
          'Recibido',
          state.lastReceivedAt == null
              ? '—'
              : _formatTime(state.lastReceivedAt!),
          last: true,
        ),
      ],
    ),
  );

  String _formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}

class _DataLine extends StatelessWidget {
  const _DataLine(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.48),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _RecentEvents extends StatelessWidget {
  const _RecentEvents({required this.events});
  final List<MachineEvent> events;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Actividad reciente'),
        const SizedBox(height: 14),
        if (events.isEmpty)
          Text(
            'Todavía no hay eventos.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (var i = 0; i < events.length; i++) ...[
            _EventRow(event: events[i]),
            if (i != events.length - 1) const Divider(height: 20),
          ],
      ],
    ),
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
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
      children: [
        StatusDot(color: color, size: 7),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            event.message,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          time,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ],
    );
  }
}
