import '../../../shared/widgets/final_limits_panel.dart';
import '../../../app/presentation/controller_ui_context.dart';
import '../../assistant/presentation/alfresi_bubble.dart';
import '../../assistant/domain/alfresi_context.dart';
import '../../assistant/services/alfresi_rules.dart';
import '../../settings/controller/settings_controller.dart';
import '../../settings/controller/app_settings.dart';
import '../../../shared/widgets/blanquita/blanquita_scaffold.dart';
import '../../../shared/widgets/blanquita/blanquita_components.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/design/blanquita_design.dart';
import '../../../core/diagnostics/connection_log.dart';
import '../../../core/models/machine_state.dart';
import '../../../core/network/connection_failure.dart';
import '../../../core/network/wifi_network_controller.dart';
import '../../../core/websocket/machine_controller.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/wifi_network_panel.dart';
import '../../vision/controller/vision_controller.dart';
import '../../vision/presentation/vision_widgets.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key, this.initialView = 0, this.journal});
  final ConnectionLog? journal;
  final int initialView;
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late int _view = widget.initialView;

  @override
  Widget build(BuildContext context) {
    final machine = context.watch<MachineController>();
    final vision = context.watch<VisionController>();
    final wifi = context.watch<WifiNetworkController>();
    final settings = context.watch<SettingsController>().settings;
    final warm = settings.visualTheme != BlanquitaVisualTheme.original;
    final state = machine.state;
    final vs = vision.state;
    final controlEndpoint = EndpointValidation.parse(
      machine.settingsWebsocketUrl,
    );
    final visionEndpoint = EndpointValidation.parse(vision.endpoint);
    final control = <String, String>{
      'Estado': _controlLabel(state),
      ..._endpointRows(machine.settingsWebsocketUrl),
      'Fase': machine.phase,
      'Transporte': machine.transportOpen ? 'Abierto' : 'Cerrado',
      'Protocolo': machine.protocolReady ? 'READY confirmado' : 'Sin READY',
      'Último RX': state.lastMessage ?? '—',
      'Último TX': state.lastCommand ?? '—',
      'Última recepción': _reception(state.lastReceivedAt),
      'Intento de reconexión': '${machine.reconnectAttempts ?? 'No informado'}',
      'Último error': state.connectionError ?? 'Sin error registrado',
      'Código': machine.lastErrorCode ?? '—',
    };
    final visionRows = <String, String>{
      'Estado': vs.ready ? 'Lista' : visionConnectionLabel(vs),
      ..._endpointRows(vision.endpoint),
      'Fase': vision.phase,
      'Transporte': vision.transportOpen ? 'Abierto' : 'Cerrado',
      'Protocolo': vs.ready ? 'vision.ready confirmado' : 'Sin ready efectivo',
      'Último RX': vs.lastMessage ?? '—',
      'Último TX': vision.lastCommand ?? '—',
      'Última recepción': _reception(vs.lastMessageAt),
      'Intento de reconexión': '${vision.reconnectAttempts}',
      'Último error': vs.error ?? 'Sin error registrado',
      'Categoría': vision.lastFailure?.category ?? '—',
      'Estado interno': vision.networkPhase.label,
      'Intento actual': '${vision.connectionAttempt}',
      'IP detectada': vision.detectedAddress ?? '—',
      'Puerto detectado': '${vision.detectedPort ?? '—'}',
      'URI efectiva': redactConnectionText(
        vision.connectionWebsocketUrl ?? '—',
      ),
      'Primera excepción': redactConnectionText(
        vision.firstFailure?.toString() ?? 'Sin excepción registrada',
      ),
      'Último HTTP': '${vision.lastFailure?.httpStatus ?? '—'}',
    };

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: warm
            ? null
            : AppBar(
                backgroundColor: Colors.transparent,
                title: const Text('Diagnósticos'),
              ),
        body: SafeArea(
          top: warm,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (warm)
                      const BlanquitaHeader(title: 'Diagnósticos', back: true)
                    else
                      const PageHeader(
                        eyebrow: 'Telemetría local',
                        title: 'Diagnósticos',
                        subtitle:
                            'Control ESP32 y visión de la laptop tienen sesiones independientes. Red esperada: CARTESIANO o una LAN común.',
                      ),
                    if (warm &&
                        settings.assistantEnabled &&
                        settings.assistantTips) ...[
                      AlfresiBubble(
                        message: AlfresiRules.explain(
                          AlfresiContext.read(machine, vision, 'Diagnósticos'),
                        ).title,
                      ),
                      const SizedBox(height: BlanquitaSpacing.md),
                    ],
                    const SizedBox(height: 20),
                    BlanquitaSegmentedControl<int>(
                      value: _view,
                      options: const {0: 'Conexiones', 1: 'Sistema', 2: 'Logs'},
                      onChanged: (value) => setState(() => _view = value),
                    ),
                    const SizedBox(height: 16),
                    if (_view == 0) ...[
                      FinalLimitsPanel(
                        limits: state.finalLimits,
                        awaitingRelease: machine.awaitingMovementRelease,
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('Canal WebSocket ESP32'),
                      const Text('Vision Server'),
                      SwitchListTile(
                        title: const Text(
                          'Diagnóstico sin reconexión automática',
                        ),
                        value: vision.diagnosticMode,
                        onChanged: vision.setDiagnosticMode,
                      ),
                      const WifiNetworkPanel(),
                      const SizedBox(height: 14),
                      _ResponsivePair(
                        first: _ConnectionCard(
                          title: 'ESP32 · CONTROL',
                          icon: CupertinoIcons.antenna_radiowaves_left_right,
                          rows: control,
                          error: state.connectionError,
                          technical: machine.lastTechnicalError,
                          hint: _errorHint(
                            machine.lastErrorCode,
                            control: true,
                          ),
                          probing: wifi.probing,
                          probe:
                              wifi.status.connected &&
                                  !wifi.probing &&
                                  controlEndpoint != null
                              ? () => _probeWifiPort(
                                  context,
                                  wifi,
                                  controlEndpoint,
                                  'el ESP32',
                                )
                              : null,
                        ),
                        second: _ConnectionCard(
                          title: 'Laptop · VISIÓN',
                          icon: CupertinoIcons.eye,
                          rows: visionRows,
                          error: vs.error,
                          technical: vision.lastTechnicalError,
                          hint: _errorHint(
                            vision.lastErrorCode,
                            control: false,
                          ),
                          probing: wifi.probing,
                          probe:
                              wifi.status.connected &&
                                  !wifi.probing &&
                                  visionEndpoint != null
                              ? () => _probeWifiPort(
                                  context,
                                  wifi,
                                  visionEndpoint,
                                  'la laptop',
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ConnectionGuidance(machine: machine, vision: vision),
                      const SizedBox(height: 14),
                    ],
                    if (_view == 2)
                      _ConnectionJournal(
                        control: control,
                        vision: visionRows,
                        wifi: wifi.snapshot,
                        source: widget.journal,
                      ),
                    const SizedBox(height: 24),
                    if (_view == 1) ...[
                      FinalLimitsPanel(
                        limits: state.finalLimits,
                        awaitingRelease: machine.awaitingMovementRelease,
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('Telemetría del ESP32'),
                      const SizedBox(height: 10),
                      _ResponsivePair(
                        first: VisionReadouts(
                          title: 'Sensores',
                          rows: {
                            'Plato': _boolLabel(
                              state.plateDetected,
                              'Detectado',
                              'Libre',
                            ),
                            'Resumen de finales': _boolLabel(
                              state.finalLimitActive,
                              'Activado',
                              'Libre',
                            ),
                            'Último paquete': state.lastSensorPacket ?? '—',
                          },
                        ),
                        second: VisionReadouts(
                          title: 'Máquina',
                          rows: {
                            'Movimiento':
                                state.activeMovement?.label ?? 'Detenido',
                            'Secuencia': state.sequence.name,
                            'Paso': state.sequenceStep?.toString() ?? '—',
                            'Pinza': state.gripper.name,
                            'Estado': state.lastStatus,
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      VisionReadouts(
                        title: 'Telemetría de visión',
                        rows: {
                          'Último heartbeat': _reception(vs.lastHeartbeat),
                          'Último reporte': visionTime(
                            vs.lastReport?.timestamp,
                          ),
                          'ID reporte': vs.lastReport?.id ?? '—',
                          'Edad reporte': visionAge(vs.reportAge),
                          'Heartbeat vencido': vs.stale ? 'Sí' : 'No',
                          'Reporte caducado': vs.reportStale ? 'Sí' : 'No',
                          'Latencia': vs.latency == null
                              ? '—'
                              : '${vs.latency!.toStringAsFixed(1)} ms',
                          'Cámara': visionStatusLabel(vs.cameraStatus),
                          'Nombre cámara': vs.cameraName ?? '—',
                          'Detector': visionStatusLabel(vs.detectorStatus),
                          'Calibración': visionStatusLabel(
                            vs.calibrationStatus,
                          ),
                        },
                      ),
                      const SizedBox(height: 14),
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Eventos de máquina',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            if (machine.events.isEmpty)
                              const Text('Sin eventos registrados'),
                            for (final event in machine.events.take(20))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '${visionTime(event.timestamp)} · ${event.level.name.toUpperCase()} · ${event.message}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 680
        ? Column(children: [first, const SizedBox(height: 14), second])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 14),
              Expanded(child: second),
            ],
          ),
  );
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.title,
    required this.icon,
    required this.rows,
    this.error,
    this.technical,
    this.hint,
    this.probe,
    this.probing = false,
  });
  final String title;
  final IconData icon;
  final Map<String, String> rows;
  final String? error;
  final String? technical;
  final String? hint;
  final VoidCallback? probe;
  final bool probing;

  @override
  Widget build(BuildContext context) => GlassPanel(
    emphasis: GlassEmphasis.prominent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: BlanquitaColors.of(context).cyan),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final entry in rows.entries.where(
          (entry) => entry.key != 'Último error',
        ))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: BlanquitaColors.of(context).steel,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  redactConnectionText(entry.value),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Último error',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: BlanquitaColors.of(context).steel,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: error != null,
          child: Text(
            error ?? 'Sin error registrado',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: error == null
                  ? BlanquitaColors.of(context).steel
                  : BlanquitaColors.of(context).warning,
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text('¿Qué pasó?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            hint ??
                'Consulta la fase, la dirección configurada y el detalle técnico antes de atribuir una causa.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (technical != null) _TechnicalDetails(text: technical!),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: probe,
          icon: const Icon(CupertinoIcons.wifi, size: 18),
          label: Text(
            probing ? 'Verificando puerto…' : 'Verificar puerto por Wi-Fi',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Prueba TCP del host y puerto configurados por Wi-Fi. No valida WebSocket ni READY y no envía comandos físicos. El resultado se registra en la bitácora.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: BlanquitaColors.of(context).steel,
          ),
        ),
      ],
    ),
  );
}

class _ConnectionGuidance extends StatelessWidget {
  const _ConnectionGuidance({required this.machine, required this.vision});
  final MachineController machine;
  final VisionController vision;

  @override
  Widget build(BuildContext context) {
    final guidance = <String>[];
    if (machine.lastErrorCode == 'READY_TIMEOUT') {
      guidance.add(
        'El WebSocket del ESP32 abrió durante el intento, pero faltó READY. Revisa el protocolo del firmware.',
      );
    }
    if (vision.lastErrorCode == 'READY_TIMEOUT' ||
        vision.lastErrorCode == 'VISION_READY_TIMEOUT') {
      guidance.add(
        'El WebSocket de la laptop abrió durante el intento, pero faltó vision.ready. Revisa el protocolo del Vision Server.',
      );
    }
    if (machine.state.isConnected && vision.state.ready) {
      guidance.add(
        'Ambos enlaces están disponibles: el ESP32 confirmó READY y la laptop confirmó vision.ready sin vencimiento de heartbeat detectado.',
      );
    } else if (machine.state.isConnected && !vision.state.ready) {
      guidance.add(
        'El control del robot está disponible. Revisa por separado la dirección y el estado del servidor de visión.',
      );
    } else if (vision.state.ready && !machine.state.isConnected) {
      guidance.add(
        'La laptop es accesible. El ESP32 aún no está validado: revisa su dirección, puerto y servidor WebSocket.',
      );
    } else if (_isNetworkFailure(machine.lastErrorCode) &&
        _isNetworkFailure(vision.lastErrorCode)) {
      guidance.add(
        'Ambos canales registraron fallos de transporte. Posible causa: conectividad de la red local. Comprueba que los tres dispositivos pertenezcan a la misma LAN y revisa aislamiento de clientes.',
      );
    }
    if (guidance.isEmpty) {
      guidance.add(
        'Configura dos direcciones independientes en Ajustes. Un socket abierto requiere además la confirmación de protocolo de su servidor.',
      );
    }
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Orientación según el estado observado',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final line in guidance)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, style: Theme.of(context).textTheme.bodySmall),
            ),
          Text(
            'La app no lee el SSID. Un timeout por sí solo no identifica una IP incorrecta, un equipo apagado o aislamiento de clientes.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BlanquitaColors.of(context).steel,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionJournal extends StatelessWidget {
  const _ConnectionJournal({
    required this.control,
    required this.vision,
    required this.wifi,
    this.source,
  });
  final Map<String, String> control;
  final Map<String, String> vision;
  final Map<String, String> wifi;
  final ConnectionLog? source;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: source ?? ConnectionLog.shared,
    builder: (context, _) {
      final log = source ?? ConnectionLog.shared;
      return GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bitácora de conexión',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${log.entries.length} eventos en memoria. Copia el estado y los eventos para compartir el diagnóstico.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BlanquitaColors.of(context).steel,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 18),
                  label: const Text('COPIAR BITÁCORA'),
                  onPressed: () async {
                    final snapshot = log.export(
                      app: {
                        'Nombre': 'BLANQUITA Víctor',
                        'Plataforma': Theme.of(context).platform.name,
                        'Red esperada':
                            'CARTESIANO o LAN común (SSID no leído)',
                        ...wifi,
                      },
                      control: control,
                      vision: vision,
                    );
                    try {
                      await Clipboard.setData(ClipboardData(text: snapshot));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Bitácora copiada. Puedes pegarla para diagnóstico.',
                            ),
                          ),
                        );
                      }
                    } catch (error, stack) {
                      log.add(
                        channel: ConnectionChannel.system,
                        level: ConnectionLogLevel.error,
                        humanMessage:
                            'No se pudo copiar la bitácora al portapapeles.',
                        technicalMessage:
                            '${error.runtimeType}: $error\n$stack',
                        errorCode: 'COPY_FAILED',
                        phase: 'clipboard_export',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No se pudo copiar la bitácora al portapapeles. Inténtalo de nuevo.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BlanquitaColors.of(context).danger,
                  ),
                  icon: const Icon(CupertinoIcons.trash, size: 18),
                  label: const Text('LIMPIAR'),
                  onPressed: log.entries.isEmpty ? null : log.clear,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (log.entries.isEmpty)
              const Text('Sin eventos de conexión registrados.'),
            for (final entry in log.entries)
              _ConnectionLogLine(key: ValueKey(entry), entry: entry),
          ],
        ),
      );
    },
  );
}

