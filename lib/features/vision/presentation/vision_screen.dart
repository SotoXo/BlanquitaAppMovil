import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../features/settings/controller/settings_controller.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/page_header.dart';

class VisionScreen extends StatelessWidget {
  const VisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 132),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(
                  eyebrow: 'Módulo futuro',
                  title: 'Visión',
                  subtitle:
                      'La interfaz está preparada para cámara y estimación espacial, sin simular datos.',
                ),
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const CustomPaint(painter: _CameraGridPainter()),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 74,
                                height: 74,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.cyan.withValues(alpha: 0.10),
                                  border: Border.all(
                                    color: AppColors.cyan.withValues(
                                      alpha: 0.32,
                                    ),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.videocam_off_outlined,
                                  color: AppColors.cyan,
                                  size: 31,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Cámara no configurada',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'No se están capturando ni procesando imágenes',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _StatusChip(
                            icon: Icons.circle,
                            label: 'SIN SEÑAL',
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 620;
                    final cards = [
                      const _VisionStatusCard(
                        icon: Icons.my_location_rounded,
                        label: 'POSICIÓN',
                        value: 'No disponible',
                        detail:
                            'X/Z permanecerán vacíos hasta tener calibración real.',
                      ),
                      const _VisionStatusCard(
                        icon: Icons.model_training_outlined,
                        label: 'DETECTOR',
                        value: 'No configurado',
                        detail:
                            'Sin OpenCV, ArUco ni modelo de IA en esta fase.',
                      ),
                    ];
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 14),
                              Expanded(child: cards[1]),
                            ],
                          )
                        : Column(
                            children: [
                              cards[0],
                              const SizedBox(height: 14),
                              cards[1],
                            ],
                          );
                  },
                ),
                const SizedBox(height: 18),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionLabel('Preparación'),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.camera_alt_outlined,
                        title: 'Cámara',
                        value: settings.cameraName,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.speed_rounded,
                        title: 'FPS objetivo',
                        value: '${settings.visionTargetFps} FPS',
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _notReady(context),
                              icon: const Icon(Icons.settings_input_component),
                              label: const Text('Configurar cámara'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: null,
                              icon: const Icon(Icons.grid_4x4_rounded),
                              label: const Text('Calibrar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _notReady(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.construction_rounded),
        title: const Text('Módulo preparado'),
        content: const Text(
          'La conexión de cámara se incorporará cuando se defina la fuente de video y el flujo de calibración.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }
}

class _VisionStatusCard extends StatelessWidget {
  const _VisionStatusCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.cyan),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(child: Text(title)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 8, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    ),
  );
}

class _CameraGridPainter extends CustomPainter {
  const _CameraGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const spacing = 34.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
