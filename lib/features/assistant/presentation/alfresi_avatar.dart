import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../settings/controller/settings_controller.dart';
import '../domain/alfresi_message.dart';

enum AlfresiExpression { normal, triste, frustrado, enojado }

/// Facial variants of the supplied ALFRESI; all production assets retain alpha.
class AlfresiAvatar extends StatefulWidget {
  const AlfresiAvatar({
    super.key,
    this.mood = AlfresiMood.idle,
    this.size = AlfresiSizes.m,
    this.expression,
  });
  final AlfresiMood mood;
  final double size;
  final AlfresiExpression? expression;
  @override
  State<AlfresiAvatar> createState() => _AlfresiAvatarState();
}

class _AlfresiAvatarState extends State<AlfresiAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _enabled = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.watch<SettingsController?>()?.settings;
    final enabled =
        s != null &&
        s.assistantAnimations &&
        !BlanquitaDesign.reduce(context, s) &&
        TickerMode.valuesOf(context).enabled;
    if (enabled != _enabled) {
      _enabled = enabled;
      if (enabled) {
        _breath.repeat(reverse: true);
      } else {
        _breath.stop();
        _breath.value = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expression =
        widget.expression ??
        switch (widget.mood) {
          AlfresiMood.error => AlfresiExpression.triste,
          AlfresiMood.warning => AlfresiExpression.frustrado,
          _ => AlfresiExpression.normal,
        };
    final asset = 'assets/alfresi/alfresi_${expression.name}_alpha.png';
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _breath,
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: _enabled ? BlanquitaMotion.modal : Duration.zero,
              child: Image.asset(
                asset,
                key: ValueKey(asset),
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                cacheHeight:
                    (widget.size *
                            MediaQuery.devicePixelRatioOf(context) *
                            1.25)
                        .ceil()
                        .clamp(192, 1024),
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -math.sin(_breath.value * math.pi) * 1.8),
            child: Transform.rotate(
              angle: widget.mood == AlfresiMood.thinking
                  ? math.sin(_breath.value * math.pi * 2) * .025
                  : 0,
              child: Transform.scale(
                scale: 1 + _breath.value * .025,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
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
