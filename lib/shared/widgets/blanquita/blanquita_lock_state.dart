import '../../../features/assistant/presentation/alfresi_avatar.dart';
import '../../../features/assistant/domain/alfresi_message.dart';
import '../../../features/settings/controller/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../../../app/design/blanquita_design.dart';
import 'blanquita_components.dart';

class BlanquitaLockState extends StatelessWidget {
  const BlanquitaLockState({
    super.key,
    required this.reason,
    this.onDiagnostic,
    this.critical = false,
  });
  final String reason;
  final VoidCallback? onDiagnostic;
  final bool critical;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: BlanquitaCard(
      borderColor: critical
          ? BlanquitaColors.of(context).danger
          : BlanquitaColors.of(context).warning,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (context.watch<SettingsController>().settings.assistantEnabled)
            const Center(
              child: AlfresiAvatar(
                size: AlfresiSizes.l,
                mood: AlfresiMood.warning,
              ),
            ),
          const SizedBox(height: BlanquitaSpacing.sm),
          Icon(
            Icons.lock_outline,
            size: 28,
            color: critical
                ? BlanquitaColors.of(context).danger
                : BlanquitaColors.of(context).warning,
          ),
          const SizedBox(height: 10),
          Text(
            'Control bloqueado',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(reason, textAlign: TextAlign.center),
          if (onDiagnostic != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onDiagnostic,
              icon: const Icon(Icons.monitor_heart_outlined),
              label: const Text('Ver diagnóstico'),
            ),
          ],
        ],
      ),
    ),
  );
}

class BlanquitaErrorState extends StatelessWidget {
  const BlanquitaErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => BlanquitaCard(
    child: Column(
      children: [
        Icon(Icons.error_outline, color: BlanquitaColors.of(context).danger),
        const SizedBox(height: 10),
        Text(message),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
