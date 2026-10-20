import 'package:flutter/material.dart';
import '../../app/design/blanquita_design.dart';

/// Existing destination indices remain stable; Devices is an additional UI view.
class BlanquitaBottomNavigation extends StatelessWidget {
  const BlanquitaBottomNavigation({
    super.key,
    required this.index,
    required this.onSelected,
  });
  final int index;
  final ValueChanged<int> onSelected;
  static const items = [
    (0, 'Inicio', Icons.home_outlined),
    (4, 'Dispositivos', Icons.devices_other_outlined),
    (1, 'Control', Icons.control_camera_outlined),
    (2, 'Visión', Icons.visibility_outlined),
    (3, 'Ajustes', Icons.tune_rounded),
  ];
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: BlanquitaColors.of(context).canvas,
      border: Border(
        top: BorderSide(
          color: BlanquitaColors.of(context).cyanDeep.withValues(alpha: .3),
        ),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (id, label, icon) in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: id == index,
                label: label,
                child: Tooltip(
                  message: label,
                  child: InkWell(
                    key: ValueKey('nav-$label'),
                    onTap: () => onSelected(id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 2,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 22,
                            color: id == index
                                ? BlanquitaColors.of(context).cyan
                                : BlanquitaColors.of(context).steel,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 10,
                                  color: id == index
                                      ? BlanquitaColors.of(context).cyan
                                      : BlanquitaColors.of(context).steel,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: 2,
                            width: 18,
                            color: id == index
                                ? BlanquitaColors.of(context).cyan
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
