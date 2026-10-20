import 'package:flutter/material.dart';
import '../../features/settings/controller/app_settings.dart';
import '../theme/app_theme.dart';
import 'blanquita_colors.dart';
export 'blanquita_colors.dart';
export 'blanquita_tokens.dart';
import 'blanquita_tokens.dart';

class BlanquitaTextScaler extends TextScaler {
  const BlanquitaTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => system.scale(14) / 14 * factor;
  @override
  bool operator ==(Object other) =>
      other is BlanquitaTextScaler &&
      other.system == system &&
      other.factor == factor;
  @override
  int get hashCode => Object.hash(system, factor);
}

abstract final class BlanquitaDesign {
  static const micro = Duration(milliseconds: 190);
  static const modal = Duration(milliseconds: 220);
  static const theme = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;
  static const touch = 48.0;
  static const gap = 16.0;
  static const radius = 22.0;
  static double density(AppSettings s) => switch (s.density) {
    BlanquitaDensity.compact => .85,
    BlanquitaDensity.normal => 1,
    BlanquitaDensity.large => 1.18,
  };
  static double textScale(AppSettings s) => switch (s.textSize) {
    BlanquitaTextSize.small => .9,
    BlanquitaTextSize.normal => 1,
    BlanquitaTextSize.large => 1.2,
  };
  static bool reduce(BuildContext context, AppSettings s) =>
      s.reduceMotion ||
      s.performanceMode ||
      MediaQuery.disableAnimationsOf(context);

  static ThemeData build(AppSettings s, Brightness brightness) {
    final base = brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;
    final original = s.visualTheme == BlanquitaVisualTheme.original;
    final dark = brightness == Brightness.dark;
    final palette = original
        ? BlanquitaColors.original
        : s.visualTheme == BlanquitaVisualTheme.custom
        ? BlanquitaColors.hamburger.copyWith(cyan: Color(s.customAccent))
        : BlanquitaColors.hamburger;
    final scheme = original
        ? base.colorScheme
        : ColorScheme.fromSeed(
            seedColor: palette.cyan,
            brightness: brightness,
          ).copyWith(
            primary: dark ? palette.cyan : const Color(0xFF805100),
            onPrimary: dark ? palette.canvas : Colors.white,
            secondary: dark ? palette.mint : const Color(0xFF246719),
            surface: dark ? palette.graphite : const Color(0xFFFFF4E3),
            onSurface: dark ? palette.coldWhite : palette.canvas,
            error: dark ? palette.danger : const Color(0xFFB81424),
            onError: Colors.white,
          );
    final effective = dark
        ? palette
        : BlanquitaColors(
            canvas: original
                ? const Color(0xFFEAF1F3)
                : const Color(0xFFFFF4E3),
            graphite: scheme.surface,
            graphiteRaised: original ? Colors.white : const Color(0xFFF2E3CE),
            coldWhite: scheme.onSurface,
            steel: original ? const Color(0xFF526B75) : const Color(0xFF725A43),
            cyan: scheme.primary,
            cyanDeep: scheme.primary,
            mint: original ? const Color(0xFF216D50) : const Color(0xFF246719),
            warning: const Color(0xFF955300),
            danger: scheme.error,
          );
    final d = density(s);
    final font = s.font == BlanquitaFont.outfit
        ? 'Outfit'
        : switch (base.platform) {
            TargetPlatform.iOS || TargetPlatform.macOS => '.SF UI Text',
            TargetPlatform.windows => 'Segoe UI',
            TargetPlatform.linux => 'Ubuntu',
            _ => 'Roboto',
          };
    final text =
        (original
                ? base.textTheme
                : base.textTheme.copyWith(
                    headlineMedium: const TextStyle(
                      fontSize: BlanquitaTypography.appTitle,
                      fontWeight: FontWeight.w700,
                      height: 1.12,
                    ),
                    headlineSmall: const TextStyle(
                      fontSize: BlanquitaTypography.pageTitle,
                      fontWeight: FontWeight.w700,
                      height: 1.16,
                    ),
                    titleLarge: const TextStyle(
                      fontSize: BlanquitaTypography.state,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    titleMedium: const TextStyle(
                      fontSize: BlanquitaTypography.cardTitle,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    bodyLarge: const TextStyle(
                      fontSize: BlanquitaTypography.body,
                      height: 1.4,
                    ),
                    bodyMedium: const TextStyle(
                      fontSize: BlanquitaTypography.body,
                      height: 1.4,
                    ),
                    bodySmall: const TextStyle(
                      fontSize: BlanquitaTypography.secondary,
                      height: 1.35,
                    ),
                    labelLarge: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    labelSmall: const TextStyle(
                      fontSize: BlanquitaTypography.micro,
                      height: 1.2,
                    ),
                  ))
            .apply(
              fontFamily: font,
              bodyColor: scheme.onSurface,
              displayColor: scheme.onSurface,
            );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: effective.canvas,
      textTheme: text,
      extensions: [effective],
      visualDensity: s.density == BlanquitaDensity.compact
          ? VisualDensity.compact
          : VisualDensity.standard,
      iconTheme: IconThemeData(size: 21 * d, color: scheme.onSurface),
      chipTheme: original
          ? base.chipTheme
          : base.chipTheme.copyWith(
              backgroundColor: effective.graphiteRaised,
              selectedColor: effective.cyan.withValues(alpha: .22),
              side: BorderSide(
                color: effective.cyanDeep.withValues(alpha: .35),
              ),
              labelStyle: text.labelSmall?.copyWith(color: effective.coldWhite),
              checkmarkColor: effective.cyan,
              shape: RoundedRectangleBorder(borderRadius: BlanquitaRadius.card),
            ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: .5)
              : scheme.onSurface.withValues(alpha: .12),
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: .7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600),
          elevation: original ? 0 : 2,
          shadowColor: effective.cyanDeep.withValues(alpha: .25),
          side: original
              ? BorderSide.none
              : BorderSide(color: effective.cyan.withValues(alpha: .5)),
          minimumSize: Size(touch, (54 * d).clamp(touch, 72)),
          padding: EdgeInsets.symmetric(horizontal: 20 * d, vertical: 15 * d),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17 * d),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(touch, touch),
          textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: original
              ? null
              : BorderSide(color: effective.cyanDeep.withValues(alpha: .45)),
          minimumSize: Size(touch, (52 * d).clamp(touch, 72)),
          padding: EdgeInsets.symmetric(horizontal: 18 * d, vertical: 14 * d),
          textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17 * d),
          ),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: effective.graphiteRaised,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: effective.graphite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          side: BorderSide(color: effective.cyanDeep.withValues(alpha: .3)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18 * d),
          borderSide: BorderSide(color: scheme.primary),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 18 * d,
          vertical: 17 * d,
        ),
      ),
    );
  }
}
