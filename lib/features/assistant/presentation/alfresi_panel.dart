import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/diagnostics/connection_log.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../vision/controller/vision_controller.dart';
import '../../settings/controller/settings_controller.dart';
import '../../diagnostics/presentation/diagnostics_screen.dart';
import '../domain/alfresi_context.dart';
import '../domain/alfresi_message.dart';
import '../services/alfresi_rules.dart';
import 'alfresi_avatar.dart';

class AlfresiButton extends StatelessWidget {
  const AlfresiButton({super.key, required this.section});
  final String section;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>().settings;
    if (!s.assistantEnabled) return const SizedBox.shrink();
    final c = AlfresiContext.read(
      context.watch<MachineController>(),
      context.watch<VisionController>(),
      section,
    );
    final message = AlfresiRules.explain(c);
    return Tooltip(
      message: 'Abrir ALFRESI',
      child: Semantics(
        button: true,
        label: 'Abrir ALFRESI, tu asistente BLANQUITA',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (_) => AlfresiPanel(section: section),
            ),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: AlfresiAvatar(
                mood: s.assistantAlerts ? message.mood : AlfresiMood.idle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AlfresiPanel extends StatelessWidget {
  const AlfresiPanel({super.key, required this.section});
  final String section;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>().settings;
    final c = AlfresiContext.read(
      context.watch<MachineController>(),
      context.watch<VisionController>(),
      section,
    );
    final message = AlfresiRules.explain(c);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  AlfresiAvatar(mood: message.mood, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALFRESI',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text('Tu asistente BLANQUITA'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar ALFRESI',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                Tab(text: 'Resumen'),
                Tab(text: 'Diagnóstico'),
                Tab(text: 'Ayuda'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Semantics(
                        liveRegion: s.assistantAlerts,
                        child: Text(
                          message.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(redactConnectionText(message.body)),
                      const SizedBox(height: 20),
                      ExpansionTile(
                        title: const Text('¿Por qué?'),
                        children: [
                          for (final entry in c.evidence.entries)
                            ListTile(
                              title: Text(entry.key),
                              subtitle: Text(entry.value),
                            ),
                        ],
                      ),
                      if (s.assistantTechnical)
                        ExpansionTile(
                          title: const Text('Ver detalles técnicos'),
                          children: [
                            ListTile(
                              title: const Text('Fase ESP32'),
                              subtitle: Text(c.phase),
                            ),
                          ],
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Último problema',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        redactConnectionText(
                          c.machine.connectionError ??
                              c.vision.error ??
                              (c.machine.finalLimitActive == true
                                  ? 'Final de carrera activo.'
                                  : 'No hay errores de conexión registrados en el estado actual.'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const DiagnosticsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.monitor_heart_outlined),
                        label: const Text('Ver detalles'),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        section,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s.assistantTips
                            ? AlfresiRules.help(section)
                            : 'Los consejos contextuales están desactivados en Ajustes.',
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'ALFRESI explica los estados mediante reglas locales. No envía órdenes al robot. Las acciones físicas se realizan desde Control.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
