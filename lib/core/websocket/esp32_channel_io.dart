import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectEsp32Channel(Uri uri) => IOWebSocketChannel.connect(
  uri,
  pingInterval: const Duration(seconds: 2),
  connectTimeout: const Duration(seconds: 5),
);
