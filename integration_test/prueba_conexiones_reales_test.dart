import 'package:blanquita/app/presentation/controller_ui_context.dart';
import 'dart:async';
import 'package:blanquita/app/app.dart';
import 'package:blanquita/core/diagnostics/connection_log.dart';
import 'package:blanquita/core/network/connection_failure.dart';
import 'package:blanquita/core/network/wifi_network_controller.dart';
import 'package:blanquita/core/storage/settings_repository.dart';
import 'package:blanquita/core/websocket/machine_controller.dart';
import 'package:blanquita/features/settings/controller/settings_controller.dart';
import 'package:blanquita/features/vision/controller/vision_controller.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _RecordedChannel implements WebSocketChannel {
  _RecordedChannel(Uri endpoint)
    : delegate = WebSocketChannel.connect(endpoint);
  final WebSocketChannel delegate;
  final received = <String>[];
  @override
  late final Stream<dynamic> stream = delegate.stream.map((message) {
    if (received.length < 40) received.add(message.toString());
    return message;
  });
  @override
  late final _RecordedSink sink = _RecordedSink(delegate.sink);
  @override
  Future<void> get ready => delegate.ready;
  @override
  int? get closeCode => delegate.closeCode;
  @override
  String? get closeReason => delegate.closeReason;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordedSink implements WebSocketSink {
  _RecordedSink(this.delegate);
  final WebSocketSink delegate;
  final sent = <String>[];
  @override
  void add(dynamic data) {
    sent.add(data.toString());
    delegate.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      delegate.addError(error, stackTrace);
  @override
  Future<void> addStream(Stream<dynamic> stream) => delegate.addStream(stream);
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    await delegate.close(closeCode, closeReason);
  }

  @override
  Future<void> get done async {
    await delegate.done;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const controlUrl = String.fromEnvironment('ESP32_URL');
  const visionUrl = String.fromEnvironment('VISION_URL');
  testWidgets(
    'observación Wi-Fi y validación real de ambos servidores sin movimientos',
    (tester) async {
      expect(EndpointValidation.parse(controlUrl), isNotNull);
      expect(EndpointValidation.parse(visionUrl), isNotNull);
      final preferences = await SharedPreferences.getInstance();
      final settings = SettingsController(SettingsRepository(preferences));
      await settings.load();
      final controlAuto = settings.settings.autoReconnect;
      final visionAuto = settings.settings.visionAutoReconnect;
      await settings.setAutoReconnect(false);
      await settings.setVisionAutoReconnect(false);
      await settings.setWebsocketUrl(controlUrl);
      await settings.setVisionWebsocketUrl(visionUrl);
      ConnectionLog.shared.clear();
      final controlChannels = <_RecordedChannel>[];
      final visionChannels = <_RecordedChannel>[];
      final machine = MachineController(
        settings,
        channelFactory: (uri) {
          final channel = _RecordedChannel(uri);
          controlChannels.add(channel);
          return channel;
        },
      );
      final vision = VisionController(
        settings,
        service: RemoteVisionService(
          channelFactory: (uri) {
            final channel = _RecordedChannel(uri);
            visionChannels.add(channel);
            return channel;
          },
        ),
      );
      final wifi = WifiNetworkController();
      await tester.pumpWidget(
        BlanquitaApp(
          settingsController: settings,
          machineController: machine,
          visionController: vision,
          wifiController: wifi,
          autoConnect: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 12));
        await wifi.refresh();
      });
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('prueba-real-wifi');
      var controlReady = false;
      var visionReady = false;
      if (wifi.status.supported && wifi.status.connected) {
        await tester.runAsync(() async {
          controlReady = await machine.testConnection();
          visionReady = await vision.testConnection();
          await Future<void>.delayed(const Duration(seconds: 3));
        });
      }
      await tester.pump(const Duration(milliseconds: 500));
      final wifiTcp = <String, Object?>{};
      if (wifi.status.connected) {
        await tester.runAsync(() async {
          for (final entry in {
            'control': Uri.parse(controlUrl),
            'vision': Uri.parse(visionUrl),
          }.entries) {
            final probe = await wifi.probeEndpoint(
              entry.value,
              deviceLabel: entry.key == 'control' ? 'ESP32' : 'Vision Server',
            );
            wifiTcp[entry.key] = probe;
          }
        });
      }
      final result = <String, Object?>{
        'wifi': wifi.snapshot,
        'tcp_especificamente_wifi': wifiTcp,
        'control': {
          'endpoint': controlUrl,
          'ready': controlReady,
          'phase': machine.phase,
          'transportOpen': machine.transportOpen,
          'errorCode': machine.lastErrorCode,
          'humanMessage':
              machine.state.connectionError ?? machine.state.lastStatus,
          'technicalMessage': machine.lastTechnicalError,
          'received': controlChannels
              .expand((channel) => channel.received)
              .toList(),
          'sent': controlChannels
              .expand((channel) => channel.sink.sent)
              .toList(),
        },
        'vision': {
          'endpoint': visionUrl,
          'ready': visionReady,
          'phase': vision.phase,
          'transportOpen': vision.transportOpen,
          'errorCode': vision.lastErrorCode,
          'humanMessage': vision.state.error ?? vision.state.lastMessage,
          'technicalMessage': vision.lastTechnicalError,
          'received': visionChannels
              .expand((channel) => channel.received)
              .toList(),
          'sent': visionChannels
              .expand((channel) => channel.sink.sent)
              .toList(),
        },
        'bitacora': ConnectionLog.shared.export(
          app: {'Nombre': 'BLANQUITA Víctor', ...wifi.snapshot},
          control: {'Endpoint': controlUrl, 'Estado': machine.phase},
          vision: {'Endpoint': visionUrl, 'Estado': vision.phase},
        ),
      };
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['prueba_real'] = result;
      expect(
        controlChannels.expand((channel) => channel.sink.sent),
        isEmpty,
        reason:
            'La validación no puede enviar comandos físicos ni heartbeat de movimiento.',
      );
      await tester.tap(find.text('Ajustes'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Abrir diagnósticos'));
      await tester.tap(find.text('Abrir diagnósticos'));
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot('prueba-real-diagnosticos');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      // Restore retry preferences after sockets have closed; keep authorized URLs.
      await preferences.setBool('connection.auto_reconnect', controlAuto);
      await preferences.setBool('vision.auto_reconnect', visionAuto);
    },
  );
}
