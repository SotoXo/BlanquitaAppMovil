import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../features/diagnostics/presentation/diagnostics_screen.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/page_header.dart';
import '../controller/app_settings.dart';
import '../controller/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final settings = controller.settings;
    final machine = context.watch<MachineController>();
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 132),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(
                  eyebrow: 'Preferencias',
                  title: 'Ajustes',
                  subtitle:
                      'Conexión, control, apariencia, seguridad y preparación de visión.',
                ),
                const SizedBox(height: 22),
                _SettingsSection(
                  icon: Icons.router_outlined,
                  title: 'Conexión',
                  children: [
                    _ActionTile(
                      title: 'WebSocket',
                      subtitle: settings.websocketUrl,
                      icon: Icons.link_rounded,
                      onTap: () => _editWebsocket(context, controller, machine),
                    ),
                    _SwitchTile(
                      title: 'Reconexión automática',
                      subtitle:
                          'Reintentos progresivos si se pierde el enlace.',
                      value: settings.autoReconnect,
                      onChanged: controller.setAutoReconnect,
                    ),
                    _ActionTile(
                      title: 'Reconectar ahora',
                      subtitle: machine.state.lastStatus,
                      icon: Icons.refresh_rounded,
                      onTap: machine.reconnect,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  icon: Icons.gamepad_outlined,
                  title: 'Control',
                  children: [
                    _SwitchTile(
                      title: 'Feedback háptico',
                      subtitle:
                          'Vibración proporcional para movimiento y acciones.',
                      value: settings.hapticsEnabled,
                      onChanged: controller.setHapticsEnabled,
                    ),
                    _SwitchTile(
                      title: 'Confirmar secuencia',
                      subtitle: 'Pedir confirmación antes del comando j.',
                      value: settings.confirmSequence,
                      onChanged: controller.setConfirmSequence,
                    ),
                    _SliderTile(
                      title: 'Sensibilidad visual',
                      subtitle:
                          'Intensidad de respuesta del esquema cartesiano.',
                      value: settings.visualSensitivity,
                      onChanged: controller.setVisualSensitivity,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Apariencia',
                  children: [
                    _ChoiceTile<ThemeMode>(
                      title: 'Tema',
                      value: settings.themeMode,
                      options: const {
                        ThemeMode.dark: 'Oscuro',
                        ThemeMode.light: 'Claro',
                        ThemeMode.system: 'Sistema',
                      },
                      onChanged: controller.setThemeMode,
                    ),
                    _SwitchTile(
                      title: 'Liquid Glass',
                      subtitle: 'Blur moderado, bordes y reflejos sutiles.',
                      value: settings.glassEnabled,
                      onChanged: settings.performanceMode
                          ? null
                          : controller.setGlassEnabled,
                    ),
                    _ChoiceTile<GlassIntensity>(
                      title: 'Intensidad del glass',
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
                    _SwitchTile(
                      title: 'Reducir animaciones',
                      subtitle: 'Reduce transiciones y movimiento informativo.',
                      value: settings.reduceMotion,
                      onChanged: controller.setReduceMotion,
                    ),
                    _SwitchTile(
                      title: 'Modo rendimiento',
                      subtitle:
                          'Desactiva blur y reduce sombras para reservar GPU.',
                      value: settings.performanceMode,
                      onChanged: controller.setPerformanceMode,
                      accent: AppColors.mint,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Seguridad',
                  children: [
                    _SwitchTile(
                      title: 'Mostrar advertencias',
                      subtitle:
                          'Banners persistentes para estados importantes.',
                      value: settings.showWarnings,
                      onChanged: controller.setShowWarnings,
                    ),
                    _SwitchTile(
                      title: 'Feedback fuerte en final de carrera',
                      subtitle: 'Una vibración fuerte al activarse el bloqueo.',
                      value: settings.strongLimitFeedback,
                      onChanged: controller.setStrongLimitFeedback,
                    ),
                    _SwitchTile(
                      title: 'Alertas de pérdida de conexión',
                      subtitle: 'Mantiene visible el estado del enlace.',
                      value: settings.connectionLossAlerts,
                      onChanged: controller.setConnectionLossAlerts,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  icon: Icons.center_focus_strong_rounded,
                  title: 'Visión',
                  children: [
                    _ActionTile(
                      title: 'Cámara',
                      subtitle: settings.cameraName,
                      icon: Icons.videocam_off_outlined,
                      onTap: () => _visionNotConfigured(context),
                    ),
                    _ChoiceTile<int>(
                      title: 'FPS objetivo',
                      value: settings.visionTargetFps,
                      options: const {15: '15 FPS', 24: '24 FPS', 30: '30 FPS'},
                      onChanged: controller.setVisionTargetFps,
                    ),
                    const _ActionTile(
                      title: 'Calibración',
                      subtitle: 'No configurada',
                      icon: Icons.grid_4x4_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                      Icon(Icons.monitor_heart_outlined),
                      SizedBox(width: 10),
                      Text('Abrir diagnósticos'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
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

  Future<void> _editWebsocket(
    BuildContext context,
    SettingsController settings,
    MachineController machine,
  ) async {
    final text = TextEditingController(text: settings.settings.websocketUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.router_outlined),
        title: const Text('Dirección WebSocket'),
        content: TextField(
          controller: text,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'ws://192.168.4.1:81/',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
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
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value == null || !context.mounted) return;
    await settings.setWebsocketUrl(value);
    await machine.reconnect();
  }

  void _visionNotConfigured(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Visión no configurada'),
        content: const Text(
          'La selección de cámara se habilitará al integrar una fuente real de video. No se simulan detecciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
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
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    activeThumbColor: accent,
    onChanged: onChanged,
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
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
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        Slider(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
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
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    trailing: DropdownButtonHideUnderline(
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
  );
}
