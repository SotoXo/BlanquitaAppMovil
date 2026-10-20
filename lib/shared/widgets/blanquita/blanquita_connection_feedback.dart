import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../../features/settings/controller/settings_controller.dart';
import '../../../core/diagnostics/connection_log.dart';
import '../../../features/diagnostics/presentation/diagnostics_screen.dart';
import 'blanquita_modal.dart';

/// Presents the existing asynchronous connection check, without implementing it.
Future<void> showConnectionFeedback(
  BuildContext context, {
  required String device,
  required Future<bool> Function() check,
  required Future<void> Function() cancel,
  required String? Function() error,
  Listenable? progress,
  String Function()? progressMessage,
}) async {
  final reduce = BlanquitaDesign.reduce(
    context,
    context.read<SettingsController>().settings,
  );
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Comprobando conexión',
    transitionDuration: reduce ? Duration.zero : BlanquitaMotion.modal,
    pageBuilder: (_, _, _) => _ConnectionProgress(
      device: device,
      check: check,
      cancel: cancel,
      progress: progress,
      progressMessage: progressMessage,
    ),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation.drive(CurveTween(curve: BlanquitaMotion.curve)),
      child: child,
    ),
  );
  if (!context.mounted || result == null) return;
  await BlanquitaModal.show<void>(
    context,
    type: result ? BlanquitaModalType.success : BlanquitaModalType.error,
    title: result ? 'Conectado' : 'No se pudo conectar',
    message: result
        ? '$device confirmó que está listo. La conexión está disponible.'
        : redactConnectionText(
            error() ??
                '$device no confirmó READY. Consulta el diagnóstico para conocer la fase observada.',
          ),
    actions: (dialogContext) => [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Cerrar'),
      ),
      if (!result)
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DiagnosticsScreen(),
              ),
            );
          },
          child: const Text('Diagnóstico'),
        ),
      if (!result)
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            unawaited(
              showConnectionFeedback(
                context,
                device: device,
                check: check,
                cancel: cancel,
                error: error,
                progress: progress,
                progressMessage: progressMessage,
              ),
            );
          },
          child: const Text('Reintentar'),
        ),
    ],
  );
}

class _ConnectionProgress extends StatefulWidget {
  const _ConnectionProgress({
    required this.device,
    required this.check,
    required this.cancel,
    this.progress,
    this.progressMessage,
  });
  final String device;
  final Future<bool> Function() check;
  final Future<void> Function() cancel;
  final Listenable? progress;
  final String Function()? progressMessage;
  @override
  State<_ConnectionProgress> createState() => _ConnectionProgressState();
}

class _ConnectionProgressState extends State<_ConnectionProgress> {
  bool _cancelled = false;
  bool _cancelling = false;
  bool _slow = false;
  bool _cancelFailed = false;
  Timer? _waitNotice;
  @override
  void initState() {
    super.initState();
    _waitNotice = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _slow = true);
    });
    // Controllers can notify synchronously; start once the dialog is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_cancelled) unawaited(_run());
    });
  }

  Future<void> _run() async {
    bool ready;
    try {
      ready = await widget.check();
    } catch (exception) {
      ready = false;
      ConnectionLog.shared.add(
        channel: ConnectionChannel.system,
        level: ConnectionLogLevel.error,
        humanMessage:
            'No se pudo completar la comprobación de ${widget.device}.',
        technicalMessage: 'connection_check: ${exception.runtimeType}',
      );
    }
    if (mounted && !_cancelled) Navigator.pop(context, ready);
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() {
      _cancelled = true;
      _cancelling = true;
    });
    try {
      await widget.cancel();
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      ConnectionLog.shared.add(
        channel: ConnectionChannel.system,
        level: ConnectionLogLevel.error,
        humanMessage: 'No se pudo confirmar el cierre de ${widget.device}.',
        technicalMessage: 'connection_cancel: ${exception.runtimeType}',
      );
      if (mounted) {
        setState(() {
          _cancelling = false;
          _cancelFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    return progress == null
        ? _dialog()
        : ListenableBuilder(listenable: progress, builder: (_, _) => _dialog());
  }

  Widget _dialog() => PopScope(
    canPop: false,
    child: BlanquitaModal(
      type: _cancelFailed
          ? BlanquitaModalType.error
          : BlanquitaModalType.loading,
      title: _cancelFailed
          ? 'Revisa la conexión'
          : _cancelling
          ? 'Cancelando…'
          : 'Conectando con ${widget.device}',
      message: _cancelFailed
          ? 'No pudimos confirmar el cierre. Revisa el estado de ${widget.device} en Diagnósticos antes de volver a conectar.'
          : _cancelling
          ? 'Cerrando el intento de conexión…'
          : '${widget.progressMessage?.call() ?? 'Estamos esperando la respuesta de ${widget.device}.'}'
                '${_slow ? '\n\nEstá tardando más de lo habitual. Comprueba que el equipo esté encendido y en la misma red. Puedes cancelar e intentarlo de nuevo.' : ''}',
      actions: [
        TextButton(
          onPressed: _cancelling
              ? null
              : _cancelFailed
              ? () => Navigator.pop(context)
              : _cancel,
          child: Text(
            _cancelFailed
                ? 'Cerrar'
                : _cancelling
                ? 'Cancelando…'
                : 'Cancelar',
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _waitNotice?.cancel();
    super.dispose();
  }
}
