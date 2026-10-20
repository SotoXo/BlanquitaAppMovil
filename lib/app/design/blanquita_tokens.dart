import 'package:flutter/material.dart';

abstract final class BlanquitaSpacing {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0;
  static const page = EdgeInsets.fromLTRB(lg, md, lg, 112);
  static const card = EdgeInsets.all(lg);
  static const compact = EdgeInsets.all(md);
}

abstract final class BlanquitaRadius {
  static const small = 12.0, standard = 18.0, hero = 22.0, control = 28.0;
  static const card = BorderRadius.all(Radius.circular(standard));
}

abstract final class BlanquitaTypography {
  static const appTitle = 30.0, pageTitle = 25.0, cardTitle = 16.0;
  static const state = 18.0, body = 14.0, secondary = 12.0, micro = 10.0;
}

abstract final class BlanquitaMotion {
  static const ambient = Duration(seconds: 10);
  static const micro = Duration(milliseconds: 190);
  static const modal = Duration(milliseconds: 220);
  static const theme = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;
}

abstract final class AlfresiSizes {
  static const xs = 24.0,
      s = 32.0,
      m = 48.0,
      l = 64.0,
      xl = 112.0,
      hero = 220.0;
}

abstract final class BlanquitaOpacity {
  static const surface = .88, raised = .94, critical = .98;
}
