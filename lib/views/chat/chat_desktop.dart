import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Pour kIsWeb
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Pour les téléchargements sur le Web
import 'package:record/record.dart'; // Pour l'enregistrement vocal
import 'package:path_provider/path_provider.dart'; // Pour le stockage temporaire

import '../../components/backround.dart';
import '../../core/localization/app_l10n.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_navbar.dart';
import '../../models/chat_message_model.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/chat/audio_player_widget.dart'; // Nouveau widget audio

class ChatDesktop extends StatefulWidget {
  const ChatDesktop({super.key});

  @override
  State<ChatDesktop> createState() => _ChatDesktopState();
}

class _ChatDesktopState extends State<ChatDesktop> {
  final ChatService _chatService = ChatService.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String? activeConversationId;
  bool isLoadingConversation = false;

  /// Fichiers en attente d'envoi
  final List<PlatformFile> _selectedFiles = [];

  String _encryptionMode = 'symmetric';
  String _algorithm = 'aes-gcm';
  bool? _currentUserHasRsa;
  bool? _receiverHasRsa;
  LocalUser? _currentUser;

  // NOUVEAU : Variables pour l'enregistrement vocal
  late AudioRecorder audioRecorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    audioRecorder = AudioRecorder();
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

  Future<void> _checkReceiverRsa(String email) async {
    final hasKeys = await _chatService.receiverHasRsaKeys(email.trim().toLowerCase());
    if (mounted) setState(() => _receiverHasRsa = hasKeys);
  }

