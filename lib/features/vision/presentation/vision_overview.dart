import '../../settings/controller/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../../core/diagnostics/connection_log.dart';
import '../../assistant/presentation/alfresi_bubble.dart';
import '../../assistant/domain/alfresi_message.dart';
import '../../../shared/widgets/blanquita/blanquita_scaffold.dart';
import '../../../shared/widgets/blanquita/blanquita_components.dart';
import '../controller/vision_controller.dart';
import 'vision_widgets.dart';

class VisionOverview extends StatelessWidget {
  const VisionOverview({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VisionController>();
    final s = controller.state;
    final report = s.lastReport;
    final settings = context.watch<SettingsController>().settings;
    final lowConfidence =
        report?.confidence != null &&
        report!.confidence! < settings.visionMinimumConfidence;
    return BlanquitaScaffold(
      title: 'Visión',
      children: [
        if (settings.assistantEnabled && settings.assistantTips)
          AlfresiBubble(
            message: s.error != null
                ? redactConnectionText(s.error!)
                : s.stale
                ? 'No hay heartbeat reciente de visión.'
                : s.ready
                ? 'Visión lista para operar.'
                : 'La laptop aún no confirmó visión disponible.',
            mood: s.error != null
                ? AlfresiMood.error
                : s.ready
                ? AlfresiMood.success
                : AlfresiMood.thinking,
          ),
        const SizedBox(height: BlanquitaSpacing.sm),
        BlanquitaStatus(
          label: 'Laptop · ${visionConnectionLabel(s)}',
          color: s.ready
              ? BlanquitaColors.of(context).mint
              : BlanquitaColors.of(context).warning,
          icon: s.ready ? Icons.check_circle_outline : Icons.link_off,
        ),
        const SizedBox(height: BlanquitaSpacing.lg),
        BlanquitaCard(
          child: Column(
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 40,
                color: BlanquitaColors.of(context).steel,
              ),
              const SizedBox(height: 12),
              const Text('Sin vista de cámara'),
              const SizedBox(height: 4),
              Text(
                'Este servidor entrega estados y reportes.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        VisionReadouts(
          title: 'Sistema de percepción',
          rows: {
            'Cámara': s.cameraName ?? 'No disponible',
            'Estado de cámara': visionStatusLabel(s.cameraStatus),
            'Detector': visionStatusLabel(s.detectorStatus),
            'Calibración': visionStatusLabel(s.calibrationStatus),
            'FPS': s.fps?.toStringAsFixed(1) ?? '—',
            'Latencia': s.latency == null
                ? '—'
                : '${s.latency!.toStringAsFixed(1)} ms',
          },
        ),
        const SizedBox(height: 12),
        if (report == null)
          const BlanquitaCard(
            child: Column(
              children: [
                Text('Sin datos de visión'),
                SizedBox(height: 8),
                Text(
                  'Los resultados aparecerán cuando la laptop envíe reportes.',
                ),
              ],
            ),
          ),
        if (report != null)
          VisionReadouts(
            title: 'Último reporte',
            rows: {
              'Detección': report.detected == null
                  ? 'No informada'
                  : report.detected!
                  ? 'Objeto detectado'
                  : 'Sin detección',
              'Objeto': report.object ?? '—',
              'X': s.position?.x?.toStringAsFixed(2) ?? '—',
              'Z': s.position?.z?.toStringAsFixed(2) ?? '—',
              'Confianza': report.confidence == null
                  ? '—'
                  : '${(report.confidence! * 100).toStringAsFixed(1)} %',
              'Última actualización': visionTime(report.timestamp),
              'Edad del reporte': visionAge(s.reportAge),
              'Vigencia': s.reportStale || !s.isConnected
                  ? 'Reporte caducado'
                  : 'Reciente',
            },
          ),
        const SizedBox(height: 12),
        ExpansionTile(
          title: const Text('Conexión y acciones'),
          initiallyExpanded: false,
          children: [
            Text(
              redactConnectionText(controller.endpoint),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: controller.isConnecting
                      ? null
                      : s.isConnected
                      ? controller.reconnect
                      : controller.connect,
                  child: Text(s.isConnected ? 'Reconectar' : 'Conectar'),
                ),
                TextButton(
                  onPressed: s.isConnected || controller.isConnecting
                      ? controller.disconnect
                      : null,
                  child: const Text('Desconectar'),
                ),
                TextButton(
                  onPressed: s.ready ? controller.start : null,
                  child: const Text('Iniciar visor'),
                ),
                TextButton(
                  onPressed: s.isConnected ? controller.stop : null,
                  child: const Text('Detener visor'),
                ),
                IconButton(
                  tooltip: 'Ping de visión',
                  onPressed: s.isConnected ? controller.ping : null,
                  icon: const Icon(Icons.network_ping),
                ),
              ],
            ),
          ],
        ),
        if (s.error != null ||
            s.stale ||
            s.reportStale ||
            s.alerts.isNotEmpty ||
            lowConfidence)
          ExpansionTile(
            title: const Text('Alertas'),
            initiallyExpanded: true,
            children: [
              if (lowConfidence)
                const Text('Confianza inferior al mínimo configurado.'),
              if (s.stale) const Text('Sin heartbeat reciente del visor.'),
              if (s.reportStale) const Text('El último reporte ha caducado.'),
              if (s.error != null) Text(redactConnectionText(s.error!)),
              for (final alert in s.alerts) Text(redactConnectionText(alert)),
            ],
          ),
      ],
    );
  }
}
