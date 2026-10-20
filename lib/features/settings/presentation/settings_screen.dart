import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../features/diagnostics/presentation/diagnostics_screen.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/motion_reveal.dart';
import '../../../shared/widgets/page_header.dart';
import '../controller/app_settings.dart';
import '../controller/settings_controller.dart';
import 'esp32_identity_panel.dart';
import '../../vision/controller/vision_controller.dart';
import '../../vision/services/remote_vision_service.dart';
import '../../vision/presentation/vision_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? _expanded = 0;

  void _toggle(int index) {
    setState(() => _expanded = _expanded == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final settings = controller.settings;
    final machine = context.watch<MachineController>();
    final vision = context.watch<VisionController>();
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 126),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MotionReveal(
                  child: PageHeader(
                    eyebrow: 'Preferencias',
                    title: 'Ajustes',
                    subtitle:
                        'Configura la experiencia sin alterar el protocolo de la máquina.',
                  ),
                ),
                const SizedBox(height: 18),
                MotionReveal(
                  delay: const Duration(milliseconds: 55),
                  child: _ConnectionPanel(
                    machine: machine,
                    autoReconnect: settings.autoReconnect,
                    onEdit: () => _editWebsocket(context, controller, machine),
                  ),
                ),
                const SizedBox(height: 18),
                _VisionConnectionPanel(
                  vision: vision,
                  onEdit: () => _editVisionUrl(context, controller),
                ),
                const SizedBox(height: 10),
                GlassButton(
                  expanded: true,
                  onPressed: machine.isConnecting && vision.isConnecting
                      ? null
                      : () {
                          if (!machine.isConnecting) {
                            unawaited(machine.searchEsp32());
                          }
                          if (!vision.isConnecting) {
                            unawaited(vision.searchVision());
                          }
                        },
                  child: const Text('Buscar dispositivos'),
                ),
                const SizedBox(height: 18),
                Text(
                  'Preferencias de la aplicación',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
                const SizedBox(height: 9),
                MotionReveal(
                  delay: const Duration(milliseconds: 100),
                  child: _SettingsDisclosure(
                    icon: CupertinoIcons.game_controller,
                    title: 'Control',
                    summary: settings.hapticsEnabled
                        ? 'Haptics activos · confirmación ${settings.confirmSequence ? 'activa' : 'omitida'}'
                        : 'Haptics desactivados',
                    expanded: _expanded == 0,
                    onTap: () => _toggle(0),
                    children: [
                      _ToggleRow(
                        title: 'Feedback háptico',
                        subtitle:
                            'Respuesta proporcional para movimiento y acciones.',
                        value: settings.hapticsEnabled,
                        onChanged: controller.setHapticsEnabled,
                      ),
                      _ToggleRow(
                        title: 'Confirmar secuencia',
                        subtitle:
                            'Pedir confirmación antes de enviar el comando j.',
                        value: settings.confirmSequence,
                        onChanged: controller.setConfirmSequence,
                      ),
                      _SliderRow(
                        title: 'Respuesta visual',
                        subtitle:
                            'Intensidad de movimiento del esquema cartesiano.',
                        value: settings.visualSensitivity,
                        onChanged: controller.setVisualSensitivity,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsDisclosure(
                  icon: CupertinoIcons.sparkles,
                  title: 'Apariencia',
                  summary: settings.performanceMode
                      ? 'Modo rendimiento activo'
                      : 'Glass ${settings.glassEnabled ? 'activo' : 'desactivado'} · ${_themeLabel(settings.themeMode)}',
                  expanded: _expanded == 1,
                  onTap: () => _toggle(1),
                  children: [
                    _ChoiceRow<ThemeMode>(
                      title: 'Tema',
                      value: settings.themeMode,
                      options: const {
                        ThemeMode.dark: 'Oscuro',
                        ThemeMode.light: 'Claro',
                        ThemeMode.system: 'Sistema',
                      },
                      onChanged: controller.setThemeMode,
                    ),
                    _ToggleRow(
                      title: 'Liquid Glass',
                      subtitle: 'Material translúcido, biseles y reflejos.',
                      value: settings.glassEnabled,
                      onChanged: settings.performanceMode
                          ? null
                          : controller.setGlassEnabled,
                    ),
                    _ChoiceRow<GlassIntensity>(
                      title: 'Intensidad',
                      value: settings.glassIntensity,
                      options: const {
                        GlassIntensity.low: 'Baja',
                        GlassIntensity.medium: 'Media',
                        GlassIntensity.high: 'Alta',
                      },
                      onChanged:
                          settings.glassEnabled && !settings.performanceMode
                          ? controller.setGlassIntensity
                          : null,
                    ),
                    _ToggleRow(
                      title: 'Reducir animaciones',
                      subtitle:
                          'Reduce entradas, desplazamientos y transiciones.',
                      value: settings.reduceMotion,
                      onChanged: controller.setReduceMotion,
                    ),
                    _ToggleRow(
                      title: 'Modo rendimiento',
                      subtitle: 'Reduce el coste gráfico de las superficies.',
                      value: settings.performanceMode,
                      onChanged: controller.setPerformanceMode,
                      accent: AppColors.mint,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SettingsDisclosure(
                  icon: CupertinoIcons.lock_shield,
                  title: 'Seguridad',
                  summary: settings.showWarnings
                      ? 'Advertencias visibles'
                      : 'Avisos reducidos',
                  expanded: _expanded == 2,
                  onTap: () => _toggle(2),
                  children: [
                    _ToggleRow(
                      title: 'Mostrar advertencias',
                      subtitle: 'Mantener visibles los estados importantes.',
                      value: settings.showWarnings,
                      onChanged: controller.setShowWarnings,
                    ),
                    _ToggleRow(
                      title: 'Final de carrera',
                      subtitle:
                          'Vibración fuerte una vez al activar el bloqueo.',
                      value: settings.strongLimitFeedback,
                      onChanged: controller.setStrongLimitFeedback,
                    ),
                    _ToggleRow(
                      title: 'Pérdida de conexión',
                      subtitle:
                          'Mostrar un aviso persistente al perder el enlace.',
                      value: settings.connectionLossAlerts,
                      onChanged: controller.setConnectionLossAlerts,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SettingsDisclosure(
                  icon: CupertinoIcons.viewfinder,
                  title: 'Conexión visión',
                  summary: 'Laptop: ${visionConnectionLabel(vision.state)}',
                  expanded: _expanded == 3,
                  onTap: () => _toggle(3),
                  children: [
                    _ActionRow(
                      title: 'URL Vision Server',
                      subtitle: settings.visionWebsocketUrl.isEmpty
                          ? 'Sin dirección guardada'
                          : settings.visionWebsocketUrl,
                      onTap: () => _editVisionUrl(context, controller),
                    ),
                    _ActionRow(
                      title: 'Vision Server',
                      subtitle: vision.state.ready ? 'Ready' : 'No disponible',
                    ),
                    _ToggleRow(
                      title: 'Reconexión de visión',
                      subtitle:
                          'Recuperar el enlace con la laptop automáticamente.',
                      value: settings.visionAutoReconnect,
                      onChanged: controller.setVisionAutoReconnect,
                    ),
                    _ChoiceRow<Duration>(
                      title: 'Timeout heartbeat',
                      value: settings.visionHeartbeatTimeout,
                      options: {
                        settings.visionHeartbeatTimeout:
                            '${settings.visionHeartbeatTimeout.inMilliseconds / 1000} s',
                        const Duration(seconds: 6): '6 s',
                        const Duration(seconds: 10): '10 s',
                        const Duration(seconds: 30): '30 s',
                      },
                      onChanged: controller.setVisionHeartbeatTimeout,
                    ),
                    _SliderRow(
                      title:
                          'Confianza mínima · ${(settings.visionMinimumConfidence * 100).round()} %',
                      subtitle:
                          'Umbral informativo para los reportes recibidos.',
                      value: settings.visionMinimumConfidence,
                      onChanged: controller.setVisionMinimumConfidence,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GlassButton(
                          onPressed:
                              vision.isConnecting || vision.state.isConnected
                              ? null
                              : vision.connect,
                          child: const Text('Conectar'),
                        ),
                        GlassButton(
                          onPressed: vision.isConnecting
                              ? null
                              : vision.reconnect,
                          child: const Text('Reconectar visión'),
                        ),
                        GlassButton(
                          onPressed:
                              vision.state.isConnected || vision.isConnecting
                              ? vision.disconnect
                              : null,
                          child: const Text('Desconectar visión'),
                        ),
                      ],
                    ),
                    if (vision.state.error != null)
                      Text(
                        vision.state.error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                GlassButton(
                  expanded: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DiagnosticsScreen(),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.waveform_path_ecg),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Abrir diagnósticos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 10),
                      _NestedArrow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => 'oscuro',
    ThemeMode.light => 'claro',
    ThemeMode.system => 'sistema',
  };

  Future<void> _editWebsocket(
    BuildContext context,
    SettingsController settings,
    MachineController machine,
  ) async {
    final text = TextEditingController(text: settings.settings.websocketUrl);
    final value = await _showUrlDialog(
      context,
      text,
      (context) => AlertDialog(
        icon: const Icon(CupertinoIcons.link),
        title: const Text('Dirección WebSocket'),
        content: TextField(
          controller: text,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'ws://IP_REAL_ESP32:81/',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final uri = Uri.tryParse(text.text.trim());
              final valid =
                  uri != null &&
                  (uri.scheme == 'ws' || uri.scheme == 'wss') &&
                  uri.host.isNotEmpty;
              if (valid) Navigator.pop(context, text.text.trim());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    await machine.saveEndpointAndReconnect(value);
  }

  Future<void> _editVisionUrl(
    BuildContext context,
    SettingsController settings,
  ) async {
    final vision = context.read<VisionController>();
    final text = TextEditingController(
      text: settings.settings.visionWebsocketUrl,
    );
    final form = GlobalKey<FormState>();
    final value = await _showUrlDialog(
      context,
      text,
      (context) => AlertDialog(
        title: const Text('URL Vision Server'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: text,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'URL laptop',
              hintText: 'ws://192.168.x.x:8765/vision',
              helperText: 'Deja vacío para quitar el endpoint.',
            ),
            validator: (value) =>
                value == null ||
                    value.trim().isEmpty ||
                    RemoteVisionService.isValidUrl(value)
                ? null
                : 'Usa ws://HOST:PUERTO/vision sin query ni fragmento.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, text.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    await vision.saveEndpointAndReconnect(value);
  }

  Future<String?> _showUrlDialog(
    BuildContext context,
    TextEditingController text,
    WidgetBuilder builder,
  ) async {
    TransitionRoute<String>? route;
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          route = ModalRoute.of(dialogContext) as TransitionRoute<String>;
          return builder(dialogContext);
        },
      );
      // showDialog completes at pop; completed waits for overlay removal too.
      await route?.completed;
      if (!mounted) return null;
      return value;
    } finally {
      text.dispose();
    }
  }
}

class _VisionConnectionPanel extends StatelessWidget {
  const _VisionConnectionPanel({required this.vision, required this.onEdit});
  final VisionController vision;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = vision.state.ready ? AppColors.mint : AppColors.warning;
    return GlassPanel(
      emphasis: GlassEmphasis.prominent,
      borderColor: color.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.desktopcomputer, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visor inteligente',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Visor: ${visionConnectionLabel(vision.state)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar URL Vision Server',
                onPressed: onEdit,
                icon: const Icon(CupertinoIcons.pencil),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Dirección detectada: ${vision.detectedAddress ?? 'Sin dirección'}',
          ),
          const SizedBox(height: 5),
          Text(
            'Discovery: ${vision.discoveryStatusLabel}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 5),
          Text(
            'URL: ${vision.connectionWebsocketUrl ?? (vision.endpoint.isEmpty ? 'Sin dirección guardada' : vision.endpoint)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          GlassButton(
            onPressed: vision.isConnecting ? null : vision.searchVision,
            child: const Text('Buscar visor'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
    required this.machine,
    required this.autoReconnect,
    required this.onEdit,
  });

  final MachineController machine;
  final bool autoReconnect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final connected = machine.state.isConnected;
    final color = connected ? AppColors.mint : AppColors.warning;
    return GlassPanel(
      emphasis: GlassEmphasis.prominent,
      padding: const EdgeInsets.fromLTRB(16, 16, 13, 15),
      borderColor: color.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  CupertinoIcons.antenna_radiowaves_left_right,
                  color: color,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi ESP32',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'ESP32: ${machine.connectionStatusLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Reconectar',
                onPressed: machine.isConnecting ? null : machine.reconnect,
                icon: const Icon(CupertinoIcons.arrow_clockwise, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Red local: hotspot o router · sin depender del SSID',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Dirección: ${machine.deviceAddress ?? 'Sin dirección'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.link,
                    size: 16,
                    color: AppColors.steel,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'WebSocket: ${machine.connectionWebsocketUrl ?? 'Sin dirección guardada'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.pencil,
                    size: 15,
                    color: AppColors.steel,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: machine.isConnecting ? null : machine.searchEsp32,
            icon: const Icon(CupertinoIcons.search, size: 17),
            label: const Text('Buscar ESP32'),
          ),
          const SizedBox(height: 6),
          Text(
            machine.state.lastStatus,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 9),
          Text(
            autoReconnect
                ? 'Reconexión automática activa'
                : 'Reconexión automática desactivada',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
          const SizedBox(height: 12),
          const Esp32IdentityPanel(),
        ],
      ),
    );
  }
}

class _SettingsDisclosure extends StatelessWidget {
  const _SettingsDisclosure({
    required this.icon,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onTap,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String summary;
  final bool expanded;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: EdgeInsets.zero,
    emphasis: expanded ? GlassEmphasis.standard : GlassEmphasis.quiet,
    borderRadius: BorderRadius.circular(22),
    child: Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 37,
                  height: 37,
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.075),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.cyan),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.40),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: const Icon(CupertinoIcons.chevron_down, size: 17),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
            child: Column(
              children: [
                const Divider(height: 1),
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.accent,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.40),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: value,
          activeThumbColor: accent,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text('${(value * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.40),
          ),
        ),
        Slider(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(title)),
        const SizedBox(width: 12),
        DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            borderRadius: BorderRadius.circular(16),
            onChanged: onChanged == null
                ? null
                : (next) {
                    if (next != null) onChanged!(next);
                  },
            items: options.entries
                .map(
                  (entry) => DropdownMenuItem<T>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.40),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(CupertinoIcons.chevron_right, size: 17),
        ],
      ),
    ),
  );
}

class _NestedArrow extends StatelessWidget {
  const _NestedArrow();

  @override
  Widget build(BuildContext context) => Container(
    width: 27,
    height: 27,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.cyan.withValues(alpha: 0.12),
    ),
    child: const Icon(
      CupertinoIcons.arrow_up_right,
      size: 13,
      color: AppColors.cyan,
    ),
  );
}
