import '../design/blanquita_design.dart';
import '../../features/devices/presentation/devices_screen.dart';
import '../../features/settings/controller/app_settings.dart';
import 'blanquita_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/control/presentation/control_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/settings/controller/settings_controller.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/vision/presentation/vision_screen.dart';
import '../../shared/widgets/app_background.dart';
import 'glass_navigation_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final _transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final _opacity = _transition
      .drive(CurveTween(curve: Curves.easeOutCubic))
      .drive(Tween(begin: .72, end: 1.0));
  int _index = 0;

  static const _pages = [
    DashboardScreen(),
    ControlScreen(),
    VisionScreen(),
    SettingsScreen(),
    DevicesScreen(),
  ];

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    final settings = context.read<SettingsController>().settings;
    final reduceMotion = BlanquitaDesign.reduce(context, settings);
    // Jump directly so distant destinations never expose intermediate screens.
    _pageController.jumpToPage(index);
    if (reduceMotion) {
      _transition.value = 1;
    } else {
      _transition.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final warm = settings.visualTheme != BlanquitaVisualTheme.original;
    final reduce = BlanquitaDesign.reduce(context, settings);
    return AppBackground(
      scene: _index,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: !warm,
        bottomNavigationBar: warm
            ? BlanquitaBottomNavigation(index: _index, onSelected: _select)
            : null,
        body: Stack(
          children: [
            FadeTransition(
              opacity: reduce ? const AlwaysStoppedAnimation(1.0) : _opacity,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) {
                  if (_index != value) setState(() => _index = value);
                },
                children: _pages,
              ),
            ),
            if (!warm)
              Positioned(
                left: 14,
                right: 14,
                bottom: 10,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: GlassNavigationBar(
                        index: _index,
                        onSelected: _select,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transition.dispose();
    super.dispose();
  }
}
