import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/settings/controller/app_settings.dart';
import '../../features/settings/controller/settings_controller.dart';
import 'blanquita/blanquita_brand.dart';

import '../../app/design/blanquita_design.dart';

class AppBackground extends StatefulWidget {
  const AppBackground({super.key, required this.child, this.scene = 0});
  final int scene;

  final Widget child;

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rain = AnimationController(
    vsync: this,
    duration: BlanquitaMotion.ambient,
  );
  bool _enabled = false;
  BlanquitaVisualTheme? _visualTheme;
  @override
  void didUpdateWidget(AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_enabled && oldWidget.scene != widget.scene) _rain.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsController?>()?.settings;
    final enabled =
        settings != null &&
        settings.visualTheme != BlanquitaVisualTheme.original &&
        !BlanquitaDesign.reduce(context, settings);
    if (enabled != _enabled || _visualTheme != settings?.visualTheme) {
      _visualTheme = settings?.visualTheme;
      _enabled = enabled;
      if (enabled) {
        _rain.repeat();
      } else {
        _rain.stop();
        _rain.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _rain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlanquitaColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warm =
        (context.watch<SettingsController?>()?.settings.visualTheme ??
            BlanquitaVisualTheme.original) !=
        BlanquitaVisualTheme.original;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.canvas,
        gradient: RadialGradient(
          center: warm
              ? const Alignment(0, -.15)
              : const Alignment(0.72, -0.78),
          radius: warm ? .9 : 1.15,
          colors: [
            warm
                ? colors.graphiteRaised.withValues(alpha: .6)
                : colors.graphiteRaised,
            colors.canvas,
          ],
          stops: const [0, 0.72],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _IndustrialBackdropPainter(
                isDark: isDark,
                colors: colors,
              ),
            ),
          ),
          Positioned(
            top: -160,
            right: -120,
            child: _GlowOrb(
              size: 360,
              color: colors.cyan.withValues(alpha: isDark ? 0.075 : 0.12),
            ),
          ),
          if (warm)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: isDark ? .48 : .12,
                          child: Image.asset(
                            'assets/alfresi/fondo_hamburguesa.png',
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colors.canvas.withValues(alpha: .1),
                                colors.canvas.withValues(alpha: .35),
                                colors.canvas.withValues(alpha: .12),
                              ],
                            ),
                          ),
                        ),
                        CustomPaint(
                          painter: _BurgerRainPainter(_rain, colors.cyan),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 1],
        ),
      ),
    ),
  );
}

class _IndustrialBackdropPainter extends CustomPainter {
  const _IndustrialBackdropPainter({
    required this.isDark,
    required this.colors,
  });

  final bool isDark;
  final BlanquitaColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = (isDark ? colors.coldWhite : const Color(0xFF17343D))
          .withValues(alpha: isDark ? 0.022 : 0.035)
      ..strokeWidth = 0.7;
    const step = 38.0;
    for (double x = 18; x < size.width; x += step) {
      for (double y = 22; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.7, line);
      }
    }

    final rail = Paint()
      ..color = colors.cyan.withValues(alpha: isDark ? 0.025 : 0.04)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.78, 0),
      Offset(size.width * 0.78, size.height),
      rail,
    );
  }

  @override
  bool shouldRepaint(covariant _IndustrialBackdropPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.colors != colors;
}

/// Decorative, deterministic rainfall. Only the painter repaints each frame.
/// It never creates timers, input targets, or any connection state.
class _BurgerRainPainter extends CustomPainter {
  _BurgerRainPainter(this.animation, this.accent) : super(repaint: animation);
  final Animation<double> animation;
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    for (var i = 0; i < 16; i++) {
      final fraction = ((i * 0.61803398875) % 1);
      final x =
          (i.isEven ? .06 : .84) * size.width +
          math.sin(i * 2.4 + t * math.pi * 2) * size.width * .08;
      final y = ((fraction + t) % 1) * size.height;
      final extent = 14.0 + (i % 3) * 5;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(i + t * math.pi * 2) * .28);
      const BurgerMarkPainter(opacity: .16).paint(canvas, Size.square(extent));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurgerRainPainter old) =>
      old.accent != accent || old.animation != animation;
}
