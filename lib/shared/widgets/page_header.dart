import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 7),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.62),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 14), trailing!],
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.8,
          fontWeight: FontWeight.w800,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.52),
        ),
      ),
      if (trailing != null) ...[const Spacer(), trailing!],
    ],
  );
}
