import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/design/blanquita_design.dart';
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
    if (MediaQuery.textScalerOf(context).scale(12) > 20) {
      return GlassSurface(
        padding: const EdgeInsets.all(6),
        elevation: 0,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                flex: i == index ? 3 : 1,
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: _items[i].label,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: _items[i].label,
                    child: InkWell(
                      key: ValueKey('nav-${_items[i].label}'),
                      onTap: () => onSelected(i),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: contentDuration,
                        constraints: const BoxConstraints(minHeight: 64),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: i == index
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: .15)
                              : Colors.transparent,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _items[i].icon,
                              size: 22,
                              color: i == index
                                  ? Theme.of(context).colorScheme.primary
                                  : BlanquitaColors.of(context).steel,
                            ),
                            if (i == index) ...[
                              const SizedBox(height: 6),
                              Text(
                                _items[i].label,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, outer) {
        final available =
            (outer.maxWidth - 10 * BlanquitaDesign.density(settings)) /
            _items.length;
        var labelHeight = 0.0;
        for (final item in _items) {
          final measure = TextPainter(
            text: TextSpan(
              text: item.label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          )..layout(maxWidth: available - 8);
          if (measure.height > labelHeight) labelHeight = measure.height;
          measure.dispose();
        }
        final navHeight = (36 + labelHeight).clamp(62.0, double.infinity);
        return RepaintBoundary(
          child: GlassSurface(
            blur: true,
            emphasis: GlassEmphasis.prominent,
            borderRadius: BorderRadius.circular(27),
            padding: const EdgeInsets.all(5),
            child: SizedBox(
              height: navHeight,
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
                            height: navHeight,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: BlanquitaColors.of(
                                    context,
                                  ).cyan.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: BlanquitaColors.of(
                                      context,
                                    ).cyan.withValues(alpha: 0.22),
                                  ),
                                  boxShadow:
                                      settings.shadowsEnabled &&
                                          !settings.performanceMode
                                      ? [
                                          BoxShadow(
                                            color: BlanquitaColors.of(
                                              context,
                                            ).cyan.withValues(alpha: 0.055),
                                            blurRadius: 18,
                                          ),
                                        ]
                                      : null,
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
                                key: ValueKey('nav-${item.label}'),
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
                                            ? BlanquitaColors.of(context).cyan
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
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
                                                ? BlanquitaColors.of(
                                                    context,
                                                  ).cyan
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.7),
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
      },
    );
  }
}
