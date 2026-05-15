import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../services/network_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService.instance;
  final SocketService _socket = SocketService.instance;
  final NetworkService _network = NetworkService.instance;

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> get conversations => _conversations;

  final Map<String, List<ChatMessageModel>> _messages = {};
  
  String? _activeConversationId;
  String? get activeConversationId => _activeConversationId;

  ChatProvider() {
    _init();
  }

  void _init() {
    _socket.onMessage = _handleIncomingMessage;
    refreshConversations();
  }

  List<ChatMessageModel> getMessages(String conversationId) {
    return _messages[conversationId] ?? [];
  }

  Future<void> refreshConversations() async {
    try {
      _chatService.getRecentConversations().listen((convs) {
        _conversations = convs;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Erreur refreshConversations: $e');
    }
  }

  Future<void> loadMessages(String conversationId) async {
    _activeConversationId = conversationId;
    _chatService.getMessages(conversationId).listen((msgs) {
      _messages[conversationId] = msgs;
      notifyListeners();
    });
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> data) async {
    if (data.containsKey('msgType')) {
      data['type'] = data['msgType'];
    }
    await _chatService.saveReceivedMessage(data);
    notifyListeners();
  }

  Future<void> sendMessage({
    required String receiverEmail,
    required String text,
    required String mode,
    String type = 'text',
    String? fileName,
    int? fileSize,
  }) async {
    await _chatService.sendMessage(
      receiverEmail: receiverEmail,
      text: text,
      mode: mode,
      type: type,
      fileName: fileName,
      fileSize: fileSize,
    );
  }

  Future<String> decryptMessage(ChatMessageModel msg) async {
    return await _chatService.decryptMessage(msg);
  }
}
