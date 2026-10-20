import 'dart:async';
import 'package:flutter/material.dart';
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
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ConnectionProgress(device: device, check: check, cancel: cancel),
  );
  if (!context.mounted || result == null) return;
  await BlanquitaModal.show<void>(
    context,
    type: result ? BlanquitaModalType.success : BlanquitaModalType.error,
    title: result ? 'Conectado' : 'No se pudo conectar',
    message: result
        ? '$device confirmó READY. La conexión está disponible.'
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
  });
  final String device;
  final Future<bool> Function() check;
  final Future<void> Function() cancel;
  @override
  State<_ConnectionProgress> createState() => _ConnectionProgressState();
}

class _ConnectionProgressState extends State<_ConnectionProgress> {
  bool _cancelled = false;
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    bool ready;
    try {
      ready = await widget.check();
    } catch (_) {
      ready = false;
    }
    if (mounted && !_cancelled) Navigator.pop(context, ready);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: BlanquitaModal(
      type: BlanquitaModalType.loading,
      title: 'Procesando',
      message: 'Estamos esperando la respuesta de ${widget.device}.',
      actions: [
        TextButton(
          onPressed: () {
            _cancelled = true;
            unawaited(widget.cancel());
            Navigator.pop(context);
          },
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
}
