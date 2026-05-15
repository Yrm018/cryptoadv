import 'package:flutter/material.dart';

import '../../components/backround.dart';
import '../../core/localization/app_l10n.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../models/chat_message_model.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/user_avatar.dart';

class ChatMobile extends StatefulWidget {
  const ChatMobile({super.key});

  @override
  State<ChatMobile> createState() => _ChatMobileState();
}

class _ChatMobileState extends State<ChatMobile> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String? activeConversationId;
  bool showSidebar = true;

  /// 'symmetric' ou 'asymmetric'
  String _encryptionMode = 'symmetric';

  /// Algorithme symétrique
  String _algorithm = 'aes-gcm';

  bool? _currentUserHasRsa;
  bool? _receiverHasRsa;

  LocalUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().currentUser;
    if (mounted) setState(() => _currentUser = user);
    _checkCurrentUserRsa();
  }

  Future<void> _checkCurrentUserRsa() async {
    final hasKeys = await _chatService.currentUserHasRsaKeys();
    if (mounted) setState(() => _currentUserHasRsa = hasKeys);
  }

  void _checkReceiverRsa(String email) {
    final hasKeys = _chatService.receiverHasRsaKeys(email.trim().toLowerCase());
    if (mounted) setState(() => _receiverHasRsa = hasKeys);
  }

  @override
  void dispose() {
    emailController.dispose();
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

  Future<void> openConversation(AppL10n l) async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;
    try {
      final userDoc = _chatService.getUserByEmail(email);
      if (userDoc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.t('chat_err_user_not_found'))),
          );
        }
        return;
      }
      final id = await _chatService.getOrCreateConversation(
        userDoc['id'] as String, email,
      );
      _checkReceiverRsa(email);
      if (mounted) setState(() {
        activeConversationId = id;
        showSidebar = false;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> sendMessage(AppL10n l) async {
    final text  = messageController.text.trim();
    final email = emailController.text.trim();
    if (text.isEmpty || email.isEmpty) return;

    if (_encryptionMode == 'asymmetric') {
      if (_currentUserHasRsa == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('chat_rsa_missing_self'))),
        );
        return;
      }
      if (_receiverHasRsa == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('chat_rsa_missing_receiver'))),
        );
        return;
      }
    }

    try {
      await _chatService.sendMessage(
        receiverEmail: email,
        text:          text,
        mode:          _encryptionMode,
        algorithm:     _algorithm,
      );
      messageController.clear();
      _scrollToBottom();
    } catch (e) {
      final msg = e.toString();
      String displayed;
      if (msg.contains('rsa_keys_missing')) {
        displayed = l.t('chat_rsa_missing_self');
      } else if (msg.contains('rsa_receiver_no_keys')) {
        displayed = l.t('chat_rsa_missing_receiver');
      } else {
        displayed = "${l.t('chat_err_send')}$e";
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(displayed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);

    return Scaffold(
      drawer: const AppDrawer(currentPage: 'chat'),
      appBar: AppBar(
        title: Text(showSidebar ? l.t('chat_conversations') : emailController.text,
          overflow: TextOverflow.ellipsis),
        leading: showSidebar
          ? Builder(builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
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
              ? _buildSidebar(isDark, l)
              : _buildChatRoom(isDark, l),
          ),
        ],
      ),
    );
  }

  // ─── Sidebar ──────────────────────────────────────────────────────────────

  Widget _buildSidebar(bool isDark, AppL10n l) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      TextField(
        controller: emailController,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDeco(l.t('chat_search_hint'), isDark),
        onChanged: (v) => _checkReceiverRsa(v),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => openConversation(l),
          child: Text(l.t('chat_open_btn')),
        ),
      ),
      const Divider(height: 30, color: Colors.white24),
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getRecentConversations(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snap.data!.length,
            itemBuilder: (context, i) {
              final conv = snap.data![i];
              final otherId   = conv['otherUserId'] as String? ?? '';
              final photo     = otherId.isNotEmpty ? _chatService.getUserPhoto(otherId) : null;
              final nameStr   = conv['email'] as String? ?? '';
              return ListTile(
                leading: UserAvatar(
                  photoBase64:     photo,
                  initial:         nameStr,
                  radius:          20,
                  backgroundColor: Colors.blueGrey,
                ),
                title: Text(conv['email'],
                  style: const TextStyle(color: Colors.white)),
                subtitle: Text(conv['lastMessage'] ?? '',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  _checkReceiverRsa(conv['email'] as String);
                  setState(() {
                    activeConversationId = conv['conversationId'];
                    emailController.text = conv['email'];
                    showSidebar = false;
                  });
                },
              );
            },
          );
        },
      )),
    ]),
  );

  // ─── Chat room ────────────────────────────────────────────────────────────

  Widget _buildChatRoom(bool isDark, AppL10n l) => Column(children: [
    _chatRoomHeader(isDark, l),
    if (_encryptionMode == 'asymmetric') _rsaWarningBanner(l),
    Expanded(child: StreamBuilder<List<ChatMessageModel>>(
      stream: _chatService.getMessages(activeConversationId!),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: snap.data!.length,
          itemBuilder: (context, i) {
            final msg = snap.data![i];
            final isMe = msg.senderId == _currentUser?.id;
            return _bubble(msg, isMe, isDark, l);
          },
        );
      },
    )),
    _bottomBar(isDark, l),
  ]);

  Widget _chatRoomHeader(bool isDark, AppL10n l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    color: Colors.black26,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle Symétrique / Asymétrique
        Row(children: [
          Expanded(child: _modeBtn('symmetric',  l.t('chat_mode_symmetric'),  Icons.lock_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _modeBtn('asymmetric', l.t('chat_mode_asymmetric'), Icons.vpn_key_rounded)),
        ]),
        // Sous-algo visible seulement en symétrique
        if (_encryptionMode == 'symmetric') ...[
          const SizedBox(height: 8),
          Row(children: [
            Text(l.t('chat_algorithm'),
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const SizedBox(width: 8),
            _algoBtn('aes-gcm', 'AES-GCM'),
            const SizedBox(width: 6),
            _algoBtn('chacha20', 'ChaCha20'),
          ]),
        ],
      ],
    ),
  );

  Widget _modeBtn(String mode, String label, IconData icon) {
    final active = _encryptionMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _encryptionMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.blue : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _algoBtn(String val, String label) {
    final active = _algorithm == val;
    return GestureDetector(
      onTap: () => setState(() => _algorithm = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent : Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ),
    );
  }

  Widget _rsaWarningBanner(AppL10n l) {
    final selfMissing     = _currentUserHasRsa == false;
    final receiverMissing = _receiverHasRsa == false;
    if (!selfMissing && !receiverMissing) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.orange.withOpacity(0.15),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(
          selfMissing ? l.t('chat_rsa_missing_self') : l.t('chat_rsa_missing_receiver'),
          style: const TextStyle(color: Colors.orange, fontSize: 11),
        )),
      ]),
    );
  }

  Widget _bubble(ChatMessageModel msg, bool isMe, bool isDark, AppL10n l) {
    final isAsymmetric = msg.encryptionMode == 'asymmetric';
    final badgeColor   = isAsymmetric ? Colors.purpleAccent : Colors.greenAccent;
    final badgeLabel   = isAsymmetric ? 'RSA+AES' : msg.algorithm.toUpperCase();

    final senderPhoto = isMe ? null : _chatService.getUserPhoto(msg.senderId);
    final senderName  = msg.senderName.isNotEmpty ? msg.senderName : msg.senderEmail;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(
              photoBase64:     senderPhoto,
              initial:         senderName,
              radius:          12,
              backgroundColor: Colors.blueGrey,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: badgeColor.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isAsymmetric ? Icons.vpn_key_rounded : Icons.lock_rounded,
                  size: 9, color: badgeColor),
                const SizedBox(width: 3),
                Text(badgeLabel,
                  style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 3),
            // Bulle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.white10,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(14),
                  topRight:    const Radius.circular(14),
                  bottomLeft:  Radius.circular(isMe ? 14 : 3),
                  bottomRight: Radius.circular(isMe ? 3 : 14),
                ),
              ),
              child: FutureBuilder<String>(
                future: _chatService.decryptMessage(msg),
                builder: (context, snap) {
                  if (snap.data == null) {
                    return const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    );
                  }
                  return Text(snap.data!,
                    style: const TextStyle(color: Colors.white, fontSize: 14));
                },
              ),
            ),
          ],
        ))),

          if (!isMe) const SizedBox(width: 16),

          if (isMe) ...[
            const SizedBox(width: 4),
            UserAvatar(
              photoBase64:     _currentUser != null
                  ? _chatService.getUserPhoto(_currentUser!.id)
                  : null,
              initial:         _currentUser?.username ?? '?',
              radius:          12,
              backgroundColor: Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar(bool isDark, AppL10n l) => Container(
    padding: const EdgeInsets.all(10),
    color: Colors.black45,
    child: Row(children: [
      Expanded(child: TextField(
        controller: messageController,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDeco(l.t('chat_message_hint'), isDark, small: true),
        onSubmitted: (_) => sendMessage(l),
        textInputAction: TextInputAction.send,
      )),
      IconButton(
        onPressed: () => sendMessage(l),
        icon: const Icon(Icons.send_rounded, color: Colors.blue),
      ),
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
