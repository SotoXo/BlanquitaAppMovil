import 'dart:async';
import 'dart:convert';

import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/domain/vision_state.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/vision_test_channel.dart';
import 'support/vision_test_discovery.dart';
import 'vision_controller_test.dart' show until;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsController settings;
  late VisionController vision;
  late TestVisionDiscovery discovery;
  final channels = <TestVisionChannel>[];
  final urls = <Uri>[];
  var savedUrl = 'ws://172.20.10.7:8765/vision';
  late void Function(Uri, TestVisionChannel) onOpen;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'vision.websocket_url': savedUrl,
      'vision.auto_reconnect': false,
    });
    settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await settings.load();
    discovery = TestVisionDiscovery();
    onOpen = (_, channel) =>
        scheduleMicrotask(() => channel.establish(DateTime.now()));
    vision = VisionController(
      settings,
      discoveryService: discovery,
      connectionTimeout: const Duration(milliseconds: 40),
      reconnectBaseDelay: const Duration(milliseconds: 20),
      service: RemoteVisionService(
        channelFactory: (uri) {
          urls.add(uri);
          final channel = TestVisionChannel();
          channels.add(channel);
          onOpen(uri, channel);
          return channel;
        },
      ),
    );
  });

  tearDown(() async {
    await vision.disconnect();
    vision.dispose();
    settings.dispose();
    for (final channel in channels) {
      await channel.incoming.close();
    }
    channels.clear();
    urls.clear();
    savedUrl = 'ws://172.20.10.7:8765/vision';
  });

  test('valid saved URL requires ready and avoids discovery', () async {
    await vision.connect();
    expect(vision.state.ready, true);
    expect(discovery.calls, 0);
    expect(urls.single.toString(), savedUrl);
    expect(settings.settings.visionWebsocketUrl, savedUrl);
    expect(vision.detectedAddress, isNull);
  });

  test(
    'TCP, hello, status and heartbeat cannot replace vision.ready',
    () async {
      onOpen = (_, channel) => scheduleMicrotask(() {
        channel.receive('vision.hello', DateTime.now());
        channel.receive('vision.status', DateTime.now(), {'ready': true});
        channel.receive('vision.heartbeat', DateTime.now());
      });
      final connecting = vision.connect();
      await until(
        () => channels.isNotEmpty && vision.state.lastMessage != null,
      );
      expect(vision.state.isConnected, false);
      expect(vision.state.ready, false);
      expect(channels.single.sink.sent, isEmpty);
      channels.single.establish(DateTime.now());
      await connecting;
      expect(vision.state.ready, true);
      expect(discovery.calls, 0);
    },
  );

  test(
    'obsolete saved URL discovers and saves new address after ready only',
    () async {
      final candidate = Uri.parse('ws://192.168.137.115:8765/vision');
      discovery.result = () async => candidate;
      onOpen = (_, _) {};
      final connecting = vision.connect();
      await until(() => channels.length == 2);
      expect(urls, [Uri.parse(savedUrl), candidate]);
      expect(vision.detectedAddress, '192.168.137.115');
      expect(vision.state.isConnected, false);
      expect(settings.settings.visionWebsocketUrl, savedUrl);
      channels.last.establish(DateTime.now());
      await connecting;
      expect(vision.state.ready, true);
      expect(settings.settings.visionWebsocketUrl, candidate.toString());
      expect(vision.discoveryStatusLabel, 'Visor validado');
      expect(
        channels.length,
        2,
      ); // Persisting does not restart the validated session.
      expect(channels.last.sink.closed, false);
    },
  );

  test(
    'candidate without vision.ready never persists and manual fallback stays',
    () async {
      discovery.result = () async => Uri.parse('ws://10.42.193.8:8765/vision');
      onOpen = (_, channel) => scheduleMicrotask(
        () => channel.receive('vision.hello', DateTime.now()),
      );
      await vision.connect();
      expect(vision.state.isConnected, false);
      expect(discovery.calls, 1);
      expect(channels.every((channel) => channel.sink.closed), true);
      expect(settings.settings.visionWebsocketUrl, savedUrl);
      expect(vision.discoveryStatusLabel, 'Candidato sin vision.ready');
      expect(vision.isConnecting, false);
      onOpen = (_, channel) =>
          scheduleMicrotask(() => channel.establish(DateTime.now()));
      await vision.connect();
      expect(vision.state.ready, true);
      expect(urls.last.toString(), savedUrl);
    },
  );

  test(
    'invalid envelope or ready:false cannot validate UDP candidate',
    () async {
      await settings.setVisionWebsocketUrl('');
      discovery.result = () async =>
          Uri.parse('ws://192.168.137.115:8765/vision');
      onOpen = (_, channel) => scheduleMicrotask(() {
        for (final changes in <Map<String, Object?>>[
          {'protocol': 'other'},
          {'version': 2},
          {
            'payload': {'ready': false},
          },
          {'messageId': null},
          {'timestamp': 'invalid'},
        ]) {
          channel.incoming.add(
            jsonEncode({
              'protocol': 'blanquita-vision',
              'version': 1,
              'type': 'vision.ready',
              'messageId': 'ready-1',
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              'payload': {},
              ...changes,
            }),
          );
        }
      });
      await vision.connect();
      expect(vision.state.ready, false);
      expect(settings.settings.visionWebsocketUrl, '');
    },
  );

  test('empty saved URL discovers at startup without a fixed IP', () async {
    await settings.setVisionWebsocketUrl('');
    discovery.result = () async => Uri.parse('ws://10.42.193.22:8765/vision');
    await vision.connect();
    expect(discovery.calls, 1);
    expect(urls.single.host, '10.42.193.22');
    expect(
      settings.settings.visionWebsocketUrl,
      'ws://10.42.193.22:8765/vision',
    );
  });

  test(
    'explicit search uses UDP first without trying obsolete manual address',
    () async {
      discovery.result = () async =>
          Uri.parse('ws://192.168.137.115:8765/vision');
      await vision.searchVision();
      expect(discovery.calls, 1);
      expect(urls.single.host, '192.168.137.115');
    },
  );

  test(
    'DHCP recovery spans 172.20.10, 10.42.193 and 192.168.137 networks',
    () async {
      await settings.setVisionAutoReconnect(true);
      var liveHost = '172.20.10.7';
      discovery.result = () async =>
          Uri(scheme: 'ws', host: liveHost, port: 8765, path: '/vision');
      onOpen = (uri, channel) {
        if (uri.host == liveHost) {
          scheduleMicrotask(() => channel.establish(DateTime.now()));
        }
      };
      await vision.connect();
      for (final newHost in ['10.42.193.22', '192.168.137.115']) {
        final oldUrl = settings.settings.visionWebsocketUrl;
        final offset = urls.length;
        liveHost = newHost;
        await channels.last.incoming.close();
        await until(
          () =>
              settings.settings.visionWebsocketUrl ==
              'ws://$newHost:8765/vision',
        );
        expect(vision.state.ready, true);
        expect(urls[offset].toString(), oldUrl);
        expect(urls[offset + 1].host, newHost);
      }
      expect(discovery.calls, 2);
    },
  );

  test(
    'failed cycles keep exponential backoff and do not scan addresses',
    () async {
      await settings.setVisionWebsocketUrl('');
      await settings.setVisionAutoReconnect(true);
      await vision.connect();
      expect(vision.state.connection, VisionConnection.reconnecting);
      expect(
        vision.diagnostics.any((item) => item.contains('Reconexión en 20 ms')),
        true,
      );
      await until(
        () =>
            discovery.calls >= 2 &&
            vision.diagnostics.any(
              (item) => item.contains('Reconexión en 40 ms'),
            ),
      );
      expect(
        vision.diagnostics.any((item) => item.contains('Reconexión en 40 ms')),
        true,
      );
      await until(
        () =>
            discovery.calls >= 3 &&
            vision.diagnostics.any(
              (item) => item.contains('Reconexión en 80 ms'),
            ),
      );
      expect(
        vision.diagnostics.any((item) => item.contains('Reconexión en 80 ms')),
        true,
      );
      expect(urls, isEmpty);
      await vision.disconnect();
      final calls = discovery.calls;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(discovery.calls, calls);
    },
  );

  test(
    'disconnect cancels discovery and ignores a late datagram candidate',
    () async {
      final candidate = Completer<Uri?>();
      discovery.result = () => candidate.future;
      final searching = vision.searchVision();
      await until(() => vision.isDiscovering);
      await vision.disconnect();
      candidate.complete(Uri.parse('ws://192.168.137.115:8765/vision'));
      await searching;
      expect(vision.state.isConnected, false);
      expect(urls, isEmpty);
      expect(discovery.cancellations, greaterThan(0));
      expect(vision.discoveryStatusLabel, 'Búsqueda cancelada');
      expect(settings.settings.visionWebsocketUrl, savedUrl);
    },
  );

  test('disconnect overrides an explicit search before UDP begins', () async {
    final searching = vision.searchVision();
    await vision.disconnect();
    await searching;
    expect(discovery.calls, 0);
    expect(vision.state.connection, VisionConnection.disconnected);
  });

  test(
    'pending ready is cancelled and cannot reconnect after late handshake',
    () async {
      onOpen = (_, _) {};
      final connecting = vision.connect();
      await until(() => channels.isNotEmpty);
      await vision.disconnect();
      channels.single.establish(DateTime.now());
      await connecting;
      expect(vision.state.isConnected, false);
      expect(discovery.calls, 0);
      expect(channels.single.sink.closed, true);
    },
  );

  test('discovery failure and exceptions preserve manual URL', () async {
    onOpen = (_, _) {};
    discovery.result = () async => throw StateError('UDP unavailable');
    await vision.connect();
    expect(vision.state.ready, false);
    expect(vision.isDiscovering, false);
    expect(vision.isConnecting, false);
    expect(settings.settings.visionWebsocketUrl, savedUrl);
    expect(
      vision.diagnostics.any((item) => item.contains('UDP unavailable')),
      true,
    );
  });
}
