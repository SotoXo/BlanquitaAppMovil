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
      ConnectionPhase.connected => ('Online', AppColors.mint),
      ConnectionPhase.connecting => ('Conectando', AppColors.warning),
      ConnectionPhase.error => ('Error', AppColors.danger),
      ConnectionPhase.disconnected => ('Offline', AppColors.danger),
    };
    return GlassChip(
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(color: color, size: 7),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
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
    return GlassPanel(
      padding: const EdgeInsets.all(15),
      tint: color.withValues(alpha: 0.12),
      borderColor: color.withValues(alpha: 0.36),
      borderRadius: BorderRadius.circular(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          if (action == null) return content;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              content,
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: action,
                  child: Text(actionLabel ?? 'Reconectar'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
