import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/vision_test_discovery.dart';
import 'vision_controller_test.dart' show until;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // This is a real socket integration test, not a widget HTTP mock.
  HttpOverrides.global = null;

  test(
    'native /vision maintains 2s heartbeat >15s, commands and reconnection',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peers = <WebSocket>[];
      final heartbeats = <Timer>[];
      final commands = <String>[];
      var nextMessage = 0;
      var heartbeatCount = 0;
      final requests = server.listen((request) async {
        if (request.uri.path != '/vision') {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }
        final peer = await WebSocketTransformer.upgrade(request);
        peers.add(peer);
        void send(String type, [Map<String, Object?> payload = const {}]) {
          peer.add(
            jsonEncode({
              'protocol': 'blanquita-vision',
              'version': 1,
              'type': type,
              'messageId': 'test-${++nextMessage}',
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              'payload': payload,
            }),
          );
        }

        void heartbeat() {
          ++heartbeatCount;
          send('vision.heartbeat');
        }

        send('vision.hello');
        send('vision.ready');
        heartbeat();
        final timer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => heartbeat(),
        );
        heartbeats.add(timer);
        peer.listen(
          (raw) {
            final message = jsonDecode(raw as String) as Map<String, dynamic>;
            final type = message['type'] as String;
            commands.add(type);
            if (type == 'vision.ping') {
              send('vision.heartbeat', {'replyTo': message['messageId']});
            } else {
              send('vision.status', {
                'detectorStatus': type == 'vision.start' ? 'active' : 'stopped',
              });
            }
          },
          onDone: timer.cancel,
          onError: (Object error) => timer.cancel(),
        );
      });
      SharedPreferences.setMockInitialValues({
        // Exercise migration as well as the strict path on a real HTTP server.
        'vision.websocket_url': 'ws://127.0.0.1:${server.port}/',
        'vision.auto_reconnect': false,
      });
      final settings = SettingsController(
        SettingsRepository(await SharedPreferences.getInstance()),
      );
      await settings.load();
      final vision = VisionController(
        settings,
        discoveryService: TestVisionDiscovery(),
        tickInterval: const Duration(milliseconds: 100),
      );
      try {
        await vision.connect();
        expect(vision.state.ready, true);
        expect(
          vision.connectionWebsocketUrl,
          'ws://127.0.0.1:${server.port}/vision',
        );
        await Future<void>.delayed(const Duration(seconds: 16));
        expect(vision.state.ready, true);
        expect(heartbeatCount, greaterThanOrEqualTo(8));
        vision.ping();
        vision.start();
        await until(() => vision.state.detectorStatus == 'active');
        vision.stop();
        await until(() => vision.state.detectorStatus == 'stopped');
        expect(
          commands,
          containsAll(['vision.ping', 'vision.start', 'vision.stop']),
        );
        await vision.disconnect();
        expect(vision.state.ready, false);
        await vision.connect();
        expect(vision.state.ready, true);
        expect(peers.length, 2);
        expect(vision.connectionAttempt, 2);
        expect(vision.lastFailure, isNull);
      } finally {
        await vision.disconnect();
        vision.dispose();
        settings.dispose();
        for (final timer in heartbeats) {
          timer.cancel();
        }
        for (final peer in peers) {
          unawaited(peer.close());
        }
        await requests.cancel();
        await server.close(force: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
