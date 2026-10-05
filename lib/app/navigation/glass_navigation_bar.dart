import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/settings/controller/settings_controller.dart';
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
    (icon: CupertinoIcons.square_grid_2x2, label: 'Inicio'),
    (icon: CupertinoIcons.game_controller, label: 'Control'),
    (icon: CupertinoIcons.viewfinder, label: 'Visión'),
    (icon: CupertinoIcons.slider_horizontal_3, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final reduceMotion =
        settings.reduceMotion ||
        settings.performanceMode ||
        MediaQuery.disableAnimationsOf(context);
    final indicatorDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 380);
    final contentDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return RepaintBoundary(
      child: GlassSurface(
        blur: true,
        emphasis: GlassEmphasis.prominent,
        borderRadius: BorderRadius.circular(27),
        padding: const EdgeInsets.all(5),
        child: SizedBox(
          height: 62,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _items.length;
              return Stack(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: index.toDouble()),
                    duration: indicatorDuration,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Transform.translate(
                      offset: Offset(itemWidth * value, 0),
                      child: SizedBox(
                        width: itemWidth,
                        height: 62,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.cyan.withValues(alpha: 0.22),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.cyan.withValues(
                                    alpha: 0.055,
                                  ),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(_items.length, (itemIndex) {
                      final item = _items[itemIndex];
                      final selected = itemIndex == index;
                      return Expanded(
                        child: Semantics(
                          button: true,
                          selected: selected,
                          label: item.label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => onSelected(itemIndex),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedScale(
                                  scale: selected ? 1.05 : 0.94,
                                  duration: contentDuration,
                                  curve: Curves.easeOutCubic,
                                  child: Icon(
                                    item.icon,
                                    size: 20,
                                    color: selected
                                        ? AppColors.cyan
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.40),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                AnimatedDefaultTextStyle(
                                  duration: contentDuration,
                                  style:
                                      Theme.of(
                                        context,
                                      ).textTheme.labelSmall?.copyWith(
                                        color: selected
                                            ? AppColors.cyan
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.43),
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ) ??
                                      const TextStyle(),
                                  child: Text(item.label),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
