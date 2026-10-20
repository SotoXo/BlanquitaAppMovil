import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blanquita/features/vision/domain/vision_message.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'package:blanquita/features/vision/services/vision_protocol_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real loopback WebSocket receives telemetry and sends only vision commands',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peer = Completer<WebSocket>();
      final serverSubscription = server.listen((request) async {
        expect(request.uri.path, '/vision');
        if (request.uri.path != '/vision') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        peer.complete(await WebSocketTransformer.upgrade(request));
      });
      final service = RemoteVisionService();
      final session = service.open(Uri.parse('ws://127.0.0.1:${server.port}/'));
      final received = Completer<Object?>();
      final subscription = session.messages.listen((message) {
        if (!received.isCompleted) received.complete(message);
      });
      WebSocket? socket;
      addTearDown(() async {
        await subscription.cancel();
        await session.close();
        await socket?.close();
        await serverSubscription.cancel();
        await server.close(force: true);
      });
      await session.ready;
      socket = await peer.future;
      socket.add(
        jsonEncode({
          'protocol': 'blanquita-vision',
          'version': 1,
          'type': 'vision.ready',
          'messageId': 'ready-1',
          'timestamp': '2026-10-06T10:30:00Z',
          'payload': {},
        }),
      );
      final ready = const VisionProtocolParser().parse(await received.future);
      expect(ready.message!.status.ready, true);
      final receivedCommands = <Map<String, dynamic>>[];
      final commands = Completer<void>();
      socket.listen((message) {
        receivedCommands.add(
          jsonDecode(message as String) as Map<String, dynamic>,
        );
        if (receivedCommands.length == 3) commands.complete();
      });
      for (final command in VisionCommand.values) {
        session.send(command, command.name, DateTime.utc(2026, 10, 6));
      }
      await commands.future.timeout(const Duration(seconds: 3));
      expect(receivedCommands.map((item) => item['type']), [
        'vision.start',
        'vision.stop',
        'vision.ping',
      ]);
      expect(
        receivedCommands.every((item) => (item['payload'] as Map).isEmpty),
        true,
      );
    },
  );

  test(
    'URL accepts configurable ws/wss endpoints and rejects invalid input',
    () {
      expect(
        RemoteVisionService.isValidUrl('ws://192.168.10.20:8765/vision'),
        true,
      );
      expect(
        RemoteVisionService.isValidUrl('wss://laptop.local/vision'),
        false,
      );
      for (final value in [
        '',
        'http://laptop.local',
        'ws://',
        'ws://laptop:abc',
        'ws://user:pass@laptop/',
      ]) {
        expect(RemoteVisionService.isValidUrl(value), false);
      }
    },
  );
}
