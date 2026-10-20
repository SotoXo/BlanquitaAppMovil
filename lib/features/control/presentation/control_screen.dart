import '../../settings/controller/app_settings.dart';
import '../../assistant/presentation/alfresi_bubble.dart';
import '../../assistant/services/alfresi_rules.dart';
import '../../assistant/domain/alfresi_context.dart';
import '../../vision/controller/vision_controller.dart';
import '../../diagnostics/presentation/diagnostics_screen.dart';
import '../../../shared/widgets/blanquita/blanquita_lock_state.dart';
import '../../../shared/widgets/blanquita/blanquita_modal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/design/blanquita_design.dart';
import '../../../core/models/machine_state.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../features/settings/controller/settings_controller.dart';
import '../../../shared/widgets/glass_surface.dart';
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
    final lockReason = AlfresiContext.read(
      machine,
      context.watch<VisionController>(),
      'Control',
    ).lockReason;
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
                if (preferences.visualTheme != BlanquitaVisualTheme.original &&
                    preferences.assistantEnabled &&
                    preferences.assistantTips) ...[
                  const SizedBox(height: 12),
                  AlfresiBubble(
                    message:
                        lockReason ??
                        'Mantén pulsada una dirección. Suelta para detener.',
                    mood: AlfresiRules.explain(
                      AlfresiContext.read(
                        machine,
                        context.watch<VisionController>(),
                        'Control',
                      ),
                    ).mood,
                  ),
                ],
                const SizedBox(height: 15),
                if (state.finalLimitActive == true) ...[
                  SafetyBanner(
                    icon: CupertinoIcons.exclamationmark_triangle,
                    title: 'Final de carrera activado',
                    message:
                        'Movimiento bloqueado por seguridad. Pinza y STOP siguen disponibles.',
                    color: BlanquitaColors.of(context).danger,
                  ),
                  const SizedBox(height: 12),
                ],
                if (lockReason != null) ...[
                  BlanquitaLockState(
                    reason: lockReason,
                    critical: state.finalLimitActive == true,
                    onDiagnostic: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DiagnosticsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                const SizedBox(height: 14),
                _EmergencyDock(machine: machine),
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
        ? BlanquitaColors.of(context).danger
        : state.activeMovement != null
        ? BlanquitaColors.of(context).cyan
        : locked
        ? BlanquitaColors.of(context).warning
        : BlanquitaColors.of(context).mint;
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
                          ? (state.isConnected
                                ? 'Mantén pulsado para mover'
                                : 'Sin enlace · movimiento deshabilitado')
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
                    color: locked
                        ? BlanquitaColors.of(context).warning
                        : BlanquitaColors.of(context).mint,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          locked
                              ? CupertinoIcons.lock_fill
                              : CupertinoIcons.lock_open,
                          size: 14,
                          color: locked
                              ? BlanquitaColors.of(context).warning
                              : BlanquitaColors.of(context).mint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          locked ? 'Bloqueado' : 'Armado',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: locked
                                    ? BlanquitaColors.of(context).warning
                                    : BlanquitaColors.of(context).mint,
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
                color: BlanquitaColors.of(
                  context,
                ).warning.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.wifi_slash,
                    size: 16,
                    color: BlanquitaColors.of(context).warning,
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
    final enabled = machine.canStartMovement;
    final available = (MediaQuery.sizeOf(context).width.clamp(0, 516) - 88) / 3;
    var labelHeight = 0.0;
    for (final label in ['Subir Z', 'Bajar Z', 'Izquierda', 'Derecha']) {
      final measure = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout(maxWidth: available - 4);
      if (measure.height > labelHeight) labelHeight = measure.height;
      measure.dispose();
    }
    final height =
        (labelHeight + 70) *
        BlanquitaDesign.density(context.watch<SettingsController>().settings);
    Widget move(MovementDirection direction, IconData icon, String label) =>
        HoldToMoveButton(
          movement: direction,
          icon: icon,
          label: label,
          enabled: enabled || state.activeMovement == direction,
          active: state.activeMovement == direction,
        );
    final warm =
        context.watch<SettingsController>().settings.visualTheme !=
        BlanquitaVisualTheme.original;
    if (warm && MediaQuery.textScalerOf(context).scale(14) < 23) {
      return LayoutBuilder(
        builder: (context, c) {
          final size = c.maxWidth.clamp(0.0, 264.0);
          final button = size * .25;
          final stop = size * .30;
          Widget position(double x, double y, Widget child, double extent) =>
              Positioned(
                left: x * size - extent / 2,
                top: y * size - extent / 2,
                width: extent,
                height: extent,
                child: child,
              );
          return SizedBox.square(
            dimension: size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(size * .12),
                    child: Transform.rotate(
                      angle: .785398,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: BlanquitaColors.of(context).canvas,
                          borderRadius: BorderRadius.circular(
                            BlanquitaRadius.control,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                position(
                  .5,
                  .16,
                  move(
                    MovementDirection.zUp,
                    Icons.keyboard_arrow_up_rounded,
                    'Z+',
                  ),
                  button,
                ),
                position(
                  .16,
                  .5,
                  move(
                    MovementDirection.xLeft,
                    Icons.keyboard_arrow_left_rounded,
                    'X−',
                  ),
                  button,
                ),
                position(
                  .5,
                  .5,
                  _StopButton(
                    enabled: state.isConnected,
                    onPressed: machine.stopNow,
                  ),
                  stop,
                ),
                position(
                  .84,
                  .5,
                  move(
                    MovementDirection.xRight,
                    Icons.keyboard_arrow_right_rounded,
                    'X+',
                  ),
                  button,
                ),
                position(
                  .5,
                  .84,
                  move(
                    MovementDirection.zDown,
                    Icons.keyboard_arrow_down_rounded,
                    'Z−',
                  ),
                  button,
                ),
              ],
            ),
          );
        },
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Row(
              children: [
                const Spacer(),
                Expanded(
                  child: move(
                    MovementDirection.zUp,
                    CupertinoIcons.chevron_up,
                    'Subir Z',
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: height,
            child: Row(
              children: [
                Expanded(
                  child: move(
                    MovementDirection.xLeft,
                    CupertinoIcons.chevron_left,
                    'Izquierda',
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _StopButton(
                    enabled: state.isConnected,
                    onPressed: machine.stopNow,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: move(
                    MovementDirection.xRight,
                    CupertinoIcons.chevron_right,
                    'Derecha',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: height,
            child: Row(
              children: [
                const Spacer(),
                Expanded(
                  child: move(
                    MovementDirection.zDown,
                    CupertinoIcons.chevron_down,
                    'Bajar Z',
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
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
          opacity: widget.enabled ? 1 : 0.7,
          duration: const Duration(milliseconds: 160),
          child: Container(
            margin: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BlanquitaColors.of(context).danger,
              border: Border.all(
                color: BlanquitaColors.of(
                  context,
                ).danger.withValues(alpha: 0.40),
              ),
              boxShadow: [
                BoxShadow(
                  color: BlanquitaColors.of(
                    context,
                  ).danger.withValues(alpha: _pressed ? 0.17 : 0.06),
                  blurRadius: _pressed ? 17 : 10,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.enabled
                      ? CupertinoIcons.stop_fill
                      : CupertinoIcons.lock_fill,
                  color: Colors.white,
                  size: 25,
                ),
                const SizedBox(height: 3),
                const Text(
                  'STOP',
                  style: TextStyle(
                    color: Colors.white,
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text('Pinza', style: Theme.of(context).textTheme.titleMedium),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _gripperLabel(machine.state.gripper),
                  key: ValueKey(machine.state.gripper),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: BlanquitaColors.of(context).cyan,
                  ),
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
                  child: const Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Icon(CupertinoIcons.arrow_left_right, size: 17),
                      Text('Abrir'),
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
                  child: const Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Icon(CupertinoIcons.arrow_right_arrow_left, size: 17),
                      Text('Cerrar'),
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
                        ).colorScheme.onSurface.withValues(alpha: 0.72),
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
          width: 48,
          height: 48,
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
                  color: BlanquitaColors.of(context).cyan,
                  child: Text(
                    state.sequenceStep == null
                        ? 'Preparando'
                        : '${state.sequenceStep}/8',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: BlanquitaColors.of(context).cyan,
                    ),
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
    final accepted = await BlanquitaModal.show<bool>(
      context,
      type: BlanquitaModalType.confirmation,
      title: 'Iniciar secuencia',
      message:
          'Verifica que el área esté libre. El ESP32 ejecutará los ocho pasos de forma autónoma.',
      actions: (context) => [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Iniciar'),
        ),
      ],
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
        ? BlanquitaColors.of(context).mint
        : current
        ? BlanquitaColors.of(context).cyan
        : cancelled
        ? BlanquitaColors.of(context).danger.withValues(alpha: 0.55)
        : BlanquitaColors.of(context).steel.withValues(alpha: 0.42);
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
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                fontWeight: current ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            index.toString().padLeft(2, '0'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontFeatures: [const FontFeature.tabularFigures()],
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: machine.state.isConnected,
    label: 'Detención inmediata. Cancela movimiento y secuencia.',
    child: FilledButton(
      onPressed: machine.state.isConnected ? machine.emergencyStop : null,
      style: FilledButton.styleFrom(
        side: BorderSide(color: BlanquitaColors.of(context).danger),
        backgroundColor: BlanquitaColors.of(context).danger,
        foregroundColor: Colors.white,
        disabledBackgroundColor: BlanquitaColors.of(
          context,
        ).danger.withValues(alpha: .45),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(48, 76),
        padding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        children: [
          Icon(
            machine.state.isConnected
                ? Icons.warning_rounded
                : Icons.lock_outline,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DETENCIÓN INMEDIATA',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  machine.state.isConnected
                      ? 'Detiene movimiento y secuencia'
                      : 'Sin enlace con el ESP32',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
