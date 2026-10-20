import '../../features/settings/controller/app_settings.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/settings/controller/settings_controller.dart';
import 'blanquita_design.dart';

/// Keeps the same child Element (and navigation/controllers) throughout the fade.
class VisualTransition extends StatefulWidget {
  const VisualTransition({super.key, required this.child, required this.theme});
  final Widget child;
  final BlanquitaVisualTheme theme;
  @override
  State<VisualTransition> createState() => _VisualTransitionState();
}

class _VisualTransitionState extends State<VisualTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: BlanquitaDesign.theme,
    value: 1,
  );
  @override
  void didUpdateWidget(VisualTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final s = context.read<SettingsController>().settings;
    if (oldWidget.theme != widget.theme &&
        !BlanquitaDesign.reduce(context, s)) {
      _animation.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>().settings;
    final reduce = BlanquitaDesign.reduce(context, s);
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final amount = reduce
            ? 0.0
            : 1 - Curves.easeOutCubic.transform(_animation.value);
        return ImageFiltered(
          enabled: amount > 0 && s.glassEnabled && !s.performanceMode,
          imageFilter: ImageFilter.blur(
            sigmaX: amount * 1.4,
            sigmaY: amount * 1.4,
          ),
          child: Opacity(opacity: 1 - amount * .15, child: child),
        );
      },
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }
}