class _ConnectionLogLine extends StatelessWidget {
  const _ConnectionLogLine({super.key, required this.entry});
  final ConnectionLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      ConnectionLogLevel.info => BlanquitaColors.of(context).cyan,
      ConnectionLogLevel.success => BlanquitaColors.of(context).mint,
      ConnectionLogLevel.warning => BlanquitaColors.of(context).warning,
      ConnectionLogLevel.error ||
      ConnectionLogLevel.critical => BlanquitaColors.of(context).danger,
    };
    final technical = [
      if (entry.errorCode != null) 'ERROR_CODE=${entry.errorCode}',
      if (entry.endpoint != null) 'endpoint=${entry.endpoint}',
      if (entry.phase != null) 'phase=${entry.phase}',
      if (entry.attempt != null) 'attempt=${entry.attempt}',
      entry.technicalMessage,
    ].join('\n');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color.withValues(alpha: .5), width: 2),
          bottom: BorderSide(
            color: BlanquitaColors.of(context).steel.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${visionTime(entry.timestamp)}  ${entry.channel.name.toUpperCase()}  ${entry.level.name.toUpperCase()}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.humanMessage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (technical.isNotEmpty) _TechnicalDetails(text: technical),
        ],
      ),
    );
  }
}

class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    title: Text(
      'Detalles técnicos',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: BlanquitaColors.of(context).cyan),
    ),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}

