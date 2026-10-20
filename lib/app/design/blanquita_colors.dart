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
  static const hamburger = BlanquitaColors(
    canvas: Color(0xFF100A06),
    graphite: Color(0xFF21140C),
    graphiteRaised: Color(0xFF2D1C11),
    coldWhite: Color(0xFFFFF4E3),
    steel: Color(0xFFBDA58F),
    cyan: Color(0xFFFFC928),
    cyanDeep: Color(0xFFFFA31A),
    mint: Color(0xFF55D63A),
    warning: Color(0xFFFFA31A),
    danger: Color(0xFFFF343F),
  );
  static const backgroundSoft = Color(0xFF180F09);
  static const toasted = Color(0xFFE67E15);
  static const tomato = Color(0xFFE72831);
  static const sesame = Color(0xFFE5C69A);
  static const muted = Color(0xFF9A8472);

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
