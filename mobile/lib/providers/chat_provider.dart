import 'package:flutter/foundation.dart';
import '../models/match_model.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_endpoints.dart';
import '../core/services/socket_service.dart';

class ChatProvider with ChangeNotifier {
  List<MatchModel> _matches = [];
  List<MessageModel> _currentMessages = [];
  bool _isLoading = false;
  String? _activeMatchId;
  bool _isOtherUserTyping = false;

  List<MatchModel> get matches => _matches;
  List<MessageModel> get currentMessages => _currentMessages;
  bool get isLoading => _isLoading;
  String? get activeMatchId => _activeMatchId;
  bool get isOtherUserTyping => _isOtherUserTyping;

  ChatProvider() {
    initSocketListeners();
  }

  void initSocketListeners() {
    final socket = SocketService.socket;
    if (socket == null) return;

    // Clean up any old listeners to prevent duplicate event triggers
    socket.off('new_message');
    socket.off('user_typing');

    socket.on('new_message', (data) {
      if (data != null && data['matchId'] == _activeMatchId) {
        final newMsg = MessageModel.fromJson(data);
        _addMessageSafely(newMsg);
      }
    });

    socket.on('user_typing', (data) {
      if (data != null && data['matchId'] == _activeMatchId) {
        _isOtherUserTyping = data['isTyping'] ?? false;
        notifyListeners();
      }
    });
  }

  // Deduplication guard for message delivery
  void _addMessageSafely(MessageModel newMsg) {
    // 1. Never add if exact ID already exists
    final existsById = _currentMessages.any((m) => m.id == newMsg.id);
    if (existsById) return;

    // 2. Prevent duplicate bubble if identical content arrived within 3s from same sender
    final existsByContent = _currentMessages.any((m) =>
        m.senderId == newMsg.senderId &&
        m.content == newMsg.content &&
        newMsg.createdAt.difference(m.createdAt).inSeconds.abs() < 3);
    if (existsByContent) return;

    _currentMessages.add(newMsg);
    notifyListeners();
  }

  // Fetch all mutual matches
  Future<void> fetchMatches() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.get(ApiEndpoints.matches);
      final rawList = res['data'] as List<dynamic>? ?? [];
      _matches = rawList.map((m) => MatchModel.fromJson(m)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Open Conversation
  Future<void> openConversation(String matchId) async {
    _activeMatchId = matchId;
    _currentMessages = [];
    _isLoading = true;
    notifyListeners();

    // Ensure socket listeners are attached and refreshed
    initSocketListeners();
    SocketService.joinMatchRoom(matchId);

    try {
      final res = await ApiService.get(ApiEndpoints.matchMessages(matchId));
      final rawList = res['data'] as List<dynamic>? ?? [];

      // Filter out any duplicates loaded from server
      final uniqueMessages = <MessageModel>[];
      for (final raw in rawList) {
        final msg = MessageModel.fromJson(raw);
        final isDup = uniqueMessages.any((u) =>
            u.id == msg.id ||
            (u.senderId == msg.senderId &&
                u.content == msg.content &&
                msg.createdAt.difference(u.createdAt).inSeconds.abs() < 3));
        if (!isDup) {
          uniqueMessages.add(msg);
        }
      }

      _currentMessages = uniqueMessages;
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Close Conversation
  void closeConversation() {
    if (_activeMatchId != null) {
      SocketService.leaveMatchRoom(_activeMatchId!);
      _activeMatchId = null;
      _currentMessages = [];
      _isOtherUserTyping = false;
    }
  }

  // Send Message
  Future<bool> sendMessage(String content, {String? mediaUrl, bool isVoiceNote = false}) async {
    if (_activeMatchId == null) return false;

    try {
      final res = await ApiService.post(ApiEndpoints.messages, {
        'matchId': _activeMatchId,
        'content': content,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        'isVoiceNote': isVoiceNote,
      });

      final newMsg = MessageModel.fromJson(res['data']);
      _addMessageSafely(newMsg);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Toggle Media Blur (Privacy Protection)
  Future<void> toggleBlur(String messageId) async {
    try {
      final res = await ApiService.post(ApiEndpoints.toggleBlur(messageId), {});
      final updated = MessageModel.fromJson(res['data']);
      final index = _currentMessages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _currentMessages[index] = updated;
        notifyListeners();
      }
    } catch (_) {}
  }
}
