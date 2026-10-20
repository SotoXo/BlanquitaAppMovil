import 'package:flutter/material.dart';

/// Semantic colors shared by widgets and painters; interpolated by AnimatedTheme.
@immutable
class BlanquitaColors extends ThemeExtension<BlanquitaColors> {
  const BlanquitaColors({
    required this.canvas,
    required this.graphite,
    required this.graphiteRaised,
    required this.coldWhite,
    required this.steel,
    required this.cyan,
    required this.cyanDeep,
    required this.mint,
    required this.warning,
    required this.danger,
  });
  final Color canvas, graphite, graphiteRaised, coldWhite, steel;
  final Color cyan, cyanDeep, mint, warning, danger;

  static const original = BlanquitaColors(
    canvas: Color(0xFF050B0F),
    graphite: Color(0xFF0A141A),
    graphiteRaised: Color(0xFF101E26),
    coldWhite: Color(0xFFEAF7FA),
    steel: Color(0xFF8CA2AA),
    cyan: Color(0xFF6ACFE2),
    cyanDeep: Color(0xFF269AB1),
    mint: Color(0xFF6ED2AB),
    warning: Color(0xFFEDA963),
    danger: Color(0xFFF06D79),
  );
  static const backgroundDeep = Color(0xFF17100B);
  static const background = Color(0xFF21150D);
  static const surface = Color(0xFF321F10);
  static const surfaceSoft = Color(0xFF3A2515);
  static const surfaceRaised = Color(0xFF4A2A12);
  static const brownStrong = Color(0xFF6D360F);
  static const cream = Color(0xFFF6EBD3);
  static const creamMuted = Color(0xFFAAA59A);
  static const cheese = Color(0xFFF1B822);
  static const cheddar = Color(0xFFCA6730);
  static const lettuce = Color(0xFF7AC227);
  static const success = Color(0xFF29D24A);
  static const ketchup = Color(0xFFDD1415);
  static const info = Color(0xFF43A7D8);
  static const hamburger = BlanquitaColors(
    canvas: backgroundDeep,
    graphite: background,
    graphiteRaised: surface,
    coldWhite: cream,
    steel: creamMuted,
    cyan: cheese,
    cyanDeep: cheddar,
    mint: success,
    warning: cheese,
    danger: Color(0xFFFF2B25),
  );
  static const backgroundSoft = surfaceSoft;
  static const toasted = cheddar;
  static const tomato = ketchup;
  static const sesame = cream;
  static const muted = creamMuted;

  static BlanquitaColors of(BuildContext context) =>
      Theme.of(context).extension<BlanquitaColors>() ?? original;

  @override
  BlanquitaColors copyWith({Color? cyan}) => BlanquitaColors(
    canvas: canvas,
    graphite: graphite,
    graphiteRaised: graphiteRaised,
    coldWhite: coldWhite,
    steel: steel,
    cyan: cyan ?? this.cyan,
    cyanDeep: cyanDeep,
    mint: mint,
    warning: warning,
    danger: danger,
  );
  @override
  BlanquitaColors lerp(covariant BlanquitaColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return BlanquitaColors(
      canvas: mix(canvas, other.canvas),
      graphite: mix(graphite, other.graphite),
      graphiteRaised: mix(graphiteRaised, other.graphiteRaised),
      coldWhite: mix(coldWhite, other.coldWhite),
      steel: mix(steel, other.steel),
      cyan: mix(cyan, other.cyan),
      cyanDeep: mix(cyanDeep, other.cyanDeep),
      mint: mix(mint, other.mint),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
    );
  }
}
