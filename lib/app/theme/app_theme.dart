import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFF050B0F);
  static const graphite = Color(0xFF0A141A);
  static const graphiteRaised = Color(0xFF101E26);
  static const coldWhite = Color(0xFFEAF7FA);
  static const steel = Color(0xFF8CA2AA);
  static const cyan = Color(0xFF6ACFE2);
  static const cyanDeep = Color(0xFF269AB1);
  static const mint = Color(0xFF6ED2AB);
  static const warning = Color(0xFFEDA963);
  static const danger = Color(0xFFF06D79);
}

abstract final class AppTheme {
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.cyan,
          brightness: brightness,
          surface: isDark ? AppColors.graphite : const Color(0xFFF1F6F7),
          error: AppColors.danger,
        ).copyWith(
          primary: isDark ? AppColors.cyan : AppColors.cyanDeep,
          onSurface: isDark ? AppColors.coldWhite : const Color(0xFF12242B),
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Outfit',
      scaffoldBackgroundColor: isDark
          ? AppColors.canvas
          : const Color(0xFFEAF1F3),
      splashFactory: InkSparkle.splashFactory,
    );

    final text = base.textTheme.apply(fontFamily: 'Outfit');
    return base.copyWith(
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontSize: 38,
          height: 0.98,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.6,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontSize: 31,
          height: 1.02,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.1,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.55,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 20,
          height: 1.16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.35,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.15,
        ),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.46),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        bodySmall: text.bodySmall?.copyWith(height: 1.38),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
        ),
        labelMedium: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.12,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.onSurface.withValues(alpha: isDark ? 0.045 : 0.035),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.72)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.11)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(
          scheme.onSurface.withValues(alpha: 0.08),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.48)
              : scheme.onSurface.withValues(alpha: 0.08),
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: 0.42),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.graphiteRaised : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.onSurface.withValues(alpha: 0.065),
        thickness: 1,
      ),
      iconTheme: IconThemeData(
        size: 21,
        color: scheme.onSurface.withValues(alpha: 0.76),
      ),
    );
  }
}
