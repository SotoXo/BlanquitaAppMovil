import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/design/blanquita_design.dart';
import '../../../core/models/machine_state.dart';
import '../../../features/settings/controller/settings_controller.dart';

class CartesianVisualizer extends StatefulWidget {
  const CartesianVisualizer({super.key, required this.state});

  final MachineState state;

  @override
  State<CartesianVisualizer> createState() => _CartesianVisualizerState();
}

class _CartesianVisualizerState extends State<CartesianVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CartesianVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.state.activeMovement != null || widget.state.sequenceActive) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final reduceMotion =
        settings.reduceMotion ||
        settings.performanceMode ||
        MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _controller.isAnimating) _controller.stop();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _CartesianPainter(
            colors: BlanquitaColors.of(context),
            state: widget.state,
            pulse: reduceMotion ? 0.35 : _controller.value,
            brightness: Theme.of(context).brightness,
            sensitivity: settings.visualSensitivity,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _CartesianPainter extends CustomPainter {
  const _CartesianPainter({
    required this.colors,
    required this.state,
    required this.pulse,
    required this.brightness,
    required this.sensitivity,
  });

  final BlanquitaColors colors;
  final MachineState state;
  final double pulse;
  final Brightness brightness;
  final double sensitivity;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.20)
        : const Color(0xFF17313D).withValues(alpha: 0.28);
    final line = Paint()
      ..color = dim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final faint = Paint()
      ..color = colors.cyan.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final active = state.finalLimitActive == true ? colors.danger : colors.cyan;
    final activePaint = Paint()
      ..color = active
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final left = size.width * 0.12;
    final right = size.width * 0.88;
    final top = size.height * 0.23;
    final bottom = size.height * 0.84;

    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(left, y), Offset(right, y), faint);
    }

    canvas.drawLine(Offset(left, top), Offset(right, top), line);
    canvas.drawLine(Offset(left, top), Offset(left, bottom), line);
    canvas.drawLine(Offset(right, top), Offset(right, bottom), line);
    canvas.drawLine(Offset(left - 12, bottom), Offset(left + 18, bottom), line);
    canvas.drawLine(
      Offset(right - 18, bottom),
      Offset(right + 12, bottom),
      line,
    );

    final movement = state.activeMovement;
    final strength = (4 + 8 * pulse) * sensitivity;
    var headX = size.width * 0.5;
    var headY = top + 13;
    if (movement == MovementDirection.xLeft) headX -= strength;
    if (movement == MovementDirection.xRight) headX += strength;
    if (movement == MovementDirection.zUp) headY -= strength * 0.45;
    if (movement == MovementDirection.zDown) headY += strength * 0.45;

    if (movement?.axis == 'X') {
      canvas.drawLine(Offset(left, top), Offset(right, top), activePaint);
      _drawDirectionalArrow(
        canvas,
        movement == MovementDirection.xLeft
            ? Offset(left + 18, top - 18)
            : Offset(right - 18, top - 18),
        movement == MovementDirection.xLeft ? math.pi : 0,
        activePaint,
      );
    }

    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(headX, headY + 8), width: 72, height: 34),
      const Radius.circular(10),
    );
    final headFill = Paint()
      ..color = active.withValues(alpha: movement != null ? 0.22 : 0.09)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(headRect, headFill);
    canvas.drawRRect(headRect, movement != null ? activePaint : line);

    final stemTop = headY + 26;
    final stemBottom = size.height * 0.64;
    canvas.drawLine(
      Offset(headX, stemTop),
      Offset(headX, stemBottom),
      movement?.axis == 'Z' ? activePaint : line,
    );
    if (movement?.axis == 'Z') {
      _drawDirectionalArrow(
        canvas,
        Offset(
          headX + 22,
          movement == MovementDirection.zUp ? stemTop + 8 : stemBottom - 8,
        ),
        movement == MovementDirection.zUp ? -math.pi / 2 : math.pi / 2,
        activePaint,
      );
    }

    final gripY = stemBottom + 6;
    final gripperPaint = Paint()
      ..color = switch (state.gripper) {
        GripperState.open || GripperState.closed => colors.mint,
        GripperState.opening || GripperState.closing => colors.cyan,
        GripperState.unknown => dim,
      }
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(headX - 15, gripY),
      Offset(headX + 15, gripY),
      gripperPaint,
    );
    final opened =
        state.gripper == GripperState.open ||
        state.gripper == GripperState.opening ||
        state.gripper == GripperState.unknown;
    final spread = opened ? 24.0 : 13.0;
    canvas.drawLine(
      Offset(headX - 13, gripY),
      Offset(headX - spread, gripY + 28),
      gripperPaint,
    );
    canvas.drawLine(
      Offset(headX + 13, gripY),
      Offset(headX + spread, gripY + 28),
      gripperPaint,
    );

    final sensorColor = state.finalLimitActive == true
        ? colors.danger
        : state.finalLimitActive == false
        ? colors.mint
        : dim;
    canvas.drawCircle(Offset(right, top), 8, Paint()..color = sensorColor);
    if (state.finalLimitActive == true) {
      canvas.drawCircle(
        Offset(right, top),
        13 + pulse * 5,
        Paint()
          ..color = colors.danger.withValues(alpha: 0.35 * (1 - pulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawDirectionalArrow(
    Canvas canvas,
    Offset center,
    double angle,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawLine(const Offset(-10, 0), const Offset(10, 0), paint);
    canvas.drawLine(const Offset(10, 0), const Offset(4, -6), paint);
    canvas.drawLine(const Offset(10, 0), const Offset(4, 6), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CartesianPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.state != state ||
      oldDelegate.pulse != pulse ||
      oldDelegate.brightness != brightness ||
      oldDelegate.sensitivity != sensitivity;
}
