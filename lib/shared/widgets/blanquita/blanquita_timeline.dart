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
  });
  final bool transportOpen, ready, connecting;
  final String phase;
  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Conectar', transportOpen || ready, connecting && !transportOpen),
      ('Confirmar READY', ready, transportOpen && !ready),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, complete, active) in steps)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              complete
                  ? Icons.check_circle
                  : active
                  ? Icons.hourglass_top
                  : Icons.radio_button_unchecked,
              color: complete
                  ? BlanquitaColors.of(context).mint
                  : active
                  ? BlanquitaColors.of(context).warning
                  : BlanquitaColors.of(context).steel,
            ),
            title: Text(label),
            subtitle: Text(
              complete
                  ? 'Completado'
                  : active
                  ? 'Procesando'
                  : 'Pendiente',
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
