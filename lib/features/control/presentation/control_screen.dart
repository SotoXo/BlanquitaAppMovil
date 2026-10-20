import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/machine_state.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../features/settings/controller/settings_controller.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/final_limits_panel.dart';
import '../../../shared/widgets/motion_reveal.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_widgets.dart';
import '../widgets/hold_to_move_button.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final machine = context.watch<MachineController>();
    final state = machine.state;
    final preferences = context.watch<SettingsController>().settings;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 126),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MotionReveal(
                  child: PageHeader(
                    compact: true,
                    eyebrow: 'Mando seguro',
                    title: 'Control',
                    subtitle: 'Mantén pulsada una dirección para mover.',
                    trailing: ConnectionBadge(phase: state.connection),
                  ),
                ),
                const SizedBox(height: 15),
                if (state.finalLimitActive == true &&
                    !state.finalLimits.isComplete) ...[
                  const SafetyBanner(
                    icon: CupertinoIcons.exclamationmark_triangle,
                    title: 'Final de carrera activado',
                    message:
                        'Esperando los cuatro finales. Pinza y STOP siguen disponibles.',
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 12),
                ],
                MotionReveal(
                  delay: const Duration(milliseconds: 60),
                  child: _ControlConsole(
                    machine: machine,
                    showConnectionHint:
                        !state.isConnected &&
                        preferences.showWarnings &&
                        preferences.connectionLossAlerts,
                  ),
                ),
                const SizedBox(height: 16),
                MotionReveal(
                  delay: const Duration(milliseconds: 115),
                  child: _ToolDeck(machine: machine),
                ),
                const SizedBox(height: 16),
                MotionReveal(
                  delay: const Duration(milliseconds: 165),
                  child: _SequencePanel(machine: machine),
                ),
                const SizedBox(height: 14),
                _EmergencyDock(machine: machine),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlConsole extends StatelessWidget {
  const _ControlConsole({
    required this.machine,
    required this.showConnectionHint,
  });

  final MachineController machine;
  final bool showConnectionHint;

  @override
  Widget build(BuildContext context) {
    final state = machine.state;
    final locked = machine.manualControlsLocked;
    final accent = state.finalLimitActive == true
        ? AppColors.danger
        : state.activeMovement != null
        ? AppColors.cyan
        : locked
        ? AppColors.warning
        : AppColors.mint;
    return GlassPanel(
      emphasis: GlassEmphasis.prominent,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 16),
      borderRadius: BorderRadius.circular(31),
      borderColor: accent.withValues(alpha: 0.22),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.activeMovement == null
                          ? 'Movimiento manual'
                          : state.activeMovement!.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.activeMovement == null
                          ? !state.finalLimits.isComplete
                                ? 'Esperando finales de carrera'
                                : machine.awaitingMovementRelease
                                ? 'Suelta el botón para continuar'
                                : 'Heartbeat listo · 200 ms'
                          : 'Motor activo · suelta para detener',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: locked
                    ? 'Desbloquear control manual'
                    : 'Bloquear control manual',
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: state.isConnected
                      ? () => machine.setManualControlsLocked(!locked)
                      : null,
                  child: GlassChip(
                    color: locked ? AppColors.warning : AppColors.mint,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          locked
                              ? CupertinoIcons.lock_fill
                              : CupertinoIcons.lock_open,
                          size: 14,
                          color: locked ? AppColors.warning : AppColors.mint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          locked ? 'Bloqueado' : 'Armado',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: locked
                                    ? AppColors.warning
                                    : AppColors.mint,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showConnectionHint) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.wifi_slash,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Conecta el teléfono a ${MachineController.wifiName}.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Reconectar',
                    onPressed: machine.reconnect,
                    icon: const Icon(CupertinoIcons.arrow_clockwise, size: 17),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _ControlPad(machine: machine),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          FinalLimitsPanel(
            limits: state.finalLimits,
            awaitingRelease:
                machine.awaitingMovementRelease && state.activeMovement == null,
          ),
        ],
      ),
    );
  }
}

class _ControlPad extends StatelessWidget {
  const _ControlPad({required this.machine});
  final MachineController machine;

