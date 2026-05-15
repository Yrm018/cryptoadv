import 'package:flutter/material.dart';

import '../../components/backround.dart';
import '../../core/localization/app_l10n.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_navbar.dart';
import '../../models/chat_message_model.dart';
import '../../widgets/common/user_avatar.dart';

class ChatDesktop extends StatefulWidget {
  const ChatDesktop({super.key});

  @override
  State<ChatDesktop> createState() => _ChatDesktopState();
}

class _ChatDesktopState extends State<ChatDesktop> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String? activeConversationId;
  bool isLoadingConversation = false;

  /// 'symmetric' ou 'asymmetric'
  String _encryptionMode = 'symmetric';

  /// Algorithme symétrique : 'aes-gcm' ou 'chacha20'
  String _algorithm = 'aes-gcm';

  /// Statut des clés RSA de l'utilisateur courant
  bool? _currentUserHasRsa;

  /// Statut des clés RSA du destinataire actuel
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

  Future<void> openConversationFromEmail(AppL10n l) async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => isLoadingConversation = true);
    try {
      final userDoc = _chatService.getUserByEmail(email);
      if (userDoc == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('chat_err_user_not_found'))),
        );
        return;
      }
      final conversationId = await _chatService.getOrCreateConversation(
        userDoc['id'] as String, email,
      );
      _checkReceiverRsa(email);
      if (mounted) setState(() => activeConversationId = conversationId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${l.t('error_prefix')} : $e")),
      );
    } finally {
      if (mounted) setState(() => isLoadingConversation = false);
    }
  }

  Future<void> sendMessage(AppL10n l) async {
    final text  = messageController.text.trim();
    final email = emailController.text.trim();
    if (text.isEmpty || email.isEmpty) return;

    // Vérifications RSA avant envoi asymétrique
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
        receiverEmail:  email,
        text:           text,
        mode:           _encryptionMode,
        algorithm:      _algorithm,
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);

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
                        SizedBox(width: 300, child: _buildSidebar(isDark, l)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildChatPanel(isDark, l)),
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

  // ─── Sidebar ──────────────────────────────────────────────────────────────

  Widget _buildSidebar(bool isDark, AppL10n l) => _glassPanel(
    isDark: isDark,
    child: Column(children: [
      Row(children: [
        Icon(Icons.forum_rounded,
          color: isDark ? const Color(0xFF7AA6FF) : const Color(0xFF2563EB),
          size: 18),
        const SizedBox(width: 10),
        Text(l.t('chat_conversations'),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 16),
      TextField(
        controller: emailController,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: _fieldDeco(l.t('chat_search_hint'), isDark: isDark),
        onChanged: (v) => _checkReceiverRsa(v),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => openConversationFromEmail(l),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF7AA6FF) : const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          child: Text(l.t('chat_open_btn')),
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
    final id       = conv['conversationId'];
    final active   = activeConversationId == id;
    final otherId  = conv['otherUserId'] as String? ?? '';
    final photo    = otherId.isNotEmpty ? _chatService.getUserPhoto(otherId) : null;
    final nameStr  = conv['email'] as String? ?? '';
    return ListTile(
      selected: active,
      selectedTileColor: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: UserAvatar(
        photoBase64:     photo,
        initial:         nameStr,
        radius:          18,
        backgroundColor: active ? Colors.blue : Colors.grey,
      ),
      title: Text(conv['email'],
        style: const TextStyle(color: Colors.white, fontSize: 13),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(conv['lastMessage'] ?? '',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        setState(() {
          activeConversationId = id;
          emailController.text = conv['email'];
        });
        _checkReceiverRsa(conv['email'] as String);
      },
    );
  }

  // ─── Chat panel ───────────────────────────────────────────────────────────

  Widget _buildChatPanel(bool isDark, AppL10n l) => _glassPanel(
    isDark: isDark,
    padding: EdgeInsets.zero,
    child: Column(children: [
      _chatHeader(isDark, l),
      if (_encryptionMode == 'asymmetric') _rsaWarningBanner(isDark, l),
      Expanded(child: _buildMessagesArea(isDark, l)),
      _chatInput(isDark, l),
    ]),
  );

  Widget _chatHeader(bool isDark, AppL10n l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.white10)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne 1 : titre + toggle mode
        Row(children: [
          Text(l.t('chat_encrypted_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          _modeToggle(isDark, l),
        ]),
        // Ligne 2 : sous-algo (visible seulement en symétrique)
        if (_encryptionMode == 'symmetric') ...[
          const SizedBox(height: 10),
          Row(children: [
            Text(l.t('chat_algorithm'),
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(width: 10),
            _algoChip('aes-gcm', 'AES-GCM', isDark),
            const SizedBox(width: 8),
            _algoChip('chacha20', 'ChaCha20', isDark),
          ]),
        ],
      ],
    ),
  );

  Widget _modeToggle(bool isDark, AppL10n l) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _modeChip('symmetric',   l.t('chat_mode_symmetric'),   Icons.lock_rounded, isDark),
        _modeChip('asymmetric',  l.t('chat_mode_asymmetric'),  Icons.vpn_key_rounded, isDark),
      ]),
    );
  }

  Widget _modeChip(String mode, String label, IconData icon, bool isDark) {
    final active = _encryptionMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _encryptionMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _algoChip(String val, String label, bool isDark) {
    final active = _algorithm == val;
    return GestureDetector(
      onTap: () => setState(() => _algorithm = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent : Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );
  }

  Widget _rsaWarningBanner(bool isDark, AppL10n l) {
    final selfMissing     = _currentUserHasRsa == false;
    final receiverMissing = _receiverHasRsa == false;
    if (!selfMissing && !receiverMissing) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.withOpacity(0.15),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            selfMissing
              ? l.t('chat_rsa_missing_self')
              : l.t('chat_rsa_missing_receiver'),
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  // ─── Messages area ────────────────────────────────────────────────────────

  Widget _buildMessagesArea(bool isDark, AppL10n l) {
    if (activeConversationId == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(l.t('chat_select_conv'),
            style: const TextStyle(color: Colors.white38)),
        ]),
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
            _msgBubble(msgs[i], _currentUser?.id == msgs[i].senderId, isDark, l),
        );
      },
    );
  }

  Widget _msgBubble(ChatMessageModel msg, bool isMe, bool isDark, AppL10n l) {
    final isAsymmetric = msg.encryptionMode == 'asymmetric';
    final badgeColor   = isAsymmetric ? Colors.purpleAccent : Colors.greenAccent;
    final badgeLabel   = isAsymmetric ? 'RSA+AES' : msg.algorithm.toUpperCase();

    // Photo de l'expéditeur (affichée seulement pour les messages reçus)
    final senderPhoto  = isMe ? null : _chatService.getUserPhoto(msg.senderId);
    final senderName   = msg.senderName.isNotEmpty ? msg.senderName : msg.senderEmail;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar à gauche pour les messages reçus
          if (!isMe) ...[
            UserAvatar(
              photoBase64:     senderPhoto,
              initial:         senderName,
              radius:          14,
              backgroundColor: Colors.blueGrey,
            ),
            const SizedBox(width: 6),
          ],

          Flexible(child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
            // Badge chiffrement
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isAsymmetric ? Icons.vpn_key_rounded : Icons.lock_rounded,
                  size: 10, color: badgeColor),
                const SizedBox(width: 4),
                Text(badgeLabel,
                  style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 4),
            // Bulle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.white10,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: FutureBuilder<String>(
                future: _chatService.decryptMessage(msg),
                builder: (context, snap) {
                  final text = snap.data;
                  if (text == null) {
                    return const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    );
                  }
                  return Text(text,
                    style: const TextStyle(color: Colors.white, fontSize: 14));
                },
              ),
            ),
              // Heure
              if (msg.createdAt != null) ...[
                const SizedBox(height: 3),
                Text(
                  '${msg.createdAt!.hour.toString().padLeft(2, '0')}:${msg.createdAt!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ],
          ))),

          // Espace à droite pour les messages reçus (symétrie)
          if (!isMe) const SizedBox(width: 20),

          // Avatar à droite pour mes messages
          if (isMe) ...[
            const SizedBox(width: 6),
            UserAvatar(
              photoBase64:     _currentUser != null
                  ? _chatService.getUserPhoto(_currentUser!.id)
                  : null,
              initial:         _currentUser?.username ?? '?',
              radius:          14,
              backgroundColor: Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Input ────────────────────────────────────────────────────────────────

  Widget _chatInput(bool isDark, AppL10n l) => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white10)),
    ),
    child: Row(children: [
      Expanded(child: TextField(
        controller: messageController,
        style: const TextStyle(color: Colors.white),
        decoration: _fieldDeco(l.t('chat_message_hint'), isDark: isDark),
        onSubmitted: (_) => sendMessage(l),
        maxLines: null,
        textInputAction: TextInputAction.send,
      )),
      const SizedBox(width: 10),
      IconButton(
        onPressed: () => sendMessage(l),
        icon: const Icon(Icons.send_rounded, color: Colors.blue),
        tooltip: l.t('chat_send_btn'),
      ),
    ]),
  );

  // ─── Helpers ──────────────────────────────────────────────────────────────

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
