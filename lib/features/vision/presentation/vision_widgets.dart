import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../domain/vision_state.dart';

String visionConnectionLabel(VisionState state) => switch (state.connection) {
  VisionConnection.disconnected => 'Desconectada',
  VisionConnection.connecting => 'Conectando',
  VisionConnection.connected =>
    state.stale ? 'Conectada · sin heartbeat' : 'Conectada',
  VisionConnection.reconnecting => 'Reconectando',
  VisionConnection.error => 'Error de conexión',
};

String visionStatusLabel(String? value) => switch (value) {
  null => 'No disponible',
  'connected' || 'operative' || 'operational' => 'Operativa',
  'disconnected' => 'Desconectada',
  'valid' || 'calibrated' => 'Válida',
  'pending' => 'Pendiente',
  'invalid' => 'Inválida',
  'active' || 'running' => 'Activo',
  'stopped' || 'inactive' => 'Detenido',
  'error' => 'Error',
  'unknown' || 'unavailable' => 'No disponible',
  _ => value,
};

String visionTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
}

String visionAge(Duration? age) =>
    age == null ? '—' : '${(age.inMilliseconds / 1000).toStringAsFixed(1)} s';

class VisionReadouts extends StatelessWidget {
  const VisionReadouts({super.key, required this.rows, this.title});
  final Map<String, String> rows;
  final String? title;

  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
        ],
        for (final entry in rows.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    entry.key,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.steel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
