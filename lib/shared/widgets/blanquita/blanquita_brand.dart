import 'package:flutter/material.dart';
import '../../../app/design/blanquita_design.dart';

/// Small brand mark; food colors remain a visual identity, not restaurant data.
class BlanquitaBrand extends StatelessWidget {
  const BlanquitaBrand({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'BLANQUITA · tema Hamburguesa',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: const _BrandPainter()),
  );
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40);
    final p = Paint();
    final bun = Path()
      ..moveTo(4, 16)
      ..cubicTo(4, 0, 36, 0, 36, 16)
      ..close();
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFDF85), Color(0xFFE67E15)],
    ).createShader(const Rect.fromLTWH(4, 4, 32, 12));
    canvas.drawPath(bun, p);
    p.shader = null;
    p.color = BlanquitaColors.hamburger.coldWhite;
    for (final seed in [
      const Offset(12, 10),
      const Offset(20, 7),
      const Offset(27, 11),
    ]) {
      canvas.drawOval(Rect.fromCenter(center: seed, width: 3, height: 1.5), p);
    }
    void layer(double y, double height, Color c) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, y, 34, height),
        const Radius.circular(3),
      ),
      p..color = c,
    );
    layer(18, 4, BlanquitaColors.hamburger.mint);
    layer(23, 4, BlanquitaColors.hamburger.danger);
    layer(28, 5, const Color(0xFF6B3515));
    layer(34, 4, BlanquitaColors.hamburger.cyanDeep);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandPainter oldDelegate) => false;
}
