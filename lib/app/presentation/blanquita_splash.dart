import 'package:provider/provider.dart';
import '../../features/settings/controller/settings_controller.dart';
import 'package:flutter/material.dart';
import '../design/blanquita_design.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/blanquita/blanquita_brand.dart';
import '../../features/assistant/presentation/alfresi_avatar.dart';

/// Visual-only startup presentation. Never waits for a connection or delays it.
class BlanquitaSplash extends StatelessWidget {
  const BlanquitaSplash({super.key, this.progress = .4});
  final double progress;
  @override
  Widget build(BuildContext context) => AppBackground(
    child: Material(
      color: Colors.transparent,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(BlanquitaSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BlanquitaBrand(size: AlfresiSizes.l),
                    const SizedBox(height: BlanquitaSpacing.lg),
                    Text(
                      'BLANQUITA',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: BlanquitaSpacing.xs),
                    Text(
                      'CONTROL ROBÓTICO',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(letterSpacing: 2),
                    ),
                    const SizedBox(height: 40),
                    const AlfresiAvatar(size: AlfresiSizes.hero),
                    const SizedBox(height: BlanquitaSpacing.xl),
                    Text(
                      'ALFRESI',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: BlanquitaSpacing.xs),
                    const Text('Tu asistente siempre contigo'),
                    const SizedBox(height: 40),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(
                          BlanquitaRadius.small,
                        ),
                      ),
                    ),
                    const SizedBox(height: BlanquitaSpacing.md),
                    const Text('Cargando…'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class StartupPresentation extends StatefulWidget {
  const StartupPresentation({super.key, required this.child});
  final Widget child;
  @override
  State<StartupPresentation> createState() => _StartupPresentationState();
}

class _StartupPresentationState extends State<StartupPresentation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..forward();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (BlanquitaDesign.reduce(
      context,
      context.read<SettingsController>().settings,
    )) {
      _animation.stop();
      _animation.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) => Stack(
      children: [
        child!,
        if (_animation.value < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: _animation.value > .8 ? (1 - _animation.value) * 5 : 1,
                child: BlanquitaSplash(progress: _animation.value),
              ),
            ),
          ),
      ],
    ),
  );
  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }
}
