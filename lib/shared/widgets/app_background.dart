import 'package:flutter/material.dart';

import '../../app/design/blanquita_design.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = BlanquitaColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.canvas,
        gradient: RadialGradient(
          center: const Alignment(0.72, -0.78),
          radius: 1.15,
          colors: [colors.graphiteRaised, colors.canvas],
          stops: const [0, 0.72],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _IndustrialBackdropPainter(
                isDark: isDark,
                colors: colors,
              ),
            ),
          ),
          Positioned(
            top: -160,
            right: -120,
            child: _GlowOrb(
              size: 360,
              color: colors.cyan.withValues(alpha: isDark ? 0.075 : 0.12),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 1],
        ),
      ),
    ),
  );
}

class _IndustrialBackdropPainter extends CustomPainter {
  const _IndustrialBackdropPainter({
    required this.isDark,
    required this.colors,
  });

  final bool isDark;
  final BlanquitaColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = (isDark ? colors.coldWhite : const Color(0xFF17343D))
          .withValues(alpha: isDark ? 0.022 : 0.035)
      ..strokeWidth = 0.7;
    const step = 38.0;
    for (double x = 18; x < size.width; x += step) {
      for (double y = 22; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.7, line);
      }
    }

    final rail = Paint()
      ..color = colors.cyan.withValues(alpha: isDark ? 0.025 : 0.04)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.78, 0),
      Offset(size.width * 0.78, size.height),
      rail,
    );
  }

  @override
  bool shouldRepaint(covariant _IndustrialBackdropPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.colors != colors;
}
