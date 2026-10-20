import '../../../core/models/esp32_device.dart';
import 'package:flutter/material.dart';
import '../../../app/design/blanquita_design.dart';

/// Only the observed transport and READY handshake; no invented auth stages.
class BlanquitaTimeline extends StatelessWidget {
  const BlanquitaTimeline({
    super.key,
    required this.transportOpen,
    required this.ready,
    required this.connecting,
    required this.phase,
    this.linkPhase,
  });
  final bool transportOpen, ready, connecting;
  final String phase;
  final Esp32LinkPhase? linkPhase;
  @override
  Widget build(BuildContext context) {
    final p = linkPhase;
    final stages = [
      Esp32LinkPhase.connecting,
      Esp32LinkPhase.identityVerified,
      Esp32LinkPhase.authenticating,
      Esp32LinkPhase.authorized,
    ];
    final stage = p == null ? -1 : stages.indexOf(p);
    final steps = p != null && p != Esp32LinkPhase.laboratory
        ? [
            for (var i = 0; i < stages.length; i++)
              (
                [
                  'Conectar',
                  'Verificar identidad',
                  'Autenticar',
                  'Autorizar',
                ][i],
                stage > i || p == Esp32LinkPhase.authorized,
                stage == i && p != Esp32LinkPhase.authorized,
              ),
          ]
        : [
            ('Conectar', transportOpen || ready, connecting && !transportOpen),
            ('Confirmar READY', ready, transportOpen && !ready),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      Icon(
                        steps[i].$2
                            ? Icons.check_circle
                            : steps[i].$3
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 28,
                        color: steps[i].$2
                            ? BlanquitaColors.of(context).mint
                            : steps[i].$3
                            ? BlanquitaColors.of(context).cyan
                            : BlanquitaColors.of(context).steel,
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1,
                            color: BlanquitaColors.of(
                              context,
                            ).mint.withValues(alpha: .4),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$1,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          steps[i].$2
                              ? 'Completado'
                              : steps[i].$3
                              ? 'Procesando'
                              : 'Pendiente',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Ver detalles técnicos'),
          children: [
            ListTile(
              title: const Text('Fase observada'),
              subtitle: Text(phase),
            ),
          ],
        ),
      ],
    );
  }
}
