import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/machine_state.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../features/settings/controller/settings_controller.dart';
import '../../../shared/widgets/glass_surface.dart';
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 132),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  eyebrow: 'Mando seguro',
                  title: 'Control',
                  subtitle:
                      'Mantén pulsada una dirección; al soltar se envía STOP.',
                  trailing: ConnectionBadge(phase: state.connection),
                ),
                const SizedBox(height: 20),
                if (state.finalLimitActive == true) ...[
                  const SafetyBanner(
                    icon: Icons.report_rounded,
                    title: 'Final de carrera activado',
                    message:
                        'Ejes y secuencia están bloqueados. Pinza, STOP y emergencia siguen disponibles.',
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 14),
                ] else if (!state.isConnected &&
                    preferences.showWarnings &&
                    preferences.connectionLossAlerts) ...[
                  SafetyBanner(
                    icon: Icons.link_off_rounded,
                    title: 'Controles sin conexión',
                    message:
                        'Conéctate a ${MachineController.wifiName} para habilitar el mando.',
                    color: AppColors.warning,
                    action: state.connection == ConnectionPhase.connecting
                        ? null
                        : machine.reconnect,
                  ),
                  const SizedBox(height: 14),
                ],
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color:
                              (machine.manualControlsLocked
                                      ? AppColors.warning
                                      : AppColors.mint)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          machine.manualControlsLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          color: machine.manualControlsLocked
                              ? AppColors.warning
                              : AppColors.mint,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Control manual',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              machine.manualControlsLocked
                                  ? 'Bloqueado contra toques accidentales'
                                  : 'Desbloqueado · mantener para mover',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.54),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: !machine.manualControlsLocked,
                        onChanged: state.isConnected
                            ? (value) => machine.setManualControlsLocked(!value)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: SectionLabel('Movimiento X / Z'),
                          ),
                          Text(
                            state.activeMovement?.axis == null
                                ? 'EN REPOSO'
                                : 'EJE ${state.activeMovement!.axis} ACTIVO',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: state.activeMovement == null
                                      ? AppColors.mint
                                      : AppColors.cyan,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _ControlPad(machine: machine),
                      const SizedBox(height: 18),
                      Text(
                        'Heartbeat activo cada 200 ms durante el movimiento',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.48),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 610;
                    final gripper = _GripperPanel(machine: machine);
                    final speed = _SpeedPanel(machine: machine);
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: gripper),
                              const SizedBox(width: 14),
                              Expanded(child: speed),
                            ],
                          )
                        : Column(
                            children: [
                              gripper,
                              const SizedBox(height: 14),
                              speed,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),
                _SequencePanel(machine: machine),
                const SizedBox(height: 16),
                _EmergencyPanel(machine: machine),
              ],
            ),
          ),
        ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 410),
      child: AspectRatio(
        aspectRatio: 1.22,
        child: GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 1.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            const SizedBox.shrink(),
            HoldToMoveButton(
              movement: MovementDirection.zUp,
              icon: Icons.keyboard_arrow_up_rounded,
              label: 'SUBIR Z',
              enabled: enabled || state.activeMovement == MovementDirection.zUp,
              active: state.activeMovement == MovementDirection.zUp,
            ),
            const SizedBox.shrink(),
            HoldToMoveButton(
              movement: MovementDirection.xLeft,
              icon: Icons.keyboard_arrow_left_rounded,
              label: 'IZQUIERDA',
              enabled:
                  enabled || state.activeMovement == MovementDirection.xLeft,
              active: state.activeMovement == MovementDirection.xLeft,
            ),
            _StopButton(enabled: state.isConnected, onPressed: machine.stopNow),
            HoldToMoveButton(
              movement: MovementDirection.xRight,
              icon: Icons.keyboard_arrow_right_rounded,
              label: 'DERECHA',
              enabled:
                  enabled || state.activeMovement == MovementDirection.xRight,
              active: state.activeMovement == MovementDirection.xRight,
            ),
            const SizedBox.shrink(),
            HoldToMoveButton(
              movement: MovementDirection.zDown,
              icon: Icons.keyboard_arrow_down_rounded,
              label: 'BAJAR Z',
              enabled:
                  enabled || state.activeMovement == MovementDirection.zDown,
              active: state.activeMovement == MovementDirection.zDown,
            ),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Detener movimiento',
    child: InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.28,
        duration: const Duration(milliseconds: 150),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warning.withValues(alpha: 0.12),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.45),
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop_rounded, color: AppColors.warning, size: 30),
              Text(
                'STOP',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GripperPanel extends StatelessWidget {
  const _GripperPanel({required this.machine});
  final MachineController machine;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Pinza',
          trailing: Text(
            _gripperLabel(machine.state.gripper),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.mint,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 16),
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
                    Icon(Icons.open_in_full_rounded, size: 19),
                    SizedBox(width: 8),
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_fullscreen_rounded, size: 19),
                    SizedBox(width: 8),
                    Text('Cerrar'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  String _gripperLabel(GripperState value) => switch (value) {
    GripperState.unknown => 'SIN CONFIRMAR',
    GripperState.opening => 'ABRIENDO',
    GripperState.open => 'ABIERTA',
    GripperState.closing => 'CERRANDO',
    GripperState.closed => 'CERRADA',
  };
}

class _SpeedPanel extends StatelessWidget {
  const _SpeedPanel({required this.machine});
  final MachineController machine;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Velocidad solicitada'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GlassButton(
                onPressed: machine.canUseAuxiliaryControls
                    ? machine.requestSlower
                    : null,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove),
                    SizedBox(width: 6),
                    Text('Lento'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassButton(
                onPressed: machine.canUseAuxiliaryControls
                    ? machine.requestFaster
                    : null,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Rápido'),
                    SizedBox(width: 6),
                    Icon(Icons.add),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          'El ESP32 no confirma un valor absoluto.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.42),
          ),
        ),
      ],
    ),
  );
}

