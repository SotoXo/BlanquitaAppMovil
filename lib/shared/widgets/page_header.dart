import '../../app/design/blanquita_design.dart';
import 'blanquita/blanquita_scaffold.dart';
import 'package:provider/provider.dart';
import '../../features/settings/controller/settings_controller.dart';
import '../../features/settings/controller/app_settings.dart';
import 'blanquita/blanquita_brand.dart';
import '../../features/assistant/presentation/alfresi_panel.dart';
import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.compact = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (context.watch<SettingsController>().settings.visualTheme !=
        BlanquitaVisualTheme.original) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlanquitaHeader(title: title),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BlanquitaColors.of(context).steel,
                ),
              ),
              ?trailing,
            ],
          ),
        ],
      );
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: compact ? 5 : 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title == 'BLANQUITA' &&
                context.watch<SettingsController>().settings.visualTheme !=
                    BlanquitaVisualTheme.original) ...[
              const BlanquitaBrand(),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? Theme.of(context).textTheme.headlineSmall
                    : Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );

    final accessories = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ?trailing,
        AlfresiButton(
          section: title == 'BLANQUITA'
              ? 'Inicio'
              : (title == 'Visor inteligente' || title == 'Visión · laptop')
              ? 'Visión'
              : title,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520 ||
            MediaQuery.textScalerOf(context).scale(14) > 22) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: content),
                  if (trailing == null)
                    AlfresiButton(
                      section:
                          (title == 'Visor inteligente' ||
                              title == 'Visión · laptop')
                          ? 'Visión'
                          : title,
                    ),
                ],
              ),
              if (trailing != null) ...[
                const SizedBox(height: 12),
                accessories,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: content),
            const SizedBox(width: 12),
            accessories,
          ],
        );
      },
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ),
      ?trailing,
    ],
  );
}
