import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/design/blanquita_design.dart';
import '../../../features/settings/controller/settings_controller.dart';
import '../../../features/assistant/presentation/alfresi_panel.dart';
import '../app_background.dart';

class BlanquitaScaffold extends StatelessWidget {
  const BlanquitaScaffold({
    super.key,
    required this.title,
    required this.children,
    this.back = false,
    this.header = true,
  });
  final String title;
  final List<Widget> children;
  final bool back, header;
  @override
  Widget build(BuildContext context) {
    final d = BlanquitaDesign.density(
      context.watch<SettingsController>().settings,
    );
    final content = SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: BlanquitaSpacing.page * d,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header) BlanquitaHeader(title: title, back: back),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
    return back
        ? AppBackground(
            child: Scaffold(backgroundColor: Colors.transparent, body: content),
          )
        : content;
  }
}

class BlanquitaHeader extends StatelessWidget {
  const BlanquitaHeader({
    super.key,
    required this.title,
    this.back = false,
    this.trailing,
  });
  final String title;
  final bool back;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BlanquitaSpacing.md),
    child: Row(
      children: [
        if (back) const BackButton(),
        Expanded(
          child: Text(
            title,
            style: title == 'BLANQUITA'
                ? Theme.of(context).textTheme.headlineSmall
                : Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        ?trailing,
        AlfresiButton(section: title == 'BLANQUITA' ? 'Inicio' : title),
      ],
    ),
  );
}
