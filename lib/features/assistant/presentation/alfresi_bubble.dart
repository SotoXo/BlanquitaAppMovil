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
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: BlanquitaColors.hamburger.coldWhite,
            border: Border.all(color: BlanquitaColors.hamburger.cyanDeep),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: BlanquitaColors.hamburger.canvas,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BlanquitaColors.hamburger.graphite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      AlfresiAvatar(size: 72, mood: mood),
    ],
  );
}
