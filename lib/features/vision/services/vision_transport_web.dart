import 'package:web_socket_channel/web_socket_channel.dart';
import 'vision_transport.dart';

VisionTransport openVisionTransport(Uri uri) =>
    ChannelVisionTransport(WebSocketChannel.connect(uri));
