import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/models/machine_state.dart';
import 'glass_surface.dart';

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.48),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ],
    ),
  );
}

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({super.key, required this.phase});

  final ConnectionPhase phase;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      ConnectionPhase.connected => ('ONLINE', AppColors.mint),
      ConnectionPhase.connecting => ('CONECTANDO', AppColors.warning),
      ConnectionPhase.error => ('ERROR', AppColors.danger),
      ConnectionPhase.disconnected => ('OFFLINE', AppColors.danger),
    };
    return GlassSurface(
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tint: color.withValues(alpha: 0.10),
      borderColor: color.withValues(alpha: 0.32),
      elevation: 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(color: color, size: 7),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class SafetyBanner extends StatelessWidget {
  const SafetyBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      tint: color.withValues(alpha: 0.12),
      borderColor: color.withValues(alpha: 0.42),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: action,
              child: Text(actionLabel ?? 'REINTENTAR'),
            ),
        ],
      ),
    );
  }
}
