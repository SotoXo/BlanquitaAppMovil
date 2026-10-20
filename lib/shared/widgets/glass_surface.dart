import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/design/blanquita_design.dart';
import '../../features/settings/controller/app_settings.dart';
import '../../features/settings/controller/settings_controller.dart';

enum GlassEmphasis { quiet, standard, prominent }

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
    this.tint,
    this.borderColor,
    this.elevation = 1,
    this.blur = false,
    this.emphasis = GlassEmphasis.standard,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color? tint;
  final Color? borderColor;
  final double elevation;
  final bool blur;
  final GlassEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final d = BlanquitaDesign.density(settings);
    final actualRadius = borderRadius * d;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassOn = settings.glassEnabled && !settings.performanceMode;
    final blurOn = glassOn && blur;
    if (settings.visualTheme != BlanquitaVisualTheme.original) {
      final colors = BlanquitaColors.of(context);
      final opacity = !isDark || settings.performanceMode
          ? BlanquitaOpacity.critical
          : emphasis == GlassEmphasis.prominent
          ? BlanquitaOpacity.raised
          : BlanquitaOpacity.surface;
      final densityRadius = BorderRadius.circular(
        (elevation == 0
                ? BlanquitaRadius.small
                : emphasis == GlassEmphasis.prominent
                ? BlanquitaRadius.hero
                : BlanquitaRadius.standard) *
            d,
      );
      Widget content = Material(
        type: MaterialType.transparency,
        child: Padding(padding: (padding ?? EdgeInsets.zero) * d, child: child),
      );
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint == null
                ? Colors.transparent
                : Color.alphaBlend(
                    tint!,
                    colors.graphite,
                  ).withValues(alpha: BlanquitaOpacity.critical),
            gradient: tint == null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      emphasis == GlassEmphasis.prominent
                          ? colors.graphiteRaised.withValues(alpha: opacity)
                          : colors.graphite.withValues(alpha: opacity),
                      colors.graphite.withValues(alpha: opacity),
                    ],
                    stops: const [0, .8],
                  )
                : null,
            borderRadius: densityRadius,
            border: Border.all(
              color: borderColor ?? colors.cyanDeep.withValues(alpha: .28),
            ),
            boxShadow:
                settings.shadowsEnabled &&
                    !settings.performanceMode &&
                    elevation > 0
                ? [
                    BoxShadow(
                      color: colors.canvas.withValues(alpha: .3),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(borderRadius: densityRadius, child: content),
        ),
      );
    }
    final sigma = switch (settings.glassIntensity) {
      GlassIntensity.low => 6.0,
      GlassIntensity.medium => 10.0,
      GlassIntensity.high => 14.0,
    };
    final alpha = switch (emphasis) {
      GlassEmphasis.quiet => isDark ? 0.042 : 0.48,
      GlassEmphasis.standard => isDark ? 0.068 : 0.66,
      GlassEmphasis.prominent => isDark ? 0.102 : 0.82,
    };
    final coreTint =
        tint ??
        (isDark
            ? BlanquitaColors.of(
                context,
              ).graphiteRaised.withValues(alpha: alpha + 0.72)
            : Colors.white.withValues(alpha: alpha));
    final rimColor =
        borderColor ??
        (isDark
            ? Colors.white.withValues(
                alpha: emphasis == GlassEmphasis.prominent ? 0.17 : 0.11,
              )
            : Colors.white.withValues(alpha: 0.88));
    final innerRadius = _insetRadius(actualRadius, 1.25);

    Widget core = DecoratedBox(
      decoration: BoxDecoration(
        color: coreTint,
        borderRadius: innerRadius,
        gradient: glassOn
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, 0.34, 1],
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.072 : 0.55),
                  coreTint,
                  BlanquitaColors.of(
                    context,
                  ).cyan.withValues(alpha: isDark ? 0.015 : 0.022),
                ],
              )
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 18,
            right: 18,
            height: 1,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: isDark ? 0.26 : 0.86),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: (padding ?? EdgeInsets.zero) * d,
              child: child,
            ),
          ),
        ],
      ),
    );

    if (blurOn) {
      core = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: core,
      );
    }

    final shell = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: actualRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.20 : 0.94),
            rimColor,
            BlanquitaColors.of(
              context,
            ).cyan.withValues(alpha: isDark ? 0.085 : 0.11),
            Colors.white.withValues(alpha: isDark ? 0.045 : 0.68),
          ],
        ),
        boxShadow:
            elevation <= 0 ||
                !settings.shadowsEnabled ||
                settings.performanceMode
            ? null
            : [
                BoxShadow(
                  color:
                      (isDark
                              ? const Color(0xFF001016)
                              : BlanquitaColors.of(context).steel)
                          .withValues(
                            alpha: settings.performanceMode
                                ? 0.10
                                : 0.18 * elevation,
                          ),
                  blurRadius: settings.performanceMode ? 10 : 25,
                  offset: const Offset(0, 13),
                ),
                if (glassOn && emphasis == GlassEmphasis.prominent)
                  BoxShadow(
                    color: BlanquitaColors.of(
                      context,
                    ).cyan.withValues(alpha: 0.035),
                    blurRadius: 30,
                    spreadRadius: -4,
                  ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.25),
        child: ClipRRect(borderRadius: innerRadius, child: core),
      ),
    );

    return Padding(padding: margin ?? EdgeInsets.zero, child: shell);
  }

  BorderRadius _insetRadius(BorderRadius radius, double inset) {
    Radius shrink(Radius value) => Radius.elliptical(
      (value.x - inset).clamp(0, double.infinity),
      (value.y - inset).clamp(0, double.infinity),
    );
    return BorderRadius.only(
      topLeft: shrink(radius.topLeft),
      topRight: shrink(radius.topRight),
      bottomLeft: shrink(radius.bottomLeft),
      bottomRight: shrink(radius.bottomRight),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.tint,
    this.borderColor,
    this.emphasis = GlassEmphasis.standard,
    this.blur = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Color? borderColor;
  final GlassEmphasis emphasis;
  final bool blur;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => GlassSurface(
    padding: padding,
    tint: tint,
    borderColor: borderColor,
    emphasis: emphasis,
    blur: blur,
    borderRadius: borderRadius,
    child: child,
  );
}

class GlassCard extends GlassPanel {
  const GlassCard({
    super.key,
    required super.child,
    super.padding,
    super.tint,
    super.borderColor,
    super.emphasis,
    super.blur,
    super.borderRadius,
  });
}

class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => GlassSurface(
    padding: padding,
    borderRadius: BorderRadius.circular(14),
    tint: color?.withValues(alpha: 0.09),
    borderColor: color?.withValues(alpha: 0.28),
    emphasis: GlassEmphasis.quiet,
    elevation: 0,
    child: child,
  );
}

class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    this.expanded = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final bool expanded;
  final String? semanticLabel;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final settings = context.watch<SettingsController>().settings;
    final reduceMotion =
        settings.reduceMotion ||
        settings.performanceMode ||
        MediaQuery.disableAnimationsOf(context);
    final foreground = widget.color ?? Theme.of(context).colorScheme.onSurface;
    final content = AnimatedScale(
      scale: _pressed && enabled ? 0.975 : 1,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _pressed && enabled ? const Offset(0, 0.018) : Offset.zero,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: enabled ? 1 : 0.36,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(18),
            padding: widget.padding,
            tint: widget.color?.withValues(alpha: _pressed ? 0.19 : 0.11),
            borderColor: _focused
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.72)
                : widget.color?.withValues(alpha: 0.32),
            emphasis: _pressed ? GlassEmphasis.prominent : GlassEmphasis.quiet,
            elevation: _pressed ? 0 : 0.45,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground, size: 20),
                child: Center(child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapCancel: enabled
                ? () => setState(() => _pressed = false)
                : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTap: widget.onPressed,
            child: widget.expanded
                ? SizedBox(width: double.infinity, child: content)
                : content,
          ),
        ),
      ),
    );
  }
}