  @override
  Widget build(BuildContext context) {
    final state = machine.state;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 410),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = (constraints.maxWidth - 18) / 3;
          final cellHeight = math.max(
            cellWidth / 1.18,
            58 + MediaQuery.textScalerOf(context).scale(10.5) * 2,
          );
          return SizedBox(
            height: cellHeight * 3 + 18,
            child: GridView.count(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: cellWidth / cellHeight,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              children: [
                const SizedBox.shrink(),
                HoldToMoveButton(
                  movement: MovementDirection.zUp,
                  icon: CupertinoIcons.chevron_up,
                  label: 'Subir Z',
                  enabled: machine.canMove(MovementDirection.zUp),
                  limitBlocked: state.finalLimits.blocks(MovementDirection.zUp),
                  active: state.activeMovement == MovementDirection.zUp,
                ),
                const SizedBox.shrink(),
                HoldToMoveButton(
                  movement: MovementDirection.xLeft,
                  icon: CupertinoIcons.chevron_left,
                  label: 'Izquierda',
                  enabled: machine.canMove(MovementDirection.xLeft),
                  limitBlocked: state.finalLimits.blocks(
                    MovementDirection.xLeft,
                  ),
                  active: state.activeMovement == MovementDirection.xLeft,
                ),
                _StopButton(
                  enabled: machine.hasValidConnection,
                  onPressed: machine.stopNow,
                ),
                HoldToMoveButton(
                  movement: MovementDirection.xRight,
                  icon: CupertinoIcons.chevron_right,
                  label: 'Derecha',
                  enabled: machine.canMove(MovementDirection.xRight),
                  limitBlocked: state.finalLimits.blocks(
                    MovementDirection.xRight,
                  ),
                  active: state.activeMovement == MovementDirection.xRight,
                ),
                const SizedBox.shrink(),
                HoldToMoveButton(
                  movement: MovementDirection.zDown,
                  icon: CupertinoIcons.chevron_down,
                  label: 'Bajar Z',
                  enabled: machine.canMove(MovementDirection.zDown),
                  limitBlocked: state.finalLimits.blocks(
                    MovementDirection.zDown,
                  ),
                  active: state.activeMovement == MovementDirection.zDown,
                ),
                const SizedBox.shrink(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StopButton extends StatefulWidget {
  const _StopButton({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_StopButton> createState() => _StopButtonState();
}

class _StopButtonState extends State<_StopButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.enabled,
    label: 'STOP, detener movimiento manual',
    child: GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1 : 0.28,
          duration: const Duration(milliseconds: 160),
          child: Container(
            margin: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.danger.withValues(alpha: 0.11),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.40),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(
                    alpha: _pressed ? 0.17 : 0.06,
                  ),
                  blurRadius: _pressed ? 17 : 10,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.stop_fill,
                  color: AppColors.danger,
                  size: 25,
                ),
                SizedBox(height: 3),
                Text(
                  'STOP',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ToolDeck extends StatelessWidget {
  const _ToolDeck({required this.machine});
  final MachineController machine;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('Pinza')),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _gripperLabel(machine.state.gripper),
                  key: ValueKey(machine.state.gripper),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.cyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  onPressed: machine.canUseAuxiliaryControls
                      ? machine.openGripper
                      : null,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.arrow_left_right, size: 17),
                      SizedBox(width: 8),
                      Flexible(child: Text('Abrir')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(
                  onPressed: machine.canUseAuxiliaryControls
                      ? machine.closeGripper
                      : null,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.arrow_right_arrow_left, size: 17),
                      SizedBox(width: 8),
                      Flexible(child: Text('Cerrar')),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Velocidad'),
                    const SizedBox(height: 3),
                    Text(
                      'Ajuste solicitado, sin telemetría absoluta',
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
              _CompactAction(
                icon: CupertinoIcons.minus,
                tooltip: 'Más lento',
                onTap: machine.canUseAuxiliaryControls
                    ? machine.requestSlower
                    : null,
              ),
              const SizedBox(width: 8),
              _CompactAction(
                icon: CupertinoIcons.plus,
                tooltip: 'Más rápido',
                onTap: machine.canUseAuxiliaryControls
                    ? machine.requestFaster
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _gripperLabel(GripperState value) => switch (value) {
    GripperState.unknown => 'Sin confirmar',
    GripperState.opening => 'Abriendo',
    GripperState.open => 'Abierta',
    GripperState.closing => 'Cerrando',
    GripperState.closed => 'Cerrada',
  };
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Opacity(
      opacity: onTap == null ? 0.34 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: 47,
          height: 47,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    ),
  );
}

class _SequencePanel extends StatelessWidget {
  const _SequencePanel({required this.machine});
  final MachineController machine;

  static const steps = [
    'Bajar eje Z',
    'Cerrar pinza',
    'Subir eje Z',
    'Mover X a la derecha',
    'Bajar eje Z',
    'Abrir pinza',
    'Subir eje Z',
    'Mover X a la izquierda',
  ];

  @override
  Widget build(BuildContext context) {
    final state = machine.state;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('Secuencia automática')),
              if (state.sequenceActive)
                GlassChip(
                  color: AppColors.cyan,
                  child: Text(
                    state.sequenceStep == null
                        ? 'Preparando'
                        : '${state.sequenceStep}/8',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.cyan),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            _TimelineStep(
              index: i + 1,
              label: steps[i],
              isLast: i == steps.length - 1,
              current: state.sequenceStep == i + 1,
              complete:
                  state.sequence == SequencePhase.completed ||
                  (state.sequenceStep ?? 0) > i + 1,
              cancelled: state.sequence == SequencePhase.cancelled,
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: machine.canStartSequence
                ? () => _confirmAndStart(context, machine)
                : null,
            icon: Icon(
              state.sequenceActive
                  ? CupertinoIcons.hourglass
                  : CupertinoIcons.play_fill,
              size: 18,
            ),
            label: Text(
              state.sequenceActive
                  ? 'Secuencia en curso'
                  : 'Ejecutar secuencia',
            ),
          ),
          if (state.sequenceActive) ...[
            const SizedBox(height: 9),
            TextButton.icon(
              onPressed: machine.emergencyStop,
              icon: const Icon(CupertinoIcons.xmark_circle, size: 18),
              label: const Text('Cancelar secuencia'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAndStart(
    BuildContext context,
    MachineController machine,
  ) async {
    final confirm = context.read<SettingsController>().settings.confirmSequence;
    if (!confirm) {
      machine.startSequence();
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(CupertinoIcons.play_circle),
        title: const Text('Iniciar secuencia'),
        content: const Text(
          'Verifica que el área esté libre. El ESP32 ejecutará los ocho pasos de forma autónoma.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
    if (accepted == true) machine.startSequence();
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.index,
    required this.label,
    required this.isLast,
    required this.current,
    required this.complete,
    required this.cancelled,
  });

  final int index;
  final String label;
  final bool isLast;
  final bool current;
  final bool complete;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? AppColors.mint
        : current
        ? AppColors.cyan
        : cancelled
        ? AppColors.danger.withValues(alpha: 0.55)
        : AppColors.steel.withValues(alpha: 0.42);
    return SizedBox(
      height: isLast ? 36 : 43,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: current ? 18 : 16,
                  height: current ? 18 : 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: current ? 0.20 : 0.09),
                    border: Border.all(color: color, width: current ? 2 : 1),
                    boxShadow: current
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.17),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: complete
                      ? Icon(CupertinoIcons.checkmark, size: 10, color: color)
                      : current
                      ? Center(
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: color.withValues(alpha: 0.30),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: current
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                fontWeight: current ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            index.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyDock extends StatelessWidget {
  const _EmergencyDock({required this.machine});
  final MachineController machine;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.fromLTRB(12, 11, 11, 11),
    borderRadius: BorderRadius.circular(22),
    tint: AppColors.danger.withValues(alpha: 0.065),
    borderColor: AppColors.danger.withValues(alpha: 0.28),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            CupertinoIcons.exclamationmark,
            color: AppColors.danger,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Emergencia', style: Theme.of(context).textTheme.titleSmall),
              Text(
                'Cancela movimiento y secuencia',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.44),
                ),
              ),
            ],
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            minimumSize: const Size(94, 46),
            padding: const EdgeInsets.symmetric(horizontal: 17),
          ),
          onPressed: machine.hasValidConnection ? machine.emergencyStop : null,
          child: const Text('DETENER'),
        ),
      ],
    ),
  );
}