Map<String, String> _endpointRows(String endpoint) {
  final uri = EndpointValidation.parse(endpoint);
  return {
    'Endpoint': endpoint.isEmpty
        ? 'Sin configurar'
        : redactConnectionText(endpoint),
    'IP/Host': uri?.host.isNotEmpty == true ? uri!.host : '—',
    'Puerto': uri?.host.isNotEmpty == true
        ? '${uri!.hasPort
              ? uri.port
              : uri.scheme == 'wss'
              ? 443
              : 80}'
        : '—',
  };
}

String _controlLabel(MachineState state) => switch (state.connection) {
  ConnectionPhase.connected => 'Conectado · control disponible',
  ConnectionPhase.connecting => 'Conectando · control bloqueado',
  ConnectionPhase.error => 'Error de conexión · control bloqueado',
  ConnectionPhase.disconnected => 'Desconectado · control bloqueado',
};

String _reception(DateTime? value) => value == null
    ? 'Sin recepción'
    : '${value.toLocal().toIso8601String()} (local)';

Future<void> _probeWifiPort(
  BuildContext context,
  WifiNetworkController wifi,
  Uri endpoint,
  String deviceLabel,
) async {
  try {
    final result = await wifi.probeEndpoint(endpoint, deviceLabel: deviceLabel);
    if (!context.mounted || result['errorCode'] == 'PROBE_CANCELLED') return;
    final human = result['humanMessage'];
    final message = human is String && human.isNotEmpty
        ? human
        : result['connected'] == true
        ? 'El puerto de $deviceLabel acepta TCP por Wi-Fi. Falta confirmar el protocolo WebSocket.'
        : 'No se completó la comprobación del puerto de $deviceLabel por Wi-Fi. Consulta la bitácora.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  } catch (error, stack) {
    ConnectionLog.shared.add(
      channel: ConnectionChannel.network,
      level: ConnectionLogLevel.error,
      humanMessage:
          'No se pudo completar la comprobación del puerto por Wi-Fi.',
      technicalMessage: '${error.runtimeType}: $error\n$stack',
      errorCode: 'WIFI_PROBE_FAILED',
      endpoint: endpoint.toString(),
      phase: 'wifi_tcp_probe',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La comprobación del puerto no terminó. Consulta la bitácora.',
          ),
        ),
      );
    }
  }
}

