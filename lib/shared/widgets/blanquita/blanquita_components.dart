import 'package:flutter/material.dart';
import '../../../app/design/blanquita_design.dart';
import '../glass_surface.dart';

class BlanquitaCard extends GlassPanel {
  const BlanquitaCard({
    super.key,
    required super.child,
    super.padding,
    super.borderColor,
  });
}

class BlanquitaButton extends StatelessWidget {
  const BlanquitaButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}

class BlanquitaStatus extends StatelessWidget {
  const BlanquitaStatus({
    super.key,
    required this.label,
    required this.color,
    this.icon = Icons.circle,
  });
  final String label;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Icon(icon, size: 16, color: color),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ],
    ),
  );
}

class BlanquitaDeviceCard extends StatelessWidget {
  const BlanquitaDeviceCard({
    super.key,
    required this.name,
    required this.status,
    required this.ready,
    required this.icon,
  });
  final String name, status;
  final bool ready;
  final IconData icon;
  @override
  Widget build(BuildContext context) => BlanquitaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: BlanquitaDesign.gap),
        Text(name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        BlanquitaStatus(
          label: status,
          color: ready
              ? BlanquitaColors.of(context).mint
              : BlanquitaColors.of(context).warning,
          icon: ready ? Icons.check_circle_outline : Icons.link_off,
        ),
      ],
    ),
  );
}

class BlanquitaSection extends StatelessWidget {
  const BlanquitaSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      child,
    ],
  );
}

class BlanquitaSegmentedControl<T> extends StatelessWidget {
  const BlanquitaSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in options.entries)
        ChoiceChip(
          label: Text(entry.value),
          selected: value == entry.key,
          onSelected: (_) => onChanged(entry.key),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
    ],
  );
}
