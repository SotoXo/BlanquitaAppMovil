import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectEsp32Channel(Uri uri) => WebSocketChannel.connect(uri);