String _boolLabel(bool? value, String yes, String no) => value == null
    ? 'Sin datos'
    : value
    ? yes
    : no;

bool _isNetworkFailure(String? code) => {
  'CONNECT_TIMEOUT',
  'HOST_UNREACHABLE',
  'CONNECTION_REFUSED',
  'TRANSPORT_ERROR',
  'HANDSHAKE_FAILED',
}.contains(code);

String? _errorHint(String? code, {required bool control}) => switch (code) {
  'INVALID_ENDPOINT' || 'EMPTY_ENDPOINT' =>
    'Edita la dirección en Ajustes. Usa ws:// o wss://, un host y el puerto del servidor correspondiente.',
  'READY_TIMEOUT' || 'VISION_READY_TIMEOUT' =>
    control
        ? 'El transporte abrió, pero no se recibió READY a tiempo. Posible causa: protocolo del firmware incompatible o confirmación ausente.'
        : 'El transporte abrió, pero faltó vision.ready. Comprueba el protocolo del Vision Server.',
  'CONNECTION_REFUSED' =>
    'El destino rechazó la conexión. Comprueba IP, puerto y que el servidor WebSocket esté escuchando; este resultado no identifica por sí solo el dispositivo.',
  'HOST_UNREACHABLE' =>
    'Comprueba la red local de ambos equipos y el aislamiento de clientes del router/hotspot. El destino no fue alcanzable desde el móvil.',
  'CONNECT_TIMEOUT' =>
    'No se completó la apertura en el tiempo permitido. Revisa IP, puerto, equipo encendido y pertenencia a la misma red local.',
  'HEARTBEAT_TIMEOUT' =>
    'La laptop dejó de enviar heartbeat a tiempo. Revisa la actividad del servidor; el socket abierto no demuestra telemetría vigente.',
  'REMOTE_CLOSED' =>
    'El extremo remoto cerró la sesión. Consulta el cierre registrado y el siguiente intento de reconexión.',
  _ => null,
};
