import 'package:flutter/material.dart';
import '../../../app/design/blanquita_design.dart';
import '../domain/alfresi_message.dart';

/// Exact viewports of the user's original artwork; no character redesign.
class AlfresiAvatar extends StatelessWidget {
  const AlfresiAvatar({
    super.key,
    this.mood = AlfresiMood.idle,
    this.size = AlfresiSizes.m,
  });
  final AlfresiMood mood;
  final double size;
  @override
  Widget build(BuildContext context) {
    final x = switch (mood) {
      AlfresiMood.idle => 15.0,
      AlfresiMood.success => 111.0,
      AlfresiMood.thinking => 207.0,
      AlfresiMood.warning => 397.0,
      AlfresiMood.error => 493.0,
    };
    final hero = size >= AlfresiSizes.xl;
    final width = hero ? 238.0 : 94.0;
    final left = hero ? 18.0 : x;
    final top = hero ? 162.0 : 863.0;
    final factor = size / width;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            hero ? BlanquitaRadius.hero : size / 2,
          ),
          child: Stack(
            children: [
              Positioned(
                left: -left * factor,
                top: -top * factor,
                width: 1536 * factor,
                height: 1024 * factor,
                child: Image.asset(
                  'assets/alfresi/referencia_frutilla.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Code-native fallback used by the existing asset-export test only.
class AlfresiAvatarPainter extends CustomPainter {
  const AlfresiAvatarPainter(this.mood);
  final AlfresiMood mood;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final p = Paint()..color = BlanquitaColors.ketchup;
    final body = Path()
      ..moveTo(12, 30)
      ..cubicTo(-2, 65, 42, 98, 50, 98)
      ..cubicTo(60, 98, 102, 65, 88, 30)
      ..cubicTo(74, 10, 26, 10, 12, 30);
    canvas.drawPath(body, p);
    p.color = BlanquitaColors.lettuce;
    final leaves = Path()
      ..moveTo(50, 30)
      ..lineTo(22, 10)
      ..lineTo(44, 17)
      ..lineTo(50, 1)
      ..lineTo(58, 18)
      ..lineTo(82, 11)
      ..lineTo(66, 32)
      ..close();
    canvas.drawPath(leaves, p);
    for (final x in [34.0, 67.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 48), width: 25, height: 30),
        p..color = BlanquitaColors.cream,
      );
      canvas.drawCircle(Offset(x, 50), 8, p..color = BlanquitaColors.lettuce);
      canvas.drawCircle(
        Offset(x, 50),
        5,
        p..color = BlanquitaColors.backgroundDeep,
      );
    }
    canvas.drawArc(
      const Rect.fromLTWH(39, 62, 24, 14),
      0,
      3.14,
      false,
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(AlfresiAvatarPainter oldDelegate) =>
      oldDelegate.mood != mood;
}
