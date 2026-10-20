import 'theme_visual_screen.dart';
import '../controller/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../../shared/widgets/blanquita/blanquita_components.dart';
import '../controller/settings_controller.dart';

class PersonalizationPanel extends StatelessWidget {
  const PersonalizationPanel({
    super.key,
    this.expanded = false,
    this.initialSection,
  });
  final String? initialSection;
  final bool expanded;
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final s = controller.settings;
    final effects = !s.performanceMode;
    if (!expanded && s.visualTheme != BlanquitaVisualTheme.original) {
      return _CompactPreferences(controller: controller);
    }
    return BlanquitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (initialSection == null) ...[
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
          ],
          ExpansionTile(
            initiallyExpanded: initialSection == 'type',
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
            initiallyExpanded: initialSection == 'effects',
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
            initiallyExpanded: initialSection == 'assistant',
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

class _CompactPreferences extends StatelessWidget {
  const _CompactPreferences({required this.controller});
  final SettingsController controller;
  void details(BuildContext context, String section) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .8,
          minChildSize: .4,
          maxChildSize: .95,
          builder: (context, scroll) => SingleChildScrollView(
            controller: scroll,
            padding: BlanquitaSpacing.card,
            child: PersonalizationPanel(
              expanded: true,
              initialSection: section,
            ),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final s = controller.settings;
    Widget row(IconData icon, String label, String value, VoidCallback tap) =>
        InkWell(
          onTap: tap,
          borderRadius: BlanquitaRadius.card,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: BlanquitaSpacing.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: BlanquitaColors.of(context).cyan),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        );
    return BlanquitaCard(
      padding: BlanquitaSpacing.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            Icons.palette_outlined,
            'Tema visual',
            s.visualTheme == BlanquitaVisualTheme.custom
                ? 'Personalizado'
                : 'Hamburguesa',
            () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ThemeVisualScreen(),
              ),
            ),
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (theme, label) in [
                (BlanquitaVisualTheme.original, 'Original'),
                (BlanquitaVisualTheme.hamburger, 'Hamburguesa'),
                (BlanquitaVisualTheme.custom, 'Personalizado'),
              ])
                ChoiceChip(
                  key: ValueKey('theme-${theme.name}'),
                  label: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  selected: s.visualTheme == theme,
                  onSelected: (_) => controller.setVisualTheme(theme),
                ),
            ],
          ),
          row(
            Icons.text_fields,
            'Tipografía',
            s.font == BlanquitaFont.outfit ? 'Outfit' : 'Sistema',
            () => details(context, 'type'),
          ),
          row(Icons.format_size, 'Tamaño de texto', switch (s.textSize) {
            BlanquitaTextSize.small => 'Pequeño',
            BlanquitaTextSize.normal => 'Normal',
            BlanquitaTextSize.large => 'Grande',
          }, () => details(context, 'type')),
          row(
            Icons.space_dashboard_outlined,
            'Tamaño de interfaz',
            switch (s.density) {
              BlanquitaDensity.compact => 'Compacta',
              BlanquitaDensity.normal => 'Normal',
              BlanquitaDensity.large => 'Grande',
            },
            () => details(context, 'type'),
          ),
          row(
            Icons.animation,
            'Transiciones',
            s.reduceMotion || s.performanceMode ? 'Reducidas' : 'Suaves',
            () => details(context, 'effects'),
          ),
          row(
            Icons.grain,
            'Animaciones',
            s.reduceMotion || s.performanceMode ? 'Reducidas' : 'Lluvia cálida',
            () => details(context, 'effects'),
          ),
          row(
            Icons.support_agent,
            'Asistente ALFRESI',
            s.assistantEnabled ? 'Activado' : 'Desactivado',
            () => details(context, 'assistant'),
          ),
        ],
      ),
    );
  }
}
