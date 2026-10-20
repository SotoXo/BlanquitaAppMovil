import 'package:flutter/material.dart';
import '../../../app/design/blanquita_design.dart';
import '../domain/alfresi_message.dart';
import 'alfresi_avatar.dart';

class AlfresiBubble extends StatelessWidget {
  const AlfresiBubble({
    super.key,
    required this.message,
    this.title = 'ALFRESI',
    this.mood = AlfresiMood.idle,
  });
  final String message, title;
  final AlfresiMood mood;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AlfresiAvatar(size: AlfresiSizes.l, mood: mood),
      const SizedBox(width: BlanquitaSpacing.sm),
      Expanded(
        child: CustomPaint(
          painter: const _BubbleTail(),
          child: Container(
            padding: BlanquitaSpacing.compact,
            decoration: BoxDecoration(
              color: BlanquitaColors.cream,
              borderRadius: BlanquitaRadius.card,
            ),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BlanquitaColors.backgroundDeep,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _BubbleTail extends CustomPainter {
  const _BubbleTail();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(1, 17)
        ..lineTo(-7, 22)
        ..lineTo(1, 30)
        ..close(),
      Paint()..color = BlanquitaColors.cream,
    );
  }

  @override
  bool shouldRepaint(_BubbleTail oldDelegate) => false;
}
