import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../features/settings/controller/settings_controller.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/motion_reveal.dart';
import '../../../shared/widgets/page_header.dart';
import '../domain/position_estimate.dart';

class VisionScreen extends StatelessWidget {
  const VisionScreen({super.key, this.position});

  final PositionEstimate? position;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
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
                    eyebrow: 'Próxima etapa',
                    title: 'Visión',
                    subtitle:
                        'Viewport preparado para una fuente de cámara real.',
                  ),
                ),
                const SizedBox(height: 18),
                MotionReveal(
                  delay: const Duration(milliseconds: 65),
                  child: _VisionViewport(
                    cameraName: settings.cameraName,
                    onConfigure: () => _notReady(context),
                  ),
                ),
                const SizedBox(height: 16),
                MotionReveal(
                  delay: const Duration(milliseconds: 120),
                  child: _VisionStateRail(position: position),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Preparación del módulo'),
                const SizedBox(height: 10),
                MotionReveal(
                  delay: const Duration(milliseconds: 175),
                  child: _PipelinePanel(
                    cameraName: settings.cameraName,
                    targetFps: settings.visionTargetFps,
                    onConfigure: () => _notReady(context),
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
        icon: const Icon(CupertinoIcons.camera_viewfinder),
        title: const Text('Cámara no configurada'),
        content: const Text(
          'La selección de cámara se habilitará cuando se defina la fuente real de video y el flujo de calibración.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _VisionViewport extends StatelessWidget {
  const _VisionViewport({required this.cameraName, required this.onConfigure});

  final String cameraName;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.22,
    child: GlassPanel(
      padding: EdgeInsets.zero,
      emphasis: GlassEmphasis.prominent,
      borderRadius: BorderRadius.circular(31),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CameraGridPainter()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cyan.withValues(alpha: 0.085),
                    border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.06),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.video_camera_solid,
                    color: AppColors.cyan,
                    size: 27,
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  'Cámara no configurada',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  'No se capturan ni procesan imágenes',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.48),
                  ),
                ),
                const SizedBox(height: 17),
                GlassButton(
                  color: AppColors.cyan,
                  onPressed: onConfigure,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Configurar cámara'),
                      SizedBox(width: 9),
                      _NestedArrow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: GlassChip(
              color: AppColors.warning,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.circle_fill,
                    size: 6,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Sin señal',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.warning),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 17,
            right: 17,
            child: Text(
              cameraName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NestedArrow extends StatelessWidget {
  const _NestedArrow();

  @override
  Widget build(BuildContext context) => Container(
    width: 27,
    height: 27,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.cyan.withValues(alpha: 0.13),
    ),
    child: const Icon(
      CupertinoIcons.arrow_up_right,
      size: 13,
      color: AppColors.cyan,
    ),
  );
}

class _VisionStateRail extends StatelessWidget {
  const _VisionStateRail({required this.position});

  final PositionEstimate? position;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        icon: CupertinoIcons.location,
        label: 'Posición',
        value: position?.hasPosition == true ? 'Disponible' : 'No disponible',
      ),
      (icon: CupertinoIcons.scope, label: 'Calibración', value: 'Pendiente'),
      (
        icon: CupertinoIcons.waveform_path_ecg,
        label: 'Detector',
        value: 'No configurado',
      ),
    ];
    return GlassPanel(
      padding: EdgeInsets.zero,
      emphasis: GlassEmphasis.quiet,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 590;
          final children = items
              .map(
                (item) => _VisionStateItem(
                  icon: item.icon,
                  label: item.label,
                  value: item.value,
                ),
              )
              .toList();
          if (wide) {
            return Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  Expanded(child: children[i]),
                  if (i != children.length - 1)
                    const _RailDivider(vertical: true),
                ],
              ],
            );
          }
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const _RailDivider(vertical: false),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _VisionStateItem extends StatelessWidget {
  const _VisionStateItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(15),
    child: Row(
      children: [
        Icon(icon, size: 19, color: AppColors.cyan),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.42),
                ),
              ),
              Text(value, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RailDivider extends StatelessWidget {
  const _RailDivider({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) => Container(
    width: vertical ? 1 : null,
    height: vertical ? 38 : 1,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.055),
  );
}

class _PipelinePanel extends StatelessWidget {
  const _PipelinePanel({
    required this.cameraName,
    required this.targetFps,
    required this.onConfigure,
  });

  final String cameraName;
  final int targetFps;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
    child: Column(
      children: [
        _PipelineRow(
          icon: CupertinoIcons.video_camera,
          title: 'Fuente de video',
          value: cameraName,
        ),
        const Divider(height: 22),
        _PipelineRow(
          icon: CupertinoIcons.speedometer,
          title: 'Frecuencia objetivo',
          value: '$targetFps FPS',
        ),
        const Divider(height: 22),
        const _PipelineRow(
          icon: CupertinoIcons.square_grid_3x2,
          title: 'Ruta preparada',
          value: 'Camera → Detector → PositionEstimate',
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onConfigure,
                child: const Text('Seleccionar cámara'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonal(
                onPressed: null,
                child: const Text('Calibrar'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PipelineRow extends StatelessWidget {
  const _PipelineRow({
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
      Icon(icon, size: 18, color: AppColors.steel),
      const SizedBox(width: 11),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.bodySmall),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    ],
  );
}

class _CameraGridPainter extends CustomPainter {
  const _CameraGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.038)
      ..strokeWidth = 0.8;
    const spacing = 34.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final corner = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const length = 24.0;
    const inset = 16.0;
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + length, inset),
      corner,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset, inset + length),
      corner,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset - length, size.height - inset),
      corner,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset, size.height - inset - length),
      corner,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
