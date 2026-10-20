import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../../shared/widgets/blanquita/blanquita_scaffold.dart';
import '../../../shared/widgets/blanquita/blanquita_brand.dart';
import '../../assistant/presentation/alfresi_bubble.dart';
import '../../assistant/domain/alfresi_message.dart';
import '../controller/app_settings.dart';
import '../controller/settings_controller.dart';

class ThemeVisualScreen extends StatefulWidget {
  const ThemeVisualScreen({super.key});
  @override
  State<ThemeVisualScreen> createState() => _ThemeVisualScreenState();
}

class _ThemeVisualScreenState extends State<ThemeVisualScreen> {
  BlanquitaVisualTheme? _selected;
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final selected = _selected ?? controller.settings.visualTheme;
    return BlanquitaScaffold(
      title: 'Tema visual',
      back: true,
      children: [
        const SizedBox(height: BlanquitaSpacing.xl),
        if (controller.settings.assistantEnabled)
          const AlfresiBubble(
            message: '¡Qué buen estilo! Elige cómo quieres ver BLANQUITA.',
            mood: AlfresiMood.success,
          ),
        const SizedBox(height: BlanquitaSpacing.xl),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final (theme, label) in [
                (BlanquitaVisualTheme.original, 'Original'),
                (BlanquitaVisualTheme.hamburger, 'Hamburguesa'),
                (BlanquitaVisualTheme.custom, 'Personalizado'),
              ])
                SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(14) > 22
                      ? c.maxWidth
                      : (c.maxWidth - 16) / 3,
                  child: Semantics(
                    selected: selected == theme,
                    button: true,
                    label: 'Vista previa $label',
                    child: InkWell(
                      onTap: () => setState(() => _selected = theme),
                      borderRadius: BlanquitaRadius.card,
                      child: AnimatedContainer(
                        duration:
                            BlanquitaDesign.reduce(context, controller.settings)
                            ? Duration.zero
                            : BlanquitaMotion.micro,
                        padding: const EdgeInsets.all(BlanquitaSpacing.sm),
                        decoration: BoxDecoration(
                          borderRadius: BlanquitaRadius.card,
                          color: theme == BlanquitaVisualTheme.original
                              ? BlanquitaColors.original.canvas
                              : BlanquitaColors.backgroundDeep,
                          border: Border.all(
                            width: selected == theme ? 2 : 1,
                            color: selected == theme
                                ? BlanquitaColors.of(context).cyan
                                : BlanquitaColors.creamMuted.withValues(
                                    alpha: .3,
                                  ),
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 180,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (theme != BlanquitaVisualTheme.original)
                                    ClipRRect(
                                      borderRadius: BlanquitaRadius.card,
                                      child: Image.asset(
                                        'assets/alfresi/fondo_hamburguesa.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const BlanquitaBrand(size: 32),
                                      const SizedBox(height: 16),
                                      for (var i = 0; i < 3; i++)
                                        Container(
                                          height: 10,
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (theme ==
                                                            BlanquitaVisualTheme
                                                                .original
                                                        ? BlanquitaColors
                                                              .original
                                                              .cyan
                                                        : theme ==
                                                              BlanquitaVisualTheme
                                                                  .custom
                                                        ? Color(
                                                            controller
                                                                .settings
                                                                .customAccent,
                                                          )
                                                        : BlanquitaColors
                                                              .cheese)
                                                    .withValues(alpha: .6),
                                            borderRadius: BlanquitaRadius.card,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 8),
                            Icon(
                              selected == theme
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 20,
                              color: selected == theme
                                  ? BlanquitaColors.of(context).cyan
                                  : BlanquitaColors.creamMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: BlanquitaSpacing.xl),
        FilledButton.icon(
          onPressed: () => controller.setVisualTheme(selected),
          icon: const Icon(Icons.check),
          label: const Text('Aplicar tema'),
        ),
        const SizedBox(height: 12),
        Text(
          'Conserva la pantalla, las conexiones y el estado del robot.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
