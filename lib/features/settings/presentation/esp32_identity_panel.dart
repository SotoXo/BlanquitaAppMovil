import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/esp32_device.dart';
import '../../../core/protocol/esp32_session.dart';
import '../../../core/websocket/machine_controller.dart';
import '../controller/app_settings.dart';

class Esp32IdentityPanel extends StatelessWidget {
  const Esp32IdentityPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final machine = context.watch<MachineController>();
    final selected = machine.selectedDevice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Estado WebSocket: ${machine.connectionStatusLabel}'),
        Text('Estado: ${machine.linkPhase.label}'),
        Text('Autenticación: ${machine.authenticationLabel}'),
        Text(
          'IP actual: ${machine.deviceAddress ?? selected?.ip ?? 'Sin dirección'}',
        ),
        Text('Device ID: ${selected?.deviceId ?? 'Sin seleccionar'}'),
        if (selected != null)
          Text('Nombre: ${selected.name} · ${selected.deviceType}'),
        if (machine.lastError != null)
          Text('Último error: ${machine.lastError}'),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Laboratorio con firmware antiguo'),
          subtitle: const Text(
            'Solo pruebas controladas con URL manual. READY no autentica. Desactivar en redes con varios equipos.',
          ),
          value: machine.laboratoryEnabled,
          onChanged: selected != null || AppSettings.multiDeviceDeployment
              ? null
              : machine.setLaboratoryMode,
        ),
        if (machine.isDiscovering)
          TextButton(
            onPressed: machine.cancelSearch,
            child: const Text('Cancelar búsqueda'),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Seleccionar dispositivo'),
          children: [
            if (machine.devices.isEmpty)
              const Text(
                'Sin candidatos V2. Busca dispositivos o introduce la identidad de la etiqueta física.',
              ),
            for (final device in machine.devices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(device.name),
                subtitle: Text(
                  '${device.deviceId} · ${device.ip}:${device.port} · ${device.connection.label}',
                ),
                trailing:
                    selected?.deviceId == device.deviceId &&
                        selected?.ip == device.ip
                    ? const Icon(Icons.check)
                    : null,
                onTap: machine.isConnecting
                    ? null
                    : () => machine.selectDevice(device),
              ),
            TextButton(
              onPressed: machine.isConnecting
                  ? null
                  : () => _manualIdentity(context, machine),
              child: const Text('Seleccionar por identidad y URL manual'),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: selected == null || machine.isConnecting
                  ? null
                  : () => _pair(context, machine),
              child: const Text('Vincular'),
            ),
            TextButton(
              onPressed: selected == null ? null : machine.unpair,
              child: const Text('Desvincular'),
            ),
          ],
        ),
        const Text(
          'V2 requiere el nuevo firmware Arduino. La identidad de UDP por sí sola no autoriza controles.',
        ),
      ],
    );
  }

  Future<void> _manualIdentity(
    BuildContext context,
    MachineController machine,
  ) async {
    final id = TextEditingController();
    final name = TextEditingController(text: 'BLANQUITA');
    final uri = Uri.tryParse(machine.settingsWebsocketUrl);
    if (uri == null || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guarda primero la URL manual del ESP32')),
      );
      id.dispose();
      name.dispose();
      return;
    }
    final form = GlobalKey<FormState>();
    TransitionRoute<bool>? route;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        route = ModalRoute.of(ctx) as TransitionRoute<bool>;
        return AlertDialog(
          title: const Text('Identidad física del ESP32'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: id,
                  decoration: const InputDecoration(
                    labelText: 'Device ID de la etiqueta/USB',
                  ),
                  validator: (s) => Esp32Device.validId(s ?? '')
                      ? null
                      : 'Device ID inválido',
                ),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (s) =>
                      s != null && s.trim().isNotEmpty && s.length <= 100
                      ? null
                      : 'Nombre inválido',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Seleccionar'),
            ),
          ],
        );
      },
    );
    await route?.completed;
    final deviceId = id.text;
    final deviceName = name.text.trim();
    id.dispose();
    name.dispose();
    if (accepted != true || !context.mounted) return;
    await machine.selectDevice(
      Esp32Device(
        deviceId: deviceId,
        name: deviceName,
        deviceType: Esp32Device.cartesianType,
        ip: uri.host,
      ),
    );
  }

  Future<void> _pair(BuildContext context, MachineController machine) async {
    final secret = TextEditingController();
    final form = GlobalKey<FormState>();
    TransitionRoute<bool>? route;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        route = ModalRoute.of(ctx) as TransitionRoute<bool>;
        return AlertDialog(
          title: const Text('Vincular ESP32 V2'),
          content: Form(
            key: form,
            child: TextFormField(
              controller: secret,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Clave física de 64 caracteres hex',
                helperText: 'Pendiente de firmware V2 compatible.',
              ),
              validator: (s) => Esp32Session.validSecret(s ?? '')
                  ? null
                  : 'Se requieren 64 caracteres hex minúscula',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Vincular'),
            ),
          ],
        );
      },
    );
    await route?.completed;
    final value = secret.text;
    secret.dispose();
    if (accepted != true || !context.mounted) return;
    await machine.pairSelected(value);
  }
}
