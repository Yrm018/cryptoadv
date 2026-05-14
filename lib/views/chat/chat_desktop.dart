import 'package:flutter/material.dart';

import '../../components/backround.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_navbar.dart';
import '../../models/chat_message_model.dart';

class ChatDesktop extends StatefulWidget {
  const ChatDesktop({super.key});

  @override
  State<ChatDesktop> createState() => _ChatDesktopState();
}

class _ChatDesktopState extends State<ChatDesktop> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController keyController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String? activeConversationId;
  bool isLoadingConversation = false;
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

  Future<void> openConversationFromEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => isLoadingConversation = true);
    try {
      // getUserByEmail retourne Map<String,dynamic>? — on accède avec ['id']
      final userDoc = _chatService.getUserByEmail(email);
      if (userDoc == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun utilisateur trouvé")),
        );
        return;
      }
      final conversationId = await _chatService.getOrCreateConversation(
        userDoc['id'] as String, email,
      );
      if (mounted) setState(() => activeConversationId = conversationId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      if (mounted) setState(() => isLoadingConversation = false);
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    final email = emailController.text.trim();
    final key = keyController.text.trim();
    if (text.isEmpty || email.isEmpty || key.isEmpty) return;
    try {
      await _chatService.sendMessageToEmail(
        receiverEmail: email,
        text: text,
        encryptionKey: key,
        algorithm: selectedAlgorithm,
      );
      messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur d'envoi : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: Column(
              children: [
                const AppNavbar(currentPage: 'chat'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        SizedBox(width: 300, child: _buildSidebar(isDark)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildChatPanel(isDark)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDark) => _glassPanel(
    isDark: isDark,
    child: Column(children: [
      Row(children: [
        Icon(Icons.forum_rounded,
          color: isDark ? const Color(0xFF7AA6FF) : const Color(0xFF2563EB),
          size: 18),
        const SizedBox(width: 10),
        const Text("Conversations",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 16),
      TextField(
        controller: emailController,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: _fieldDeco("Email du destinataire", isDark: isDark),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: openConversationFromEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF7AA6FF) : const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          child: const Text("Ouvrir"),
        ),
      ),
      const Divider(height: 30, color: Colors.white10),
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getRecentConversations(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final convs = snap.data!;
          return ListView.builder(
            itemCount: convs.length,
            itemBuilder: (context, i) => _convTile(convs[i], isDark),
          );
        },
      )),
    ]),
  );

  Widget _convTile(Map<String, dynamic> conv, bool isDark) {
    final id = conv['conversationId'];
    final active = activeConversationId == id;
    return ListTile(
      selected: active,
      selectedTileColor: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: CircleAvatar(
        backgroundColor: active ? Colors.blue : Colors.grey,
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      ),
      title: Text(conv['email'],
        style: const TextStyle(color: Colors.white, fontSize: 13),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => setState(() {
        activeConversationId = id;
        emailController.text = conv['email'];
      }),
    );
  }

  Widget _buildChatPanel(bool isDark) => _glassPanel(
    isDark: isDark,
    padding: EdgeInsets.zero,
    child: Column(children: [
      _chatHeader(isDark),
      Expanded(child: _buildMessagesArea(isDark)),
      _chatInput(isDark),
    ]),
  );

  Widget _chatHeader(bool isDark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
    child: Row(children: [
      const Text("Chat chiffré",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      const Spacer(),
      _algoChip('aes-gcm', 'AES-GCM', isDark),
      const SizedBox(width: 10),
      _algoChip('chacha20', 'ChaCha20', isDark),
    ]),
  );

  Widget _algoChip(String val, String label, bool isDark) {
    final active = selectedAlgorithm == val;
    return GestureDetector(
      onTap: () => setState(() => selectedAlgorithm = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.blue : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );
  }

  Widget _buildMessagesArea(bool isDark) {
    if (activeConversationId == null) {
      return const Center(
        child: Text("Sélectionnez une conversation",
          style: TextStyle(color: Colors.white38)),
      );
    }
    return StreamBuilder<List<ChatMessageModel>>(
      stream: _chatService.getMessages(activeConversationId!),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final msgs = snap.data!;
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: msgs.length,
          itemBuilder: (context, i) =>
            _msgBubble(msgs[i], _currentUser?.id == msgs[i].senderId, isDark),
        );
      },
    );
  }

  Widget _msgBubble(ChatMessageModel msg, bool isMe, bool isDark) => Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue : Colors.white10,
        borderRadius: BorderRadius.circular(15),
      ),
      child: FutureBuilder<String>(
        future: _chatService.decryptMessage(msg, keyController.text),
        builder: (context, snap) => Text(
          snap.data ?? (keyController.text.isEmpty ? "🔒 Verrouillé" : "..."),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );

  Widget _chatInput(bool isDark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white10)),
    ),
    child: Row(children: [
      Expanded(child: TextField(
        controller: keyController,
        obscureText: true,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: _fieldDeco("Clé de chiffrement", isDark: isDark),
      )),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: TextField(
        controller: messageController,
        style: const TextStyle(color: Colors.white),
        decoration: _fieldDeco("Message...", isDark: isDark),
        onSubmitted: (_) => sendMessage(),
      )),
      const SizedBox(width: 10),
      IconButton(onPressed: sendMessage, icon: const Icon(Icons.send, color: Colors.blue)),
    ]),
  );

  Widget _glassPanel({required Widget child, EdgeInsets? padding, required bool isDark}) =>
    Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF0D1B3E).withOpacity(0.6),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );

  InputDecoration _fieldDeco(String hint, {required bool isDark}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white.withOpacity(0.05),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}
