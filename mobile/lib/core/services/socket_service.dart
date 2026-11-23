import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_endpoints.dart';
import '../security/secure_storage.dart';

class SocketService {
  static IO.Socket? _socket;

  static IO.Socket? get socket => _socket;

  static Future<void> connect() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null) return;

    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      ApiEndpoints.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Yaalu WebSocket successfully connected!');
    });

    _socket!.onDisconnect((_) {
      print('Yaalu WebSocket disconnected');
    });

    _socket!.onError((err) {
      print('Yaalu WebSocket error: $err');
    });
  }

  static void joinMatchRoom(String matchId) {
    _socket?.emit('join_match_room', {'matchId': matchId});
  }

  static void leaveMatchRoom(String matchId) {
    _socket?.emit('leave_match_room', {'matchId': matchId});
  }

  static void sendTyping(String matchId, bool isTyping) {
    _socket?.emit(isTyping ? 'typing_start' : 'typing_stop', {'matchId': matchId});
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