class _SequencePanel extends StatelessWidget {
  const _SequencePanel({required this.machine});
  final MachineController machine;

  static const steps = [
    'Z bajando',
    'Cerrando pinza',
    'Z subiendo',
    'X derecha',
    'Z bajando',
    'Abriendo pinza',
    'Z subiendo',
    'X izquierda',
  ];

  @override
  Widget build(BuildContext context) {
    final state = machine.state;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('Automático')),
              if (state.sequenceActive)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (state.sequence != SequencePhase.idle) ...[
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: steps.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final number = index + 1;
                  final current = state.sequenceStep == number;
                  final complete =
                      state.sequence == SequencePhase.completed ||
                      (state.sequenceStep ?? 0) > number;
                  final color = current
                      ? AppColors.cyan
                      : complete
                      ? AppColors.mint
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.28);
                  return Container(
                    width: 118,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.26)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$number',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            steps[index],
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],
          FilledButton.icon(
            onPressed: machine.canStartSequence
                ? () => _confirmAndStart(context, machine)
                : null,
            icon: Icon(
              state.sequenceActive
                  ? Icons.hourglass_top_rounded
                  : Icons.play_arrow_rounded,
            ),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                state.sequenceActive
                    ? 'SECUENCIA EN CURSO'
                    : 'EJECUTAR SECUENCIA',
              ),
            ),
          ),
          if (state.sequenceActive) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: machine.emergencyStop,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('CANCELAR SECUENCIA'),
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
        icon: const Icon(Icons.play_circle_outline_rounded),
        title: const Text('Iniciar secuencia automática'),
        content: const Text(
          'Verifica que el área esté libre. El ESP32 ejecutará los ocho pasos de forma autónoma.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('INICIAR'),
          ),
        ],
      ),
    );
    if (accepted == true) machine.startSequence();
  }
}

class _EmergencyPanel extends StatelessWidget {
  const _EmergencyPanel({required this.machine});
  final MachineController machine;

  @override
  Widget build(BuildContext context) => GlassCard(
    tint: AppColors.danger.withValues(alpha: 0.08),
    borderColor: AppColors.danger.withValues(alpha: 0.28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Seguridad'),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.18),
            minimumSize: const Size.fromHeight(66),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: machine.state.isConnected ? machine.emergencyStop : null,
          icon: const Icon(Icons.emergency_share_rounded, size: 29),
          label: const Text(
            'PARADA DE EMERGENCIA',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
          ),
        ),
      ],
    ),
  );
}
