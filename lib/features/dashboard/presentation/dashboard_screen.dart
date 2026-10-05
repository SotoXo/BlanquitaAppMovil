import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/machine_state.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../features/settings/controller/settings_controller.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/motion_reveal.dart';
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
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 126),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MotionReveal(
                  child: PageHeader(
                    eyebrow: 'Sistema cartesiano',
                    title: 'BLANQUITA',
                    subtitle: 'Supervisión local del ESP32 único.',
                    trailing: ConnectionBadge(phase: state.connection),
                  ),
                ),
                const SizedBox(height: 18),
                if (state.finalLimitActive == true) ...[
                  const MotionReveal(
                    child: SafetyBanner(
                      icon: CupertinoIcons.exclamationmark_triangle,
                      title: 'Final de carrera activado',
                      message: 'Movimiento bloqueado por seguridad.',
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (!state.isConnected &&
                    preferences.showWarnings &&
                    preferences.connectionLossAlerts) ...[
                  MotionReveal(
                    child: _ConnectionNotice(
                      phase: state.connection,
                      onReconnect: machine.reconnect,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                MotionReveal(
                  delay: const Duration(milliseconds: 70),
                  child: _MachineHero(state: state),
                ),
                const SizedBox(height: 16),
                MotionReveal(
                  delay: const Duration(milliseconds: 125),
                  child: _StatusMatrix(state: state),
                ),
                const SizedBox(height: 24),
                const SectionLabel('Actividad reciente'),
                const SizedBox(height: 10),
                MotionReveal(
                  delay: const Duration(milliseconds: 170),
                  child: _ActivityPanel(
                    state: state,
                    events: machine.events.take(4).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                _ConnectionDetails(
                  state: state,
                  websocketUrl:
                      machine.connectionWebsocketUrl ??
                      'Sin dirección guardada',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({required this.phase, required this.onReconnect});

  final ConnectionPhase phase;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final connecting = phase == ConnectionPhase.connecting;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 11, 9, 11),
      borderRadius: BorderRadius.circular(20),
      tint: AppColors.warning.withValues(alpha: 0.075),
      borderColor: AppColors.warning.withValues(alpha: 0.25),
      child: Row(
        children: [
          Icon(
            connecting
                ? CupertinoIcons.antenna_radiowaves_left_right
                : CupertinoIcons.wifi_slash,
            size: 19,
            color: AppColors.warning,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              connecting
                  ? 'Conectando al ESP32 único…'
                  : 'Sin enlace. Conecta el teléfono a ${MachineController.wifiName}.',
              maxLines: 2,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
          ),
          if (!connecting)
            IconButton(
              tooltip: 'Reconectar',
              onPressed: onReconnect,
              icon: const Icon(CupertinoIcons.arrow_clockwise, size: 19),
            ),
        ],
      ),
    );
  }
}

class _MachineHero extends StatelessWidget {
  const _MachineHero({required this.state});

  final MachineState state;

  @override
  Widget build(BuildContext context) {
    final activity = state.finalLimitActive == true
        ? 'Bloqueada por seguridad'
        : state.activeMovement?.label ??
              (state.sequenceActive
                  ? 'Secuencia automática activa'
                  : 'Sistema en reposo');
    final color = state.finalLimitActive == true
        ? AppColors.danger
        : state.activeMovement != null || state.sequenceActive
        ? AppColors.cyan
        : AppColors.mint;

    return GlassPanel(
      emphasis: GlassEmphasis.prominent,
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 14),
      borderRadius: BorderRadius.circular(31),
      borderColor: color.withValues(alpha: 0.20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cartesiano 01',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.46),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: Text(
                        activity,
                        key: ValueKey(activity),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GlassChip(
                color: color,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusDot(color: color, size: 6),
                    const SizedBox(width: 7),
                    Text(
                      state.finalLimitActive == true
                          ? 'Seguro'
                          : state.sequenceActive
                          ? 'Auto'
                          : state.activeMovement != null
                          ? 'Manual'
                          : 'Listo',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 238,
            child: Stack(
              children: [
                Positioned.fill(child: CartesianVisualizer(state: state)),
                Positioned(
                  top: 17,
                  left: 4,
                  child: _AxisMark(
                    label: 'Eje X',
                    active: state.activeMovement?.axis == 'X',
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 26,
                  child: _AxisMark(
                    label: 'Eje Z',
                    active: state.activeMovement?.axis == 'Z',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.028),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.location_slash,
                  size: 17,
                  color: AppColors.steel,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Posición no calibrada',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  'X / Z —',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.steel,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisMark extends StatelessWidget {
  const _AxisMark({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: (active ? AppColors.cyan : AppColors.steel).withValues(
        alpha: 0.08,
      ),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: active ? AppColors.cyan : AppColors.steel,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _StatusMatrix extends StatelessWidget {
  const _StatusMatrix({required this.state});

  final MachineState state;

  @override
  Widget build(BuildContext context) {
    final cells = [
      _StatusCellData(
        label: 'ESP32',
        value: state.isConnected ? 'Conectado' : 'Sin enlace',
        icon: CupertinoIcons.antenna_radiowaves_left_right,
        color: state.isConnected ? AppColors.mint : AppColors.danger,
      ),
      _StatusCellData(
        label: 'Plato',
        value: _boolLabel(state.plateDetected, 'Detectado', 'Libre'),
        icon: CupertinoIcons.circle_grid_3x3,
        color: state.plateDetected == true
            ? AppColors.mint
            : state.plateDetected == false
            ? AppColors.steel
            : AppColors.warning,
      ),
      _StatusCellData(
        label: 'Final de carrera',
        value: _boolLabel(state.finalLimitActive, 'Activado', 'Libre'),
        icon: CupertinoIcons.stop_circle,
        color: state.finalLimitActive == true
            ? AppColors.danger
            : state.finalLimitActive == false
            ? AppColors.mint
            : AppColors.warning,
      ),
      _StatusCellData(
        label: 'Pinza',
        value: _gripperLabel(state.gripper),
        icon: CupertinoIcons.arrow_left_right,
        color: state.gripper == GripperState.unknown
            ? AppColors.warning
            : AppColors.cyan,
      ),
    ];
    return GlassPanel(
      padding: EdgeInsets.zero,
      emphasis: GlassEmphasis.quiet,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 650;
          if (wide) {
            return Row(
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  Expanded(child: _StatusCell(data: cells[i])),
                  if (i != cells.length - 1) const _VerticalHairline(),
                ],
              ],
            );
          }
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _StatusCell(data: cells[0])),
                  const _VerticalHairline(),
                  Expanded(child: _StatusCell(data: cells[1])),
                ],
              ),
              const Divider(height: 1),
              Row(
                children: [
                  Expanded(child: _StatusCell(data: cells[2])),
                  const _VerticalHairline(),
                  Expanded(child: _StatusCell(data: cells[3])),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static String _boolLabel(bool? value, String yes, String no) => value == null
      ? 'Sin datos'
      : value
      ? yes
      : no;

  static String _gripperLabel(GripperState value) => switch (value) {
    GripperState.unknown => 'Sin confirmar',
    GripperState.opening => 'Abriendo',
    GripperState.open => 'Abierta',
    GripperState.closing => 'Cerrando',
    GripperState.closed => 'Cerrada',
  };
}

class _StatusCellData {
  const _StatusCellData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.data});

  final _StatusCellData data;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(15, 14, 12, 15),
    child: Row(
      children: [
        AnimatedContainer(
          key: ValueKey('${data.label}-${data.value}'),
          duration: const Duration(milliseconds: 260),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.095),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(data.icon, size: 17, color: data.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.42),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.97,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  data.value,
                  key: ValueKey(data.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: data.color),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VerticalHairline extends StatelessWidget {
  const _VerticalHairline();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 48,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.055),
  );
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.state, required this.events});

  final MachineState state;
  final List<MachineEvent> events;

  @override
  Widget build(BuildContext context) {
    final activeColor = state.finalLimitActive == true
        ? AppColors.danger
        : state.sequenceActive
        ? AppColors.cyan
        : AppColors.mint;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final current = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ahora',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: activeColor),
              ),
              const SizedBox(height: 7),
              Text(
                state.lastStatus,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (state.sequenceStep != null) ...[
                const SizedBox(height: 9),
                Text(
                  'Paso ${state.sequenceStep}/8 · ${state.sequenceStepLabel ?? 'En curso'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.cyan),
                ),
              ],
            ],
          );
          final history = Column(
            children: events.isEmpty
                ? [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Aún no hay actividad registrada.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.44),
                        ),
                      ),
                    ),
                  ]
                : [
                    for (var i = 0; i < events.length; i++) ...[
                      _EventRow(event: events[i]),
                      if (i != events.length - 1) const Divider(height: 17),
                    ],
                  ],
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                current,
                const SizedBox(height: 18),
                const Divider(),
                history,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: current),
              const SizedBox(width: 26),
              Expanded(flex: 5, child: history),
            ],
          );
        },
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final MachineEvent event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.level) {
      MachineEventLevel.info => AppColors.steel,
      MachineEventLevel.success => AppColors.mint,
      MachineEventLevel.warning => AppColors.warning,
      MachineEventLevel.critical => AppColors.danger,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: StatusDot(color: color, size: 6),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            event.message,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _time(event.timestamp),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.34),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _ConnectionDetails extends StatelessWidget {
  const _ConnectionDetails({required this.state, required this.websocketUrl});

  final MachineState state;
  final String websocketUrl;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
    emphasis: GlassEmphasis.quiet,
    child: Row(
      children: [
        const Icon(CupertinoIcons.link, size: 17, color: AppColors.steel),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                websocketUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                state.lastMessage == null
                    ? 'Sin mensajes recibidos'
                    : 'Último RX · ${state.lastMessage}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          state.lastReceivedAt == null ? '—' : _time(state.lastReceivedAt!),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.steel,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}
