import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../core/models/machine_state.dart';
import '../../features/settings/controller/settings_controller.dart';
import 'page_header.dart';

/// Shared by the manual console and diagnostics so both report the same truth.
class FinalLimitsPanel extends StatelessWidget {
  const FinalLimitsPanel({
    super.key,
    required this.limits,
    this.awaitingRelease = false,
  });

  final FinalLimitsState limits;
  final bool awaitingRelease;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final duration = settings.reduceMotion || settings.performanceMode
        ? Duration.zero
        : const Duration(milliseconds: 155);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Finales de carrera'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520
                ? 4
                : constraints.maxWidth >= 220
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final limit in FinalLimit.values)
                  SizedBox(
                    width: width,
                    child: _indicator(context, limit, duration),
                  ),
              ],
            );
          },
        ),
        if (!limits.isComplete)
          _notice(
            context,
            'Sin datos completos de los cuatro finales. Movimiento deshabilitado hasta recibir nuevas lecturas.',
            AppColors.steel,
          ),
        if (limits.xFault)
          _notice(
            context,
            'Fallo de sensores del eje X: ambos extremos activados. Eje X bloqueado; revisa los finales y su cableado.',
            AppColors.danger,
          ),
        if (limits.zFault)
          _notice(
            context,
            'Fallo de sensores del eje Z: ambos extremos activados. Eje Z bloqueado; revisa los finales y su cableado.',
            AppColors.danger,
          ),
        for (final limit in FinalLimit.values)
          if (limits[limit] == LimitSwitchStatus.active &&
              !limits.axisFault(limit.direction))
            _notice(context, limit.retreatMessage, AppColors.danger),
        if (awaitingRelease)
          _notice(
            context,
            'Suelta el botón antes de iniciar otro movimiento.',
            AppColors.warning,
          ),
      ],
    );
  }

  Widget _indicator(BuildContext context, FinalLimit limit, Duration duration) {
    final status = limits[limit];
    final color = switch (status) {
      LimitSwitchStatus.free => AppColors.mint,
      LimitSwitchStatus.active => AppColors.danger,
      LimitSwitchStatus.unknown => AppColors.steel,
    };
    return Semantics(
      label: '${limit.label}: ${status.label}',
      excludeSemantics: true,
      child: AnimatedContainer(
        key: ValueKey('sensor-${limit.protocolName}'),
        duration: duration,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Icon(
              status == LimitSwitchStatus.active
                  ? Icons.lock_rounded
                  : Icons.circle,
              size: status == LimitSwitchStatus.active ? 13 : 7,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    limit.label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(BuildContext context, String message, Color color) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: color, height: 1.45),
    ),
  );
}
