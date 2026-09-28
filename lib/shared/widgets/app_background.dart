import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF061017), Color(0xFF0B1822), Color(0xFF080E18)]
              : const [Color(0xFFE7F3F6), Color(0xFFF8FBFC), Color(0xFFEAF0FB)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -130,
            right: -90,
            child: _GlowOrb(
              size: 330,
              color: AppColors.cyan.withValues(alpha: isDark ? 0.12 : 0.18),
            ),
          ),
          Positioned(
            top: 340,
            left: -150,
            child: _GlowOrb(
              size: 370,
              color: AppColors.violet.withValues(alpha: isDark ? 0.09 : 0.12),
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
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}
