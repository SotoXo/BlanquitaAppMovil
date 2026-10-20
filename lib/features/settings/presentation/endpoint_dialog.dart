import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The route owns these editing resources until its closing animation finishes.
class EndpointDialog extends StatefulWidget {
  const EndpointDialog({
    super.key,
    required this.title,
    required this.label,
    required this.initialValue,
    required this.hint,
    this.validator,
  });

  final String title;
  final String label;
  final String initialValue;
  final String hint;
  final FormFieldValidator<String>? validator;

  static String? validate(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;
    final uri = Uri.tryParse(input);
    if (uri == null ||
        (uri.scheme != 'ws' && uri.scheme != 'wss') ||
        uri.host.isEmpty ||
        RegExp(r'\s').hasMatch(input)) {
      return 'Introduce una URL ws:// o wss:// válida.';
    }
    if (['0.0.0.0', '::', '[::]'].contains(uri.host)) {
      return '0.0.0.0 / :: es una dirección de escucha. Escribe la IP real del dispositivo.';
    }
    try {
      // Uri treats :0 as the default for ws/wss and can drop hasPort.
      final authority = RegExp(
        r'^[^:]+://([^/?#]+)',
      ).firstMatch(input)?.group(1);
      final portText = authority == null
          ? null
          : RegExp(r':(\d+)$').firstMatch(authority)?.group(1);
      final explicitPort = portText == null ? null : int.tryParse(portText);
      if ((uri.hasPort && (uri.port < 1 || uri.port > 65535)) ||
          (portText != null &&
              (explicitPort == null ||
                  explicitPort < 1 ||
                  explicitPort > 65535))) {
        return 'El puerto debe estar entre 1 y 65535.';
      }
    } on FormatException {
      return 'El puerto debe ser un número entre 1 y 65535.';
    }
    if (uri.userInfo.isNotEmpty) {
      return 'Usa la dirección del servidor sin usuario ni contraseña.';
    }
    if (uri.hasFragment) return 'Quita el fragmento que empieza con #.';
    return null;
  }

  @override
  State<EndpointDialog> createState() => _EndpointDialogState();
}

class _EndpointDialogState extends State<EndpointDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text;
  bool _submitted = false;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialValue);
  }

  void _save() {
    if (_submitted) return;
    if (_form.currentState!.validate()) {
      setState(() => _submitted = true);
      Navigator.of(context).pop(_text.text.trim());
    } else {
      setState(() => _showValidationErrors = true);
    }
  }

  void _cancel() {
    if (_submitted) return;
    setState(() => _submitted = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    icon: const Icon(CupertinoIcons.link),
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _text,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          helperText: 'Deja vacío para quitar esta dirección.',
          errorMaxLines: 3,
        ),
        validator: widget.validator ?? EndpointDialog.validate,
        autovalidateMode: _showValidationErrors
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        onFieldSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitted ? null : _cancel,
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _submitted ? null : _save,
        child: const Text('Guardar'),
      ),
    ],
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }
}
