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
    final duration = settings.reduceMotion || settings.performanceMode
        ? Duration.zero
        : const Duration(milliseconds: 155);
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
          scale: widget.active ? 0.945 : 1,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minWidth: 92, minHeight: 84),
            padding: const EdgeInsets.all(1.2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.active
                    ? [AppColors.cyan, AppColors.cyanDeep]
                    : [
                        Colors.white.withValues(
                          alpha: widget.enabled ? 0.15 : 0.055,
                        ),
                        AppColors.cyan.withValues(
                          alpha: widget.enabled ? 0.07 : 0.02,
                        ),
                        Colors.white.withValues(alpha: 0.035),
                      ],
              ),
              boxShadow: widget.active && !settings.performanceMode
                  ? [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.25),
                        blurRadius: 22,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(21.8),
                color: widget.active
                    ? AppColors.cyan
                    : widget.enabled
                    ? AppColors.graphiteRaised.withValues(alpha: 0.92)
                    : AppColors.graphite.withValues(alpha: 0.72),
                gradient: widget.active
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(
                            alpha: widget.enabled ? 0.055 : 0.018,
                          ),
                          AppColors.graphite.withValues(alpha: 0.90),
                        ],
                      ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Text(
                      widget.movement.axis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.42),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 29, color: foreground),
                        const SizedBox(height: 5),
                        Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.05,
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
    );
  }

  @override
  void dispose() {
    if (_pointer != null) _machine?.stopMovementOnUnmount(widget.movement);
    _pointer = null;
    super.dispose();
  }
}
