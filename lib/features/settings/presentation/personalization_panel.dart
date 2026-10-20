import '../controller/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../../shared/widgets/blanquita/blanquita_components.dart';
import '../controller/settings_controller.dart';

class PersonalizationPanel extends StatelessWidget {
  const PersonalizationPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final s = controller.settings;
    final effects = !s.performanceMode;
    return BlanquitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlanquitaSection(
            title: 'Tema visual',
            child: Column(
              children: [
                for (final (theme, label, palette) in [
                  (
                    BlanquitaVisualTheme.original,
                    'Original',
                    BlanquitaColors.original,
                  ),
                  (
                    BlanquitaVisualTheme.hamburger,
                    'Hamburguesa',
                    BlanquitaColors.hamburger,
                  ),
                  (
                    BlanquitaVisualTheme.custom,
                    'Personalizado',
                    BlanquitaColors.hamburger.copyWith(
                      cyan: Color(s.customAccent),
                    ),
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      selected: s.visualTheme == theme,
                      button: true,
                      label: 'Tema $label',
                      child: InkWell(
                        key: ValueKey('theme-${theme.name}'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => controller.setVisualTheme(theme),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: s.visualTheme == theme
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .09)
                                : Colors.transparent,
                            border: Border.all(
                              color: s.visualTheme == theme
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                s.visualTheme == theme
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(label)),
                              for (final c in [
                                palette.canvas,
                                palette.cyan,
                                palette.mint,
                              ])
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  width: 15,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: c,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: Colors.white24),
                                  ),
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
          if (s.visualTheme == BlanquitaVisualTheme.custom) ...[
            const SizedBox(height: 12),
            const Text('Color principal'),
            BlanquitaSegmentedControl<int>(
              value: s.customAccent,
              options: const {
                0xFFFFC928: 'Queso',
                0xFFE5C69A: 'Sésamo',
                0xFF6ACFE2: 'Cian',
              },
              onChanged: controller.setCustomAccent,
            ),
          ],
          const SizedBox(height: 12),
          ExpansionTile(
            key: const ValueKey('personalization-type'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Texto e interfaz'),
            subtitle: const Text('Tipografía, tamaño y densidad'),
            children: [
              _Preference(
                title: 'Tipografía',
                child: BlanquitaSegmentedControl<BlanquitaFont>(
                  value: s.font,
                  options: const {
                    BlanquitaFont.outfit: 'Outfit',
                    BlanquitaFont.system: 'Sistema',
                  },
                  onChanged: controller.setFont,
                ),
              ),
              _Preference(
                title: 'Tamaño de texto',
                child: BlanquitaSegmentedControl<BlanquitaTextSize>(
                  value: s.textSize,
                  options: const {
                    BlanquitaTextSize.small: 'Pequeño',
                    BlanquitaTextSize.normal: 'Normal',
                    BlanquitaTextSize.large: 'Grande',
                  },
                  onChanged: controller.setTextSize,
                ),
              ),
              _Preference(
                title: 'Tamaño de interfaz',
                child: BlanquitaSegmentedControl<BlanquitaDensity>(
                  value: s.density,
                  options: const {
                    BlanquitaDensity.compact: 'Compacta',
                    BlanquitaDensity.normal: 'Normal',
                    BlanquitaDensity.large: 'Grande',
                  },
                  onChanged: controller.setDensity,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'El tamaño se combina con la accesibilidad del dispositivo.',
                ),
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Efectos'),
            subtitle: Text(
              s.performanceMode
                  ? 'Modo rendimiento · efectos reducidos'
                  : 'Movimiento, difuminado y sombras',
            ),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Animaciones'),
                value: !s.reduceMotion,
                onChanged: effects
                    ? (v) => controller.setReduceMotion(!v)
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Difuminado'),
                value: s.glassEnabled,
                onChanged: effects ? controller.setGlassEnabled : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sombras'),
                value: s.shadowsEnabled,
                onChanged: effects ? controller.setShadowsEnabled : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Efectos del asistente'),
                value: s.assistantAnimations,
                onChanged: effects && !s.reduceMotion
                    ? controller.setAssistantAnimations
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Modo rendimiento'),
                value: s.performanceMode,
                onChanged: controller.setPerformanceMode,
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('ALFRESI'),
            subtitle: const Text('Asistente local de BLANQUITA'),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Asistente'),
                value: s.assistantEnabled,
                onChanged: controller.setAssistantEnabled,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Consejos contextuales'),
                value: s.assistantTips,
                onChanged: s.assistantEnabled
                    ? controller.setAssistantTips
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Avisos importantes'),
                value: s.assistantAlerts,
                onChanged: s.assistantEnabled
                    ? controller.setAssistantAlerts
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Detalles técnicos'),
                value: s.assistantTechnical,
                onChanged: s.assistantEnabled
                    ? controller.setAssistantTechnical
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Animaciones del asistente'),
                value: s.assistantAnimations,
                onChanged: s.assistantEnabled && effects && !s.reduceMotion
                    ? controller.setAssistantAnimations
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preference extends StatelessWidget {
  const _Preference({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
