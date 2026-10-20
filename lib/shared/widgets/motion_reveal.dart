import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/settings/controller/settings_controller.dart';

class MotionReveal extends StatefulWidget {
  const MotionReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.035),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<MotionReveal> createState() => _MotionRevealState();
}

class _MotionRevealState extends State<MotionReveal> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final reduce =
        settings.reduceMotion ||
        settings.performanceMode ||
        MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: _visible || reduce ? 1 : 0,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible || reduce ? Offset.zero : widget.offset,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
