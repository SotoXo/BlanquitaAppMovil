import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../../features/settings/controller/settings_controller.dart';

enum BlanquitaModalType { info, success, warning, error, confirmation, loading }

class BlanquitaModal extends StatelessWidget {
  const BlanquitaModal({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.actions = const [],
  });
  final BlanquitaModalType type;
  final String title, message;
  final List<Widget> actions;

  static Future<T?> show<T>(
    BuildContext context, {
    required BlanquitaModalType type,
    required String title,
    required String message,
    List<Widget> Function(BuildContext)? actions,
  }) {
    final settings = context.read<SettingsController>().settings;
    final reduce = BlanquitaDesign.reduce(context, settings);
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: type != BlanquitaModalType.loading,
      barrierLabel: 'Cerrar diálogo',
      barrierColor: Colors.black54,
      transitionDuration: reduce ? Duration.zero : BlanquitaDesign.modal,
      pageBuilder: (context, _, _) => BlanquitaModal(
        type: type,
        title: title,
        message: message,
        actions:
            actions?.call(context) ??
            [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuar'),
              ),
            ],
      ),
      transitionBuilder: (context, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: BlanquitaDesign.curve,
        );
        return FadeTransition(
          opacity: curve,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: settings.glassEnabled && !reduce ? 2 * curve.value : 0,
              sigmaY: settings.glassEnabled && !reduce ? 2 * curve.value : 0,
            ),
            child: ScaleTransition(
              scale: Tween(begin: .96, end: 1.0).animate(curve),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlanquitaColors.of(context);
    final (icon, color) = switch (type) {
      BlanquitaModalType.success => (Icons.check_circle_outline, colors.mint),
      BlanquitaModalType.error => (Icons.error_outline, colors.danger),
      BlanquitaModalType.warning ||
      BlanquitaModalType.confirmation => (Icons.warning_amber, colors.warning),
      _ => (Icons.info_outline, colors.cyan),
    };
    return AlertDialog(
      scrollable: true,
      icon: type == BlanquitaModalType.loading
          ? Semantics(
              label: 'Esperando respuesta',
              child: MediaQuery.disableAnimationsOf(context)
                  ? Icon(Icons.hourglass_top, color: color, size: 40)
                  : SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: CircularProgressIndicator(color: color),
                      ),
                    ),
            )
          : Icon(icon, color: color, size: 40),
      title: Text(title),
      content: Text(message),
      actions: actions,
      actionsOverflowButtonSpacing: 8,
    );
  }
}
