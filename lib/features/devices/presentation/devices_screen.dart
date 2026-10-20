import '../../settings/controller/settings_controller.dart';
import '../../assistant/presentation/alfresi_avatar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../../core/diagnostics/connection_log.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../vision/controller/vision_controller.dart';
import '../../assistant/presentation/alfresi_bubble.dart';
import '../../assistant/domain/alfresi_message.dart';
import '../../../shared/widgets/blanquita/blanquita_scaffold.dart';
import '../../../shared/widgets/blanquita/blanquita_components.dart';
import '../../../shared/widgets/blanquita/blanquita_timeline.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final machine = context.watch<MachineController>();
    final vision = context.watch<VisionController>();
    final endpoints = [
      ('ESP32', machine.connectionWebsocketUrl ?? '', machine.protocolReady),
      ('Visión · laptop', vision.endpoint, vision.state.ready),
    ];
    final count = endpoints.where((e) => e.$2.isNotEmpty).length;
    return BlanquitaScaffold(
      title: 'Dispositivos',
      children: [
        if (context.watch<SettingsController>().settings.assistantEnabled &&
            context.watch<SettingsController>().settings.assistantTips)
          const AlfresiBubble(
            message:
                'Aquí puedes revisar los equipos configurados y su conexión.',
            mood: AlfresiMood.thinking,
          ),
        const SizedBox(height: BlanquitaSpacing.lg),
        BlanquitaCard(
          child: Column(
            children: [
              const SizedBox(
                height: 190,
                child: CustomPaint(
                  painter: DeviceRadarPainter(),
                  child: Center(
                    child: AlfresiAvatar(
                      size: AlfresiSizes.l,
                      mood: AlfresiMood.thinking,
                    ),
                  ),
                ),
              ),
              Text(
                'Descubrimiento no disponible',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Esta versión utiliza las direcciones guardadas.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: BlanquitaSpacing.lg),
        Text(
          'Equipos configurados ($count)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: BlanquitaSpacing.sm),
        for (final (name, endpoint, ready) in endpoints) ...[
          BlanquitaCard(
            padding: BlanquitaSpacing.compact,
            borderColor: ready
                ? BlanquitaColors.of(context).mint.withValues(alpha: .5)
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  name == 'ESP32'
                      ? Icons.memory_outlined
                      : Icons.visibility_outlined,
                  color: ready
                      ? BlanquitaColors.of(context).mint
                      : BlanquitaColors.of(context).steel,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        endpoint.isEmpty
                            ? 'Sin dirección guardada'
                            : redactConnectionText(endpoint),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ready
                            ? 'Conectado · READY confirmado'
                            : 'Sin conexión confirmada',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (name == 'ESP32')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BindingScreen(),
                              ),
                            ),
                            child: const Text('Ver vinculación'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BlanquitaSpacing.md),
        ],
      ],
    );
  }
}

/// A static network diagram: no animation, search or invented result dots.
class DeviceRadarPainter extends CustomPainter {
  const DeviceRadarPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .44;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = BlanquitaColors.info.withValues(alpha: .5);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, p);
    }
    canvas.drawLine(center - Offset(radius, 0), center + Offset(radius, 0), p);
    canvas.drawLine(center - Offset(0, radius), center + Offset(0, radius), p);
    canvas.drawCircle(center, 5, Paint()..color = BlanquitaColors.creamMuted);
  }

  @override
  bool shouldRepaint(DeviceRadarPainter oldDelegate) => false;
}

class BindingScreen extends StatelessWidget {
  const BindingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final machine = context.watch<MachineController>();
    return BlanquitaScaffold(
      title: 'Vinculación',
      back: true,
      children: [
        if (context.watch<SettingsController>().settings.assistantEnabled &&
            context.watch<SettingsController>().settings.assistantTips)
          AlfresiBubble(
            message: machine.protocolReady
                ? 'El ESP32 confirmó READY. La conexión está disponible.'
                : machine.transportOpen
                ? 'El dispositivo respondió. Estamos esperando READY.'
                : 'El ESP32 todavía no confirmó la conexión.',
            mood: machine.protocolReady
                ? AlfresiMood.success
                : AlfresiMood.thinking,
          ),
        const SizedBox(height: BlanquitaSpacing.xl),
        BlanquitaTimeline(
          transportOpen: machine.transportOpen,
          ready: machine.protocolReady,
          connecting: machine.isConnecting,
          phase: machine.phase,
        ),
        const SizedBox(height: BlanquitaSpacing.lg),
        BlanquitaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Detalles de conexión',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text('Dirección', style: Theme.of(context).textTheme.bodySmall),
              Text(
                redactConnectionText(
                  machine.connectionWebsocketUrl ?? 'Sin configurar',
                ),
              ),
              const SizedBox(height: 12),
              Text(redactConnectionText(machine.state.lastStatus)),
            ],
          ),
        ),
      ],
    );
  }
}