  @override
  void dispose() {
    emailController.dispose();
    messageController.dispose();
    _scrollController.dispose();
    audioRecorder.dispose(); // Libérer les ressources audio
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

  // ─── NOUVEAU : Méthodes d'enregistrement vocal ────────────────────────────

  Future<void> _startRecording() async {
    if (activeConversationId == null) return;
    try {
      if (await audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        const config = RecordConfig(); // Config par défaut (m4a)

        await audioRecorder.start(config, path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint("Erreur record start: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null && emailController.text.isNotEmpty) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        final base64Audio = base64Encode(bytes);

        await _chatService.sendMessage(
          receiverEmail: emailController.text.trim(),
          text: base64Audio,
          mode: _encryptionMode,
          algorithm: _algorithm,
          type: 'audio',
          fileName: 'vocal.m4a',
          fileSize: bytes.length,
        );
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Erreur record stop: $e");
    }
  }

  // ──────────────────────────────────────────────────────────────────────────

  Future<void> openConversationFromEmail(AppL10n l) async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => isLoadingConversation = true);
    try {
      final userDoc = await _chatService.getUserByEmail(email);
      if (userDoc == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('chat_err_user_not_found'))),
        );
        return;
      }
      final conversationId = await _chatService.getOrCreateConversation(
        userDoc['id'] as String,
        email,
      );
      await _checkReceiverRsa(email);
      if (mounted) setState(() => activeConversationId = conversationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${l.t('error_prefix')} : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoadingConversation = false);
    }
  }

  Future<void> sendMessage(AppL10n l) async {
    final text = messageController.text.trim();
    final email = emailController.text.trim();
    
    if (email.isEmpty) return;
    if (text.isEmpty && _selectedFiles.isEmpty) return;

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
      if (text.isNotEmpty) {
        await _chatService.sendMessage(
          receiverEmail: email,
          text: text,
          mode: _encryptionMode,
          algorithm: _algorithm,
        );
      }

      for (var file in _selectedFiles) {
        if (file.bytes == null) continue;
        final base64File = base64Encode(file.bytes!);
        final fileName = file.name;
        
        String type = 'file';
        final ext = fileName.split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
          type = 'image';
        } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
          type = 'video';
        }

        await _chatService.sendMessage(
          receiverEmail: email,
          text: base64File,
          mode: _encryptionMode,
          algorithm: _algorithm,
          type: type,
          fileName: fileName,
          fileSize: file.size,
        );
      }

      setState(() {
        messageController.clear();
        _selectedFiles.clear();
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${l.t('chat_err_send')}$e")),
        );
      }
    }
  }

  Future<void> _pickFiles(AppL10n l) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: true,
    );

    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.files);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  // ─── Gestion des téléchargements et prévisualisation ──────────────────────

  Future<void> _handleDownload(String base64Data, String fileName) async {
    try {
      if (kIsWeb) {
        final uri = Uri.parse('data:application/octet-stream;base64,$base64Data');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } else {
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Enregistrer le fichier',
          fileName: fileName,
        );
        if (outputPath != null) {
          final file = File(outputPath);
          await file.writeAsBytes(base64Decode(base64Data));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fichier enregistré avec succès !')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement : $e')),
        );
      }
    }
  }

  void _showMediaPreview(String base64Data, String fileName, String type) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (type == 'image')
              InteractiveViewer(
                child: Image.memory(base64Decode(base64Data)),
              )
            else
              const Center(
                child: Text('Prévisualisation vidéo non implémentée',
                    style: TextStyle(color: Colors.white)),
              ),
            
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 30),
                    onPressed: () => _handleDownload(base64Data, fileName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
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
                backgroundColor:
                    isDark ? const Color(0xFF7AA6FF) : const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: Text(l.t('chat_open_btn')),
            ),
          ),
          const Divider(height: 30, color: Colors.white10),
          Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.getRecentConversations(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
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
    final otherId = conv['otherUserId'] as String? ?? '';
    final photo = otherId.isNotEmpty ? _chatService.getUserPhoto(otherId) : null;
    final nameStr = conv['email'] as String? ?? '';
    return ListTile(
      selected: active,
      selectedTileColor: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: UserAvatar(
        photoBase64: photo,
        initial: nameStr,
        radius: 18,
        backgroundColor: active ? Colors.blue : Colors.grey,
      ),
      title: Text(conv['email'],
          style: const TextStyle(color: Colors.white, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(conv['lastMessage'] ?? '',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      onTap: () async {
        setState(() {
          activeConversationId = id;
          emailController.text = conv['email'];
        });
        await _checkReceiverRsa(conv['email'] as String);
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
            Row(children: [
              Text(l.t('chat_encrypted_title'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              _modeToggle(isDark, l),
            ]),
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
        _modeChip('symmetric', l.t('chat_mode_symmetric'), Icons.lock_rounded,
            isDark),
        _modeChip('asymmetric', l.t('chat_mode_asymmetric'),
            Icons.vpn_key_rounded, isDark),
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
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );
  }

  Widget _rsaWarningBanner(bool isDark, AppL10n l) {
    final selfMissing = _currentUserHasRsa == false;
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
          const Icon(Icons.chat_bubble_outline_rounded,
              size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(l.t('chat_select_conv'),
              style: const TextStyle(color: Colors.white38)),
        ]),
      );
    }
    return StreamBuilder<List<ChatMessageModel>>(
      stream: _chatService.getMessages(activeConversationId!),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final msgs = snap.data!;
        _scrollToBottom();
        // Dernier message envoyé par moi qui a été lu par le destinataire
        int lastReadSentIdx = -1;
        for (int j = msgs.length - 1; j >= 0; j--) {
          if (msgs[j].senderId == _currentUser?.id && msgs[j].readAt != null) {
            lastReadSentIdx = j;
            break;
          }
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: msgs.length,
          itemBuilder: (context, i) => _msgBubble(
              msgs[i], _currentUser?.id == msgs[i].senderId, isDark, l,
              showVu: i == lastReadSentIdx),
        );
      },
    );
  }

  Widget _msgBubble(ChatMessageModel msg, bool isMe, bool isDark, AppL10n l, {bool showVu = false}) {
    final isAsymmetric = msg.encryptionMode == 'asymmetric';
    final badgeColor = isAsymmetric ? Colors.purpleAccent : Colors.greenAccent;
    final badgeLabel = isAsymmetric ? 'RSA+AES' : msg.algorithm.toUpperCase();

    final senderPhoto = isMe ? null : _chatService.getUserPhoto(msg.senderId);
    final senderName =
        msg.senderName.isNotEmpty ? msg.senderName : msg.senderEmail;

    return GestureDetector(
      onLongPress: () => _showDeleteMenu(msg, isMe, l),
      child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(
              photoBase64: senderPhoto,
              initial: senderName,
              radius: 14,
              backgroundColor: Colors.blueGrey,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
              child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        isAsymmetric
                            ? Icons.vpn_key_rounded
                            : Icons.lock_rounded,
                        size: 10,
                        color: badgeColor),
                    const SizedBox(width: 4),
                    Text(badgeLabel,
                        style: TextStyle(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue : Colors.white10,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: FutureBuilder<String>(
                    future: _chatService.decryptMessage(msg),
                    builder: (context, snap) {
                      final decrypted = snap.data;
                      if (decrypted == null) {
                        return const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white54),
                        );
                      }

                      // MODIFICATION : Gestion de l'audio déchiffré
                      if (msg.type == 'audio') {
                        return AudioPlayerWidget(base64Data: decrypted, isMe: isMe);
                      }

                      if (msg.type == 'image') {
                        return _imageBubble(decrypted, msg);
                      } else if (msg.type == 'file' || msg.type == 'video') {
                        return InkWell(
                          onTap: () => _handleDownload(decrypted, msg.fileName ?? 'file'),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                                msg.type == 'video'
                                    ? Icons.video_library_rounded
                                    : Icons.insert_drive_file_rounded,
                                color: Colors.white,
                                size: 20),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(msg.fileName ?? 'Fichier',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ),
                          ]),
                        );
                      }

                      return Text(decrypted,
                          style:
                              const TextStyle(color: Colors.white, fontSize: 14));
                    },
                  ),
                ),
                if (msg.createdAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${msg.createdAt!.hour.toString().padLeft(2, '0')}:${msg.createdAt!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
                if (showVu) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.done_all_rounded, size: 11, color: Colors.lightBlueAccent),
                      const SizedBox(width: 3),
                      Text(
                        'Vu ${_formatReadAt(msg.readAt)}',
                        style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          )),
          if (!isMe) const SizedBox(width: 20),
          if (isMe) ...[
            const SizedBox(width: 6),
            UserAvatar(
              photoBase64: _currentUser != null
                  ? _chatService.getUserPhoto(_currentUser!.id)
                  : null,
              initial: _currentUser?.username ?? '?',
              radius: 14,
              backgroundColor: Colors.blue,
            ),
          ],
        ],
      ),
    ));
  }

  // ─── Image bubble (taille fixe, tap pour agrandir) ────────────────────────

  Widget _imageBubble(String base64Data, ChatMessageModel msg) {
    if (base64Data.startsWith('🔒') || base64Data.startsWith('🔐')) {
      return Container(
        width: 220, height: 160,
        decoration: BoxDecoration(
          color: Colors.white10, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_rounded, color: Colors.white38, size: 32),
          SizedBox(height: 6),
          Text('Image chiffrée', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      );
    }
    try {
      final bytes = base64Decode(base64Data);
      return GestureDetector(
        onTap: () => _showMediaPreview(base64Data, msg.fileName ?? 'image.png', 'image'),
        child: Container(
          width: 220, height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white38, size: 32)),
            ),
          ),
        ),
      );
    } catch (_) {
      return Container(
        width: 220, height: 160,
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 32)),
      );
    }
  }

  // ─── Suppression d'un message ─────────────────────────────────────────────

  void _showDeleteMenu(ChatMessageModel msg, bool isMe, AppL10n l) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Message', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMe) ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              title: const Text('Supprimer pour tout le monde',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _chatService.deleteMessageForEveryone(msg.id, activeConversationId!);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.orange),
              title: const Text('Supprimer pour moi',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await _chatService.deleteMessageForMe(msg.id, activeConversationId!);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  /// Format "14:32" ou "12/05 14:32" si hier ou avant
  String _formatReadAt(DateTime? readAt) {
    if (readAt == null) return '';
    final local = readAt.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  // ─── Input ────────────────────────────────────────────────────────────────

  Widget _chatInput(bool isDark, AppL10n l) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedFiles.isNotEmpty) _buildSelectedFilesPreview(l),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(children: [
              // Bouton "+" (Fichiers)
              IconButton(
                onPressed: () => _pickFiles(l),
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white54, size: 26),
                tooltip: 'Ajouter des fichiers',
              ),
              // NOUVEAU : Bouton Microphone
              IconButton(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                icon: Icon(
                  _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                  color: _isRecording ? Colors.red : Colors.white54,
                  size: 26,
                ),
                tooltip: 'Message vocal',
              ),
              const SizedBox(width: 5),
              Expanded(
                  child: TextField(
                controller: messageController,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDeco(
                  _isRecording ? 'Enregistrement en cours...' : l.t('chat_message_hint'), 
                  isDark: isDark
                ),
                onSubmitted: (_) => sendMessage(l),
                enabled: !_isRecording,
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
          ),
        ],
      );

  Widget _buildSelectedFilesPreview(AppL10n l) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: () => _pickFiles(l),
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white70),
            ),
          ),
          ..._selectedFiles.asMap().entries.map((entry) {
            return _filePreviewItem(entry.value, entry.key);
          }).toList(),
        ],
      ),
    );
  }

  Widget _filePreviewItem(PlatformFile file, int index) {
    final ext = file.name.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 75,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isImage && file.bytes != null
                  ? Image.memory(file.bytes!, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.insert_drive_file_rounded, color: Colors.white60, size: 28),
                        Text(file.name, 
                          style: const TextStyle(color: Colors.white, fontSize: 8),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => _removeFile(index),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _glassPanel(
          {required Widget child, EdgeInsets? padding, required bool isDark}) =>
      Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF0D1B3E).withOpacity(0.6),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      );

  InputDecoration _fieldDeco(String hint, {required bool isDark}) =>
      InputDecoration(
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
