import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/machine_state.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../features/settings/controller/settings_controller.dart';

class HoldToMoveButton extends StatefulWidget {
  const HoldToMoveButton({
    super.key,
    required this.movement,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.active,
  });

  final MovementDirection movement;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool active;

  @override
  State<HoldToMoveButton> createState() => _HoldToMoveButtonState();
}

class _HoldToMoveButtonState extends State<HoldToMoveButton> {
  MachineController? _machine;
  int? _pointer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _machine = context.read<MachineController>();
  }

  void _onDown(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    if (_machine?.startMovement(widget.movement) == true) {
      _pointer = event.pointer;
    }
  }

  void _release(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _machine?.stopMovement(widget.movement);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final duration = settings.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 130);
    final foreground = widget.active
        ? const Color(0xFF031419)
        : widget.enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.26);

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: '${widget.label}. Mantener pulsado para mover.',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerUp: _release,
        onPointerCancel: _release,
        child: AnimatedScale(
          scale: widget.active ? 0.96 : 1,
          duration: duration,
          child: AnimatedContainer(
            duration: duration,
            constraints: const BoxConstraints(minWidth: 92, minHeight: 88),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: widget.active
                  ? AppColors.cyan
                  : widget.enabled
                  ? Colors.white.withValues(alpha: 0.065)
                  : Colors.white.withValues(alpha: 0.025),
              border: Border.all(
                width: widget.active ? 2 : 1,
                color: widget.active
                    ? AppColors.cyan
                    : Colors.white.withValues(
                        alpha: widget.enabled ? 0.14 : 0.05,
                      ),
              ),
              boxShadow: widget.active && !settings.performanceMode
                  ? [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.34),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 35, color: foreground),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_pointer != null) _machine?.stopMovement(widget.movement);
    super.dispose();
  }
}
