import 'vision_overview.dart';
import '../../settings/controller/app_settings.dart';
import '../../../core/diagnostics/connection_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/design/blanquita_design.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/motion_reveal.dart';
import '../../../shared/widgets/page_header.dart';
import '../../settings/controller/settings_controller.dart';
import '../controller/vision_controller.dart';
import 'vision_widgets.dart';

class VisionScreen extends StatelessWidget {
  const VisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VisionController>();
    final state = controller.state;
    final report = state.lastReport;
    final settings = context.watch<SettingsController>().settings;
    final color = state.stale || state.error != null
        ? BlanquitaColors.of(context).warning
        : state.ready
        ? BlanquitaColors.of(context).mint
        : BlanquitaColors.of(context).steel;
    final lowConfidence =
        report?.confidence != null &&
        report!.confidence! < settings.visionMinimumConfidence;
    if (settings.visualTheme != BlanquitaVisualTheme.original) {
      return const VisionOverview();
    }
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 126),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MotionReveal(
                  child: PageHeader(
                    eyebrow: 'Monitor remoto',
                    title: 'Visión · laptop',
                    subtitle: 'Conexión, sistema y reportes recibidos.',
                  ),
                ),
                const SizedBox(height: 18),
                MotionReveal(
                  child: GlassPanel(
                    emphasis: GlassEmphasis.prominent,
                    borderColor: color.withValues(alpha: 0.25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.desktopcomputer,
                              color: color,
                              size: 29,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Laptop · ${visionConnectionLabel(state)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    state.ready
                                        ? 'Vision Server · Ready'
                                        : 'Vision Server · No disponible',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: color),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          controller.endpoint.isEmpty
                              ? 'Configura la URL del Vision Server en Ajustes.'
                              : redactConnectionText(controller.endpoint),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            GlassButton(
                              onPressed: controller.isConnecting
                                  ? null
                                  : state.isConnected
                                  ? controller.reconnect
                                  : controller.connect,
                              child: Text(
                                state.isConnected ? 'Reconectar' : 'Conectar',
                              ),
                            ),
                            GlassButton(
                              onPressed:
                                  state.isConnected || controller.isConnecting
                                  ? controller.disconnect
                                  : null,
                              child: const Text('Desconectar'),
                            ),
                            GlassButton(
                              onPressed: state.ready ? controller.start : null,
                              child: const Text('Iniciar visor'),
                            ),
                            GlassButton(
                              onPressed: state.isConnected
                                  ? controller.stop
                                  : null,
                              child: const Text('Detener visor'),
                            ),
                            IconButton(
                              tooltip: 'Ping de visión',
                              onPressed: state.isConnected
                                  ? controller.ping
                                  : null,
                              icon: const Icon(
                                CupertinoIcons.waveform_path_ecg,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                VisionReadouts(
                  title: 'Sistema de percepción',
                  rows: {
                    'Cámara': state.cameraName ?? 'No disponible',
                    'Estado de cámara': visionStatusLabel(state.cameraStatus),
                    'Calibración': visionStatusLabel(state.calibrationStatus),
                    'Detector': visionStatusLabel(state.detectorStatus),
                    'FPS': state.fps?.toStringAsFixed(1) ?? '—',
                    'Latencia': state.latency == null
                        ? '—'
                        : '${state.latency!.toStringAsFixed(1)} ms',
                  },
                ),
                const SizedBox(height: 22),
                const SectionLabel('Último reporte'),
                const SizedBox(height: 10),
                if (report == null)
                  GlassPanel(
                    emphasis: GlassEmphasis.quiet,
                    child: Column(
                      children: [
                        Icon(
                          CupertinoIcons.viewfinder,
                          size: 32,
                          color: BlanquitaColors.of(context).steel,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sin datos de visión',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Los resultados aparecerán cuando la laptop envíe reportes.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  VisionReadouts(
                    rows: {
                      'Detección': report.detected == null
                          ? 'No informada'
                          : report.detected!
                          ? 'Objeto detectado'
                          : 'Sin detección',
                      'Objeto': report.object ?? '—',
                      'X': state.position?.x?.toStringAsFixed(2) ?? '—',
                      'Z': state.position?.z?.toStringAsFixed(2) ?? '—',
                      'Confianza': report.confidence == null
                          ? '—'
                          : '${(report.confidence! * 100).toStringAsFixed(1)} %',
                      'Última actualización': visionTime(report.timestamp),
                      'Edad del reporte': visionAge(state.reportAge),
                      'Vigencia': state.reportStale || !state.isConnected
                          ? 'Reporte caducado'
                          : 'Reciente',
                    },
                  ),
                if (state.stale ||
                    state.reportStale ||
                    lowConfidence ||
                    state.error != null ||
                    state.alerts.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const SectionLabel('Alertas'),
                  const SizedBox(height: 10),
                  GlassPanel(
                    borderColor: BlanquitaColors.of(
                      context,
                    ).warning.withValues(alpha: 0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.stale)
                          const Text('Sin heartbeat reciente del visor.'),
                        if (state.reportStale)
                          const Text('El último reporte ha caducado.'),
                        if (lowConfidence)
                          const Text(
                            'Confianza inferior al mínimo configurado.',
                          ),
                        if (state.error != null) Text(state.error!),
                        for (final alert in state.alerts) Text(alert),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
