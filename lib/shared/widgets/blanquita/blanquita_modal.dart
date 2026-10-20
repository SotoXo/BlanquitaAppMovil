import '../../../features/assistant/presentation/alfresi_avatar.dart';
import '../../../features/assistant/domain/alfresi_message.dart';
import '../../../features/settings/controller/app_settings.dart';
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
      BlanquitaModalType.loading => (
        Icons.pending_outlined,
        BlanquitaColors.info,
      ),
      BlanquitaModalType.error => (Icons.error_outline, colors.danger),
      BlanquitaModalType.warning ||
      BlanquitaModalType.confirmation => (Icons.warning_amber, colors.warning),
      _ => (Icons.info_outline, colors.cyan),
    };
    final settings = context.watch<SettingsController>().settings;
    final reduce = BlanquitaDesign.reduce(context, settings);
    if (settings.visualTheme != BlanquitaVisualTheme.original) {
      final mood = switch (type) {
        BlanquitaModalType.success => AlfresiMood.success,
        BlanquitaModalType.error => AlfresiMood.error,
        BlanquitaModalType.loading => AlfresiMood.thinking,
        BlanquitaModalType.warning ||
        BlanquitaModalType.confirmation => AlfresiMood.warning,
        _ => AlfresiMood.idle,
      };
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(BlanquitaSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (settings.assistantEnabled)
                  AlfresiAvatar(size: 96, mood: mood),
                const SizedBox(height: BlanquitaSpacing.md),
                Container(
                  padding: BlanquitaSpacing.card,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      color.withValues(alpha: .10),
                      colors.graphite,
                    ),
                    borderRadius: BlanquitaRadius.card,
                    border: Border.all(color: color.withValues(alpha: .65)),
                    boxShadow:
                        settings.shadowsEnabled && !settings.performanceMode
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: .1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        label: type == BlanquitaModalType.loading
                            ? 'Esperando respuesta'
                            : title,
                        child: Icon(
                          type == BlanquitaModalType.loading
                              ? Icons.pending_outlined
                              : icon,
                          color: color,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: BlanquitaSpacing.md),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: BlanquitaSpacing.sm),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (type == BlanquitaModalType.loading) ...[
                        const SizedBox(height: BlanquitaSpacing.lg),
                        if (reduce)
                          Semantics(
                            label: 'Esperando respuesta; progreso no informado',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < 3; i++)
                                  Padding(
                                    padding: const EdgeInsets.all(
                                      BlanquitaSpacing.xs,
                                    ),
                                    child: Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: color,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        else
                          LinearProgressIndicator(
                            color: color,
                            backgroundColor: color.withValues(alpha: .15),
                            borderRadius: BlanquitaRadius.card,
                          ),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: BlanquitaSpacing.xl),
                        OverflowBar(
                          alignment: MainAxisAlignment.center,
                          overflowAlignment: OverflowBarAlignment.center,
                          spacing: 8,
                          overflowSpacing: 8,
                          children: actions,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      scrollable: true,
      icon: type == BlanquitaModalType.loading
          ? Semantics(
              label: 'Esperando respuesta',
              child: reduce
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
