import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../core/network/wifi_network_controller.dart';
import 'glass_surface.dart';

/// Read-only information about the phone link, independent of both servers.
class WifiNetworkPanel extends StatelessWidget {
  const WifiNetworkPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final network = context.watch<WifiNetworkController>();
    final status = network.status;
    final available = status.supported && network.error == null;
    final connected = available && status.connected;
    final title = network.checking && network.lastUpdatedAt == null
        ? 'Consultando Wi-Fi…'
        : !available
        ? 'Consulta Wi-Fi no disponible'
        : !status.wifiEnabled
        ? 'Wi-Fi desactivado'
        : connected
        ? 'Wi-Fi conectado'
        : 'Wi-Fi activado · sin conexión';
    final accent = connected ? AppColors.mint : AppColors.warning;
    final theme = Theme.of(context);

    return GlassPanel(
      emphasis: GlassEmphasis.standard,
      borderColor: accent.withValues(alpha: .22),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  connected ? CupertinoIcons.wifi : CupertinoIcons.wifi_slash,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wi-Fi del teléfono',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          if (network.error != null) ...[
            const SizedBox(height: 12),
            Text(network.error!, style: theme.textTheme.bodySmall),
          ],
          if (connected) ...[
            const SizedBox(height: 14),
            Text(
              'IP del teléfono: ${status.localIpv4 ?? 'No informada'}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              status.rssiDbm == null
                  ? 'Señal: ${status.signalLabel}'
                  : 'Señal: ${status.signalLabel} · ${status.rssiDbm} dBm',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              status.linkSpeedMbps == null
                  ? 'Velocidad del enlace: No informada'
                  : 'Velocidad del enlace: ${status.linkSpeedMbps} Mbps informados por Android',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(network.stabilityLabel, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Cortes observados: ${network.disconnects} · Cambios de enlace: ${network.linkChanges}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'La señal y la velocidad describen el enlace con el router. La estabilidad se observa mientras la aplicación está activa.',
              style: theme.textTheme.bodySmall,
            ),
            if (status.defaultRouteWifi == false) ...[
              const SizedBox(height: 12),
              const _NetworkNotice(
                message:
                    'Android usa otra red como ruta principal. Aunque el Wi-Fi esté conectado, comprueba el acceso al ESP32 y a la laptop por separado.',
              ),
            ],
            if (status.internetValidated != null) ...[
              const SizedBox(height: 10),
              Text(
                status.internetValidated == true
                    ? 'Internet validado por Android. El acceso local al ESP32 y a la laptop se comprueba por separado.'
                    : 'Android no valida acceso a Internet. La comunicación con dispositivos en la red local puede seguir disponible.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ] else if (available) ...[
            const SizedBox(height: 12),
            Text(network.stabilityLabel, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 14),
          Text(
            'Conéctate al Wi-Fi desde los ajustes del teléfono. Luego configura el ESP32 en el puerto :81 y la laptop en el puerto :8765.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: network.checking ? null : network.refresh,
              icon: const Icon(CupertinoIcons.arrow_clockwise, size: 18),
              label: Text(
                network.checking ? 'Actualizando Wi-Fi…' : 'Actualizar Wi-Fi',
              ),
            ),
          ),
          if (network.lastUpdatedAt case final DateTime updated) ...[
            const SizedBox(height: 4),
            Text(
              'Última consulta: ${_time(updated)}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    return [
      local.hour,
      local.minute,
      local.second,
    ].map((part) => part.toString().padLeft(2, '0')).join(':');
  }
}

class _NetworkNotice extends StatelessWidget {
  const _NetworkNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const ExcludeSemantics(
        child: Icon(
          CupertinoIcons.exclamationmark_triangle,
          size: 20,
          color: AppColors.warning,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}
