import 'package:flutter/material.dart';

import '../../components/backround.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../models/chat_message_model.dart';
import '../../widgets/common/app_drawer.dart';

class ChatMobile extends StatefulWidget {
  const ChatMobile({super.key});

  @override
  State<ChatMobile> createState() => _ChatMobileState();
}

class _ChatMobileState extends State<ChatMobile> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController keyController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String? activeConversationId;
  bool showSidebar = true;
  String selectedAlgorithm = 'aes-gcm';

  // Utilisateur courant chargé en initState (pas dans build)
  LocalUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().currentUser;
    if (mounted) setState(() => _currentUser = user);
  }

  @override
  void dispose() {
    emailController.dispose();
    keyController.dispose();
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> openConversation() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;
    try {
      // getUserByEmail retourne Map<String,dynamic>? — on accède avec ['id']
      final userDoc = _chatService.getUserByEmail(email);
      if (userDoc == null) return;
      final id = await _chatService.getOrCreateConversation(
        userDoc['id'] as String, email,
      );
      setState(() {
        activeConversationId = id;
        showSidebar = false;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    final key = keyController.text.trim();
    if (text.isEmpty || key.isEmpty) return;
    try {
      await _chatService.sendMessageToEmail(
        receiverEmail: emailController.text,
        text: text,
        encryptionKey: key,
        algorithm: selectedAlgorithm,
      );
      messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(currentPage: 'chat'),
      appBar: AppBar(
        title: Text(showSidebar ? 'Conversations' : emailController.text),
        leading: showSidebar
          ? Builder(builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ))
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => showSidebar = true),
            ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: showSidebar
              ? _buildSidebar(isDark)
              : _buildChatRoom(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDark) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      TextField(
        controller: emailController,
        decoration: _inputDeco("@username ou email", isDark),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: openConversation,
          child: const Text("Ouvrir"),
        ),
      ),
      const Divider(height: 30),
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getRecentConversations(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snap.data!.length,
            itemBuilder: (context, i) {
              final conv = snap.data![i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(conv['email'],
                  style: const TextStyle(color: Colors.white)),
                onTap: () => setState(() {
                  activeConversationId = conv['conversationId'];
                  emailController.text = conv['email'];
                  showSidebar = false;
                }),
              );
            },
          );
        },
      )),
    ]),
  );

  Widget _buildChatRoom(bool isDark) => Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black26,
      child: TextField(
        controller: keyController,
        obscureText: true,
        decoration: _inputDeco("Clé de chiffrement", isDark, small: true),
      ),
    ),
    Expanded(child: StreamBuilder<List<ChatMessageModel>>(
      stream: _chatService.getMessages(activeConversationId!),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: snap.data!.length,
          itemBuilder: (context, i) {
            final msg = snap.data![i];
            final isMe = msg.senderId == _currentUser?.id;
            return _bubble(msg, isMe, isDark);
          },
        );
      },
    )),
    _bottomBar(isDark),
  ]);

  Widget _bubble(ChatMessageModel msg, bool isMe, bool isDark) => Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue : Colors.white10,
        borderRadius: BorderRadius.circular(15),
      ),
      child: FutureBuilder<String>(
        future: _chatService.decryptMessage(msg, keyController.text),
        builder: (context, snap) => Text(
          snap.data ?? "🔒",
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    ),
  );

  Widget _bottomBar(bool isDark) => Container(
    padding: const EdgeInsets.all(10),
    color: Colors.black45,
    child: Row(children: [
      Expanded(child: TextField(
        controller: messageController,
        decoration: _inputDeco("Message...", isDark, small: true),
      )),
      IconButton(onPressed: sendMessage, icon: const Icon(Icons.send, color: Colors.blue)),
    ]),
  );

  InputDecoration _inputDeco(String hint, bool isDark, {bool small = false}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white10,
      contentPadding: EdgeInsets.all(small ? 10 : 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
}
