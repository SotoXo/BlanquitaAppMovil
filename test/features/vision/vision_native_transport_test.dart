import 'dart:async';
import 'dart:io';

import 'package:blanquita/features/vision/domain/vision_network_failure.dart';
import 'package:blanquita/features/vision/services/remote_vision_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final status in [400, 403, 404, 426]) {
    test('native upgrade preserves original HTTP $status and stack', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = server.listen((request) async {
        expect(request.uri.path, '/vision');
        request.response.statusCode = status;
        await request.response.close();
      });
      final uri = Uri.parse('ws://127.0.0.1:${server.port}/vision');
      final session = RemoteVisionService().open(uri);
      final messages = session.messages.listen(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      );
      try {
        await session.ready;
        fail('Upgrade should have failed');
      } catch (error, stack) {
        expect(error, isA<WebSocketException>());
        final failure = VisionNetworkFailure(
          error: error,
          stack: stack,
          uri: uri.toString(),
          timestamp: DateTime.now(),
          attempt: 1,
          previousState: 'CONNECTING',
        );
        expect(failure.httpStatus, status);
        expect(failure.category, 'HTTP $status');
        expect(failure.type, 'WebSocketException');
        expect(failure.stack.toString(), contains('WebSocket.connect'));
        expect(failure.uri, uri.toString());
        // dart:io prints its internal HTTP upgrade URI, not the input WS URI.
        expect(failure.message, contains('http://127.0.0.1:'));
      } finally {
        await session.close();
        await messages.cancel();
        await requests.cancel();
        await server.close(force: true);
      }
    });
  }

  test(
    'close aborts a real pending HTTP upgrade instead of leaving it alive',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final requestReceived = Completer<void>();
      final peerClosed = Completer<void>();
      final peers = <Socket>[];
      final peerSubscriptions = <StreamSubscription<List<int>>>[];
      final incoming = server.listen((peer) {
        peers.add(peer);
        peerSubscriptions.add(
          peer.listen(
            (bytes) {
              if (!requestReceived.isCompleted) requestReceived.complete();
              // Deliberately never answer the HTTP upgrade.
            },
            onDone: () {
              if (!peerClosed.isCompleted) peerClosed.complete();
            },
            onError: (Object error) {
              if (!peerClosed.isCompleted) peerClosed.complete();
            },
          ),
        );
      });
      final session = RemoteVisionService().open(
        Uri.parse('ws://127.0.0.1:${server.port}/vision'),
      );
      final messages = session.messages.listen(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      );
      final failedOpening = expectLater(session.ready, throwsA(anything));
      try {
        await requestReceived.future.timeout(const Duration(seconds: 2));
        await session.close();
        await failedOpening.timeout(const Duration(seconds: 2));
        await peerClosed.future.timeout(const Duration(seconds: 2));
      } finally {
        await session.close();
        await messages.cancel();
        for (final subscription in peerSubscriptions) {
          await subscription.cancel();
        }
        for (final peer in peers) {
          peer.destroy();
        }
        await incoming.cancel();
        await server.close();
      }
    },
  );

  test('closed TCP port is diagnosed as connection refused', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final uri = Uri.parse('ws://127.0.0.1:${server.port}/vision');
    await server.close();
    final session = RemoteVisionService().open(uri);
    final messages = session.messages.listen(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    try {
      await session.ready;
      fail('Connection should be refused');
    } catch (error, stack) {
      final failure = VisionNetworkFailure(
        error: error,
        stack: stack,
        uri: uri.toString(),
        timestamp: DateTime.now(),
        attempt: 1,
        previousState: 'CONNECTING',
      );
      expect(failure.category, 'Connection refused', reason: failure.message);
      expect(failure.type, 'SocketException');
      expect(failure.httpStatus, isNull);
    } finally {
      await session.close();
      await messages.cancel();
    }
  });
}
