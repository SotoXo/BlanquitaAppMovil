import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../settings/controller/settings_controller.dart';
import '../domain/alfresi_message.dart';

/// Vector asset drawn locally, including all five moods; no emoji or network.
class AlfresiAvatar extends StatefulWidget {
  const AlfresiAvatar({
    super.key,
    this.mood = AlfresiMood.idle,
    this.size = 48,
  });
  final AlfresiMood mood;
  final double size;
  @override
  State<AlfresiAvatar> createState() => _AlfresiAvatarState();
}

class _AlfresiAvatarState extends State<AlfresiAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.watch<SettingsController>().settings;
    if (!BlanquitaDesign.reduce(context, s) && s.assistantAnimations) {
      if (!_animation.isAnimating) _animation.forward();
    } else {
      _animation.stop();
      _animation.value = 0;
    }
  }

  @override
  void didUpdateWidget(AlfresiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final s = context.read<SettingsController>().settings;
    if (oldWidget.mood != widget.mood &&
        s.assistantAnimations &&
        !BlanquitaDesign.reduce(context, s)) {
      _animation.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, -math.sin(_animation.value * math.pi) * 1.4),
        child: SizedBox.square(
          dimension: widget.size,
          child: Stack(
            children: [
              Image.asset(
                'assets/alfresi/alfresi_premium.png',
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                cacheWidth: 384,
                errorBuilder: (_, _, _) => CustomPaint(
                  size: Size.square(widget.size),
                  painter: AlfresiAvatarPainter(widget.mood),
                ),
              ),
              if (widget.mood != AlfresiMood.idle)
                Positioned(
                  right: 0,
                  bottom: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: BlanquitaColors.hamburger.canvas,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BlanquitaColors.sesame.withValues(alpha: .4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        switch (widget.mood) {
                          AlfresiMood.success => Icons.check_circle,
                          AlfresiMood.error => Icons.error,
                          AlfresiMood.warning => Icons.warning_amber_rounded,
                          _ => Icons.more_horiz,
                        },
                        size: widget.size * .27,
                        color: switch (widget.mood) {
                          AlfresiMood.success => BlanquitaColors.hamburger.mint,
                          AlfresiMood.error => BlanquitaColors.hamburger.danger,
                          _ => BlanquitaColors.hamburger.cyanDeep,
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }
}

class AlfresiAvatarPainter extends CustomPainter {
  const AlfresiAvatarPainter(this.mood);
  final AlfresiMood mood;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final c = switch (mood) {
      AlfresiMood.error => BlanquitaColors.hamburger.danger,
      AlfresiMood.warning => BlanquitaColors.hamburger.warning,
      AlfresiMood.success => BlanquitaColors.hamburger.mint,
      _ => BlanquitaColors.hamburger.cyan,
    };
    final paint = Paint()..color = c.withValues(alpha: .12);
    canvas.drawCircle(const Offset(50, 52), 46, paint);
    paint
      ..color = BlanquitaColors.sesame
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 19), const Offset(50, 9), paint);
    canvas.drawCircle(const Offset(50, 7), 4, paint..color = c);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 65, 56, 28),
        const Radius.circular(12),
      ),
      paint..color = BlanquitaColors.sesame,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 21, 74, 53),
        const Radius.circular(18),
      ),
      paint..color = BlanquitaColors.hamburger.coldWhite,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(21, 30, 58, 34),
        const Radius.circular(12),
      ),
      paint..color = BlanquitaColors.hamburger.canvas,
    );
    paint.color = c;
    if (mood == AlfresiMood.thinking) {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(Offset(37.0 + 13 * i, 47), 3, paint);
      }
    } else {
      for (final x in [37.0, 63.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, 46),
              width: 7,
              height: mood == AlfresiMood.success ? 5 : 12,
            ),
            const Radius.circular(4),
          ),
          paint,
        );
      }
    }
    canvas.drawCircle(
      const Offset(18, 47),
      3,
      paint..color = BlanquitaColors.hamburger.cyan,
    );
    canvas.drawCircle(const Offset(82, 47), 3, paint);
    final text = TextPainter(
      text: TextSpan(
        text: 'A',
        style: TextStyle(
          color: BlanquitaColors.hamburger.canvas,
          fontFamily: 'Outfit',
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(50 - text.width / 2, 74));
    canvas.restore();
  }

  @override
  bool shouldRepaint(AlfresiAvatarPainter oldDelegate) =>
      oldDelegate.mood != mood;
}
