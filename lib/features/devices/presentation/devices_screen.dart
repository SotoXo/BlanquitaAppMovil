import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../../app/presentation/controller_ui_context.dart';
import '../../../core/diagnostics/connection_log.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../settings/controller/settings_controller.dart';
import '../../settings/presentation/esp32_identity_panel.dart';
import '../../vision/controller/vision_controller.dart';
import '../../assistant/presentation/alfresi_avatar.dart';
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
    final settings = context.watch<SettingsController>().settings;
    final searching = machine.isDiscovering || vision.isDiscovering;
    return BlanquitaScaffold(
      title: 'Dispositivos',
      children: [
        if (settings.assistantEnabled && settings.assistantTips)
          AlfresiBubble(
            message: machine.isConnecting || machine.isDiscovering
                ? machine.progressMessage
                : vision.isConnecting || vision.isDiscovering
                ? vision.progressMessage
                : machine.lastError != null
                ? redactConnectionText(machine.lastError!)
                : vision.state.error != null
                ? redactConnectionText(vision.state.error!)
                : 'Revisa los dispositivos encontrados y selecciona su identidad.',
            mood: searching || machine.isConnecting || vision.isConnecting
                ? AlfresiMood.thinking
                : machine.lastError != null || vision.state.error != null
                ? AlfresiMood.error
                : AlfresiMood.idle,
          ),
        const SizedBox(height: BlanquitaSpacing.lg),
        BlanquitaCard(
          child: Column(
            children: [
              SizedBox(
                height: 190,
                child: DeviceRadar(
                  searching: searching,
                  found:
                      machine.devices.length +
                      (vision.detectedAddress == null ? 0 : 1),
                ),
              ),
              Text(
                searching ? 'Búsqueda en curso' : 'Red local',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: machine.isConnecting
                        ? null
                        : machine.searchEsp32,
                    icon: const Icon(Icons.radar),
                    label: const Text('Buscar ESP32'),
                  ),
                  OutlinedButton.icon(
                    onPressed: vision.isConnecting ? null : vision.searchVision,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Buscar visión'),
                  ),
                  if (machine.isDiscovering)
                    TextButton(
                      onPressed: machine.cancelSearch,
                      child: const Text('Cancelar búsqueda'),
                    ),
                  if (vision.isDiscovering)
                    TextButton(
                      onPressed: vision.disconnect,
                      child: const Text('Cancelar búsqueda de visión'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: BlanquitaSpacing.lg),
        Text(
          'Dispositivos ESP32 encontrados (${machine.devices.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: BlanquitaSpacing.sm),
        if (machine.devices.isEmpty)
          const BlanquitaCard(
            child: Text(
              'Todavía no hay candidatos. Puedes buscar en la red o revisar la identidad guardada.',
            ),
          ),
        for (final device in machine.devices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BlanquitaCard(
              borderColor: machine.selectedDevice?.deviceId == device.deviceId
                  ? BlanquitaColors.of(context).cyan
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.memory_outlined,
                        color: BlanquitaColors.of(context).cyan,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          device.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(device.deviceId),
                  Text(
                    '${device.ip}:${device.port} · ${device.connection.label}',
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: machine.isConnecting
                        ? null
                        : () async {
                            await machine.selectDevice(device);
                            if (context.mounted) {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const BindingScreen(),
                                ),
                              );
                            }
                          },
                    child: const Text('Seleccionar'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        BlanquitaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ESP32 actual',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(machine.authenticationLabel),
              Text(
                redactConnectionText(
                  machine.connectionWebsocketUrl ?? 'Sin dirección guardada',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const BindingScreen(),
                  ),
                ),
                child: const Text('Ver vinculación'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BlanquitaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Visión · laptop',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(vision.state.ready ? 'Ready' : vision.discoveryStatusLabel),
              if (vision.detectedAddress != null)
                Text('${vision.detectedAddress}:${vision.detectedPort ?? '—'}'),
              Text(
                redactConnectionText(
                  vision.connectionWebsocketUrl ??
                      (vision.endpoint.isEmpty
                          ? 'Sin dirección guardada'
                          : vision.endpoint),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Animation only reflects the existing discovery flags; markers count real results.
class DeviceRadar extends StatefulWidget {
  const DeviceRadar({super.key, required this.searching, required this.found});
  final bool searching;
  final int found;
  @override
  State<DeviceRadar> createState() => _DeviceRadarState();
}

class _DeviceRadarState extends State<DeviceRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController scan = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  void update() {
    final reduce = BlanquitaDesign.reduce(
      context,
      context.read<SettingsController>().settings,
    );
    if (widget.searching && !reduce) {
      if (!scan.isAnimating) scan.repeat();
    } else {
      scan.stop();
      scan.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.watch<SettingsController>();
    update();
  }

  @override
  void didUpdateWidget(DeviceRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    update();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: DeviceRadarPainter(scan, widget.found),
      child: Center(
        child: context.watch<SettingsController>().settings.assistantEnabled
            ? AlfresiAvatar(
                size: AlfresiSizes.l,
                mood: widget.searching
                    ? AlfresiMood.thinking
                    : AlfresiMood.idle,
              )
            : const Icon(Icons.router_outlined, size: 48),
      ),
    ),
  );
  @override
  void dispose() {
    scan.dispose();
    super.dispose();
  }
}

class DeviceRadarPainter extends CustomPainter {
  DeviceRadarPainter(this.scan, this.found) : super(repaint: scan);
  final Animation<double> scan;
  final int found;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2),
        radius = size.shortestSide * .44;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = BlanquitaColors.info.withValues(alpha: .5);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, p);
    }
    canvas.drawLine(center - Offset(radius, 0), center + Offset(radius, 0), p);
    canvas.drawLine(center - Offset(0, radius), center + Offset(0, radius), p);
    if (scan.value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        scan.value * math.pi * 2,
        .55,
        true,
        Paint()..color = BlanquitaColors.info.withValues(alpha: .12),
      );
    }
    for (var i = 0; i < found; i++) {
      final angle = i * 2.4;
      final d = radius * (.5 + (i % 3) * .15);
      canvas.drawCircle(
        center + Offset(math.cos(angle) * d, math.sin(angle) * d),
        3,
        Paint()..color = BlanquitaColors.success,
      );
    }
  }

  @override
  bool shouldRepaint(DeviceRadarPainter old) =>
      old.found != found || old.scan != scan;
}

class BindingScreen extends StatelessWidget {
  const BindingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final machine = context.watch<MachineController>();
    final settings = context.watch<SettingsController>().settings;
    return BlanquitaScaffold(
      title: 'Vinculación',
      back: true,
      children: [
        if (settings.assistantEnabled && settings.assistantTips)
          AlfresiBubble(
            message: machine.hasValidConnection
                ? machine.authenticationLabel
                : machine.lastError ??
                      'Estado actual: ${machine.linkPhase.label}.',
            mood: machine.lastError != null
                ? AlfresiMood.error
                : machine.hasValidConnection
                ? AlfresiMood.success
                : machine.isConnecting
                ? AlfresiMood.thinking
                : AlfresiMood.warning,
          ),
        const SizedBox(height: BlanquitaSpacing.xl),
        BlanquitaTimeline(
          transportOpen: machine.transportOpen,
          ready: machine.hasValidConnection,
          connecting: machine.isConnecting,
          phase: machine.phase,
          linkPhase: machine.linkPhase,
        ),
        const SizedBox(height: BlanquitaSpacing.lg),
        const BlanquitaCard(child: Esp32IdentityPanel()),
      ],
    );
  }
}
