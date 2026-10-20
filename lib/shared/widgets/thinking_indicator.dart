import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/design/blanquita_design.dart';
import '../../features/settings/controller/settings_controller.dart';

/// Indeterminate activity only: dots never imply a percentage or completion.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key, this.label = 'Pensando…', this.color});
  final String label;
  final Color? color;

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsController>().settings;
    _animate =
        !BlanquitaDesign.reduce(context, settings) &&
        settings.assistantAnimations &&
        TickerMode.valuesOf(context).enabled;
    if (_animate) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    liveRegion: true,
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final color = widget.color ?? Theme.of(context).colorScheme.primary;
            return Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Text(
                  widget.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: color),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Opacity(
                          opacity: _animate
                              ? .35 +
                                    .65 *
                                        (.5 +
                                            .5 *
                                                math.sin(
                                                  (_pulse.value - i / 5) *
                                                      math.pi *
                                                      2,
                                                ))
                              : 1,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
}
