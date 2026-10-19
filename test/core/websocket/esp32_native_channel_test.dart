import 'dart:async';
import 'dart:io';
import 'package:blanquita/core/models/machine_state.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real native WebSocket accepts old READY only in laboratory and sends original bytes',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = <String>[];
      final stopped = Completer<void>();
      final accepted = Completer<WebSocket>();
      final subscription = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        accepted.complete(socket);
        socket.listen((data) {
          received.add(data as String);
          if (data == 'x' && !stopped.isCompleted) stopped.complete();
        });
        socket.add('READY');
      });
      SharedPreferences.setMockInitialValues({
        'connection.websocket_url': 'ws://127.0.0.1:${server.port}/',
        'esp32.laboratory_mode': true,
        'connection.auto_reconnect': false,
        'control.haptics': false,
      });
      final settings = SettingsController(
        SettingsRepository(await SharedPreferences.getInstance()),
      );
      await settings.load();
      final machine = MachineController(settings);
      try {
        await machine.connect();
        expect(machine.hasValidConnection, true);
        expect(machine.isAuthorized, false);
        expect(machine.startMovement(MovementDirection.xLeft), true);
        await Future<void>.delayed(const Duration(milliseconds: 225));
        machine.stopMovement();
        await stopped.future.timeout(const Duration(seconds: 2));
        expect(received, ['a', 'k', 'x']);
        await (await accepted.future).close();
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (machine.state.isConnected && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(machine.hasValidConnection, false);
        expect(machine.canStartMovement, false);
      } finally {
        machine.dispose();
        settings.dispose();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
