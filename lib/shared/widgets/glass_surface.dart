import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/settings/controller/app_settings.dart';
import '../../features/settings/controller/settings_controller.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.tint,
    this.borderColor,
    this.elevation = 1,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color? tint;
  final Color? borderColor;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassOn = settings.glassEnabled && !settings.performanceMode;
    final sigma = switch (settings.glassIntensity) {
      GlassIntensity.low => 7.0,
      GlassIntensity.medium => 12.0,
      GlassIntensity.high => 18.0,
    };
    final baseTint =
        tint ??
        (isDark
            ? Colors.white.withValues(alpha: glassOn ? 0.065 : 0.085)
            : Colors.white.withValues(alpha: glassOn ? 0.55 : 0.86));
    final border =
        borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.9));

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: baseTint,
        borderRadius: borderRadius,
        border: Border.all(color: border),
        boxShadow: elevation <= 0
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.18 * elevation : 0.07 * elevation,
                  ),
                  blurRadius: settings.performanceMode ? 8 : 22,
                  offset: const Offset(0, 10),
                ),
                if (glassOn)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: isDark ? 0.025 : 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, -1),
                  ),
              ],
        gradient: glassOn
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.07 : 0.52),
                  baseTint,
                  AppColors.cyan.withValues(alpha: isDark ? 0.018 : 0.025),
                ],
              )
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );

    if (glassOn) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: content,
        ),
      );
    }

    return Padding(padding: margin ?? EdgeInsets.zero, child: content);
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.tint,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => GlassSurface(
    padding: padding,
    tint: tint,
    borderColor: borderColor,
    child: child,
  );
}

class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduceMotion =
        context.watch<SettingsController>().settings.reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    final content = AnimatedScale(
      scale: _pressed && enabled ? 0.975 : 1,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 120),
      child: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(18),
          padding: widget.padding,
          tint: widget.color?.withValues(alpha: 0.16),
          borderColor: widget.color?.withValues(alpha: 0.38),
          elevation: 0.5,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: widget.color ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: widget.color),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTap: widget.onPressed,
          child: widget.expanded
              ? SizedBox(width: double.infinity, child: content)
              : content,
        ),
      ),
    );
  }
}
