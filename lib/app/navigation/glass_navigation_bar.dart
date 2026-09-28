import 'package:flutter/material.dart';

import '../../shared/widgets/glass_surface.dart';

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.index,
    required this.onSelected,
  });

  final int index;
  final ValueChanged<int> onSelected;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.space_dashboard_rounded, label: 'Inicio'),
    (icon: Icons.gamepad_rounded, label: 'Control'),
    (icon: Icons.center_focus_strong_rounded, label: 'Visión'),
    (icon: Icons.tune_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(6),
        child: Row(
          children: List.generate(_items.length, (itemIndex) {
            final item = _items[itemIndex];
            final selected = itemIndex == index;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onSelected(itemIndex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      border: selected
                          ? Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.26),
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 21,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.48),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.50),
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
