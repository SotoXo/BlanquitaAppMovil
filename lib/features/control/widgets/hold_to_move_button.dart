import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/design/blanquita_design.dart';
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
    this.limitBlocked = false,
  });

  final MovementDirection movement;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool active;
  final bool limitBlocked;

  @override
  State<HoldToMoveButton> createState() => _HoldToMoveButtonState();
}

class _HoldToMoveButtonState extends State<HoldToMoveButton> {
  MachineController? _machine;
  int? _pointer;
  int? _pressId;
  MachineController? _pressMachine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _machine = context.read<MachineController>();
  }

  void _onDown(PointerDownEvent event) {
    if (!widget.enabled || widget.limitBlocked || _pointer != null) return;
    final pressId = _machine?.beginMovement(widget.movement);
    if (pressId != null) {
      _pointer = event.pointer;
      _pressId = pressId;
      _pressMachine = _machine;
    }
  }

  void _release(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    final pressId = _pressId;
    _pressId = null;
    if (pressId != null) _pressMachine?.releaseMovement(pressId);
    _pressMachine = null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final duration = settings.reduceMotion || settings.performanceMode
        ? Duration.zero
        : const Duration(milliseconds: 155);
    final foreground = widget.limitBlocked
        ? BlanquitaColors.of(context).danger
        : widget.active
        ? const Color(0xFF031419)
        : widget.enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.26);

    return Semantics(
      button: true,
      excludeSemantics: true,
      enabled: widget.enabled && !widget.limitBlocked,
      label: widget.limitBlocked
          ? '${widget.label}. Bloqueada por final de carrera.'
          : '${widget.label}. Mantener pulsado para mover.',
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
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.all(1.2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BlanquitaRadius.control),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.limitBlocked
                    ? [
                        BlanquitaColors.of(
                          context,
                        ).danger.withValues(alpha: 0.7),
                        BlanquitaColors.of(
                          context,
                        ).danger.withValues(alpha: 0.15),
                      ]
                    : widget.active
                    ? [
                        BlanquitaColors.of(context).cyan,
                        BlanquitaColors.of(context).cyanDeep,
                      ]
                    : [
                        Colors.white.withValues(
                          alpha: widget.enabled ? 0.15 : 0.055,
                        ),
                        BlanquitaColors.of(
                          context,
                        ).cyan.withValues(alpha: widget.enabled ? 0.07 : 0.02),
                        Colors.white.withValues(alpha: 0.035),
                      ],
              ),
              boxShadow: widget.active && !settings.performanceMode
                  ? [
                      BoxShadow(
                        color: BlanquitaColors.of(
                          context,
                        ).cyan.withValues(alpha: 0.25),
                        blurRadius: 22,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BlanquitaRadius.control),
                color: widget.limitBlocked
                    ? BlanquitaColors.of(context).danger.withValues(alpha: 0.12)
                    : widget.active
                    ? BlanquitaColors.of(context).cyan
                    : widget.enabled
                    ? (isDark
                              ? BlanquitaColors.of(context).graphiteRaised
                              : scheme.surface)
                          .withValues(alpha: 0.92)
                    : (isDark
                              ? BlanquitaColors.of(context).graphite
                              : scheme.surface)
                          .withValues(alpha: 0.72),
                gradient: widget.active || widget.limitBlocked
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(
                            alpha: widget.enabled ? 0.055 : 0.018,
                          ),
                          (isDark
                                  ? BlanquitaColors.of(context).graphite
                                  : scheme.surface)
                              .withValues(alpha: 0.90),
                        ],
                      ),
              ),
              child: Stack(
                children: [
                  if (widget.limitBlocked)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: BlanquitaColors.of(context).danger,
                      ),
                    ),
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
    final pressId = _pressId;
    if (pressId != null) _pressMachine?.releaseMovement(pressId);
    super.dispose();
  }
}
