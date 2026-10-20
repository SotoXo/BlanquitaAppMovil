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

class _MainShellState extends State<MainShell> {
  final PageController _pageController = PageController();
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
    if (reduceMotion) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 330),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final warm =
        context.watch<SettingsController>().settings.visualTheme !=
        BlanquitaVisualTheme.original;
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
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (value) {
                if (_index != value) setState(() => _index = value);
              },
              children: _pages,
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
    super.dispose();
  }
}
