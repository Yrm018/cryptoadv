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
import '../../models/chat_message_model.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/chat/audio_player_widget.dart'; // Nouveau widget audio

class ChatMobile extends StatefulWidget {
  const ChatMobile({super.key});

  @override
  State<ChatMobile> createState() => _ChatMobileState();
}

class _ChatMobileState extends State<ChatMobile> {
  final ChatService _chatService = ChatService.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String? activeConversationId;
  String? _activeConvName;
  bool showSidebar = true;

  /// Fichiers en attente d'envoi (File d'attente style Messenger)
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
    audioRecorder.dispose(); // Libérer les ressources
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
    try {
      if (await audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        const config = RecordConfig(); // Config par défaut (aac/m4a)

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

      if (path != null && activeConversationId != null) {
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

  Future<void> openConversation(AppL10n l) async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;
    try {
      final userDoc = await _chatService.getUserByEmail(email);
      if (userDoc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.t('chat_err_user_not_found'))),
          );
        }
        return;
      }
      final id = await _chatService.getOrCreateConversation(
        userDoc['id'] as String,
        email,
      );
      await _checkReceiverRsa(email);
      if (mounted) {
        setState(() {
          activeConversationId = id;
          showSidebar = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
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
      // 1. Envoyer le message texte si présent
      if (text.isNotEmpty) {
        await _chatService.sendMessage(
          receiverEmail: email,
          text: text,
          mode: _encryptionMode,
          algorithm: _algorithm,
        );
      }

      // 2. Envoyer chaque fichier de la file d'attente
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

      // Réinitialisation après envoi
      setState(() {
        messageController.clear();
        _selectedFiles.clear();
      });
      _scrollToBottom();
    } catch (e) {
      final msg = e.toString();
      String displayed = "${l.t('chat_err_send')}$msg";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(displayed)),
        );
      }
    }
  }

  /// Sélection de plusieurs fichiers
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

  // ─── GESTION TÉLÉCHARGEMENT ET PRÉVISUALISATION ───────────────────────────

  /// Gère l'enregistrement du fichier déchiffré
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
          final bytes = base64Decode(base64Data);
          await File(outputPath).writeAsBytes(bytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fichier enregistré !')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  /// Affiche le média en plein écran
  void _showMediaPreview(String base64Data, String fileName, String type) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (type == 'image')
              InteractiveViewer(
                child: Image.memory(base64Decode(base64Data)),
              )
            else
              const Center(
                child: Text('Lecture vidéo non supportée en aperçu direct',
                    style: TextStyle(color: Colors.white)),
              ),
            Positioned(
              top: 40,
              right: 20,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 30),
                    onPressed: () => _handleDownload(base64Data, fileName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
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

  String _formatFileSize(int? size) {
    if (size == null) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);

    return Scaffold(
      drawer: const AppDrawer(currentPage: 'chat'),
      appBar: AppBar(
        title: Text(
            showSidebar ? l.t('chat_conversations') : (_activeConvName ?? emailController.text),
            overflow: TextOverflow.ellipsis),
        leading: showSidebar
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
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
          Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.getRecentConversations(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                itemCount: snap.data!.length,
                itemBuilder: (context, i) {
                  final conv = snap.data![i];
                  final otherId = conv['otherUserId'] as String? ?? '';
                  final photo =
                      otherId.isNotEmpty ? _chatService.getUserPhoto(otherId) : null;
                  final nameStr = conv['name'] as String? ?? conv['email'] as String? ?? '';
                  return Dismissible(
                    key: Key(conv['conversationId'] as String),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E2E),
                          title: const Text('Supprimer la conversation',
                              style: TextStyle(color: Colors.white)),
                          content: const Text(
                              'Cette action supprimera la conversation pour les deux utilisateurs.',
                              style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Annuler')),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Supprimer',
                                  style: TextStyle(color: Colors.redAccent))),
                          ],
                        ),
                      ) ?? false;
                    },
                    onDismissed: (_) async {
                      try {
                        await _chatService.deleteConversation(
                            conv['conversationId'] as String);
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur : $e'),
                              backgroundColor: Colors.redAccent));
                      }
                    },
                    child: ListTile(
                      leading: UserAvatar(
                        photoBase64: photo,
                        initial: nameStr,
                        radius: 20,
                        backgroundColor: Colors.blueGrey,
                      ),
                      title: Text(nameStr,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(conv['lastMessage'] ?? '',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      onTap: () {
                        _checkReceiverRsa(conv['email'] as String);
                        setState(() {
                          activeConversationId = conv['conversationId'];
                          emailController.text = conv['email'] as String;
                          _activeConvName = conv['name'] as String?;
                          showSidebar = false;
                        });
                      },
                    ),
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
        Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
          stream: _chatService.getMessages(activeConversationId!),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            _scrollToBottom();
            final msgs = snap.data!;
            // Trouver le dernier message envoyé par moi qui a été vu
            int lastReadSentIdx = -1;
            for (int j = msgs.length - 1; j >= 0; j--) {
              if (msgs[j].senderId == _currentUser?.id && msgs[j].readAt != null) {
                lastReadSentIdx = j;
                break;
              }
            }
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length,
              itemBuilder: (context, i) {
                final msg = msgs[i];
                final isMe = msg.senderId == _currentUser?.id;
                final showVu = isMe && i == lastReadSentIdx;
                return _bubble(msg, isMe, isDark, l, showVu: showVu);
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
            Row(children: [
              Expanded(
                  child: _modeBtn(
                      'symmetric', l.t('chat_mode_symmetric'), Icons.lock_rounded)),
              const SizedBox(width: 8),
              Expanded(
                  child: _modeBtn('asymmetric', l.t('chat_mode_asymmetric'),
                      Icons.vpn_key_rounded)),
            ]),
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
        child: Row(mainAxisSize: MainAxisSize.max, children: [
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
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 10)),
      ),
    );
  }

  Widget _rsaWarningBanner(AppL10n l) {
    final selfMissing = _currentUserHasRsa == false;
    final receiverMissing = _receiverHasRsa == false;
    if (!selfMissing && !receiverMissing) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.orange.withOpacity(0.15),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
        const SizedBox(width: 6),
        Expanded(
            child: Text(
          selfMissing
              ? l.t('chat_rsa_missing_self')
              : l.t('chat_rsa_missing_receiver'),
          style: const TextStyle(color: Colors.orange, fontSize: 11),
        )),
      ]),
    );
  }

  /// Affiche le menu de suppression au long press
  void _showDeleteMenu(ChatMessageModel msg, bool isMe, AppL10n l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.white38),
              title: const Text('Annuler', style: TextStyle(color: Colors.white54)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessageModel msg, bool isMe, bool isDark, AppL10n l, {bool showVu = false}) {
    final isAsymmetric = msg.encryptionMode == 'asymmetric';
    final badgeColor = isAsymmetric ? Colors.purpleAccent : Colors.greenAccent;
    final badgeLabel = isAsymmetric ? 'RSA+AES' : msg.algorithm.toUpperCase();

    final senderPhoto = isMe ? null : _chatService.getUserPhoto(msg.senderId);
    final senderName =
        msg.senderName.isNotEmpty ? msg.senderName : msg.senderEmail;

    return GestureDetector(
      onLongPress: () => _showDeleteMenu(msg, isMe, l),
      child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(
              photoBase64: senderPhoto,
              initial: senderName,
              radius: 12,
              backgroundColor: Colors.blueGrey,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
              child: Container(
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        isAsymmetric
                            ? Icons.vpn_key_rounded
                            : Icons.lock_rounded,
                        size: 9,
                        color: badgeColor),
                    const SizedBox(width: 3),
                    Text(badgeLabel,
                        style: TextStyle(
                            color: badgeColor,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 3),
                
                // Corps du message
                FutureBuilder<String>(
                  future: _chatService.decryptMessage(msg),
                  builder: (context, snap) {
                    final decrypted = snap.data;
                    if (decrypted == null) {
                      return const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                      );
                    }

                    // NOUVEAU : Gestion de l'audio déchiffré
                    if (msg.type == 'audio') {
                      return AudioPlayerWidget(base64Data: decrypted, isMe: isMe);
                    }

                    // AFFICHAGE INTERACTIF (Image/Fichier)
                    if (msg.type == 'image') {
                      return _imageBubble(decrypted, msg, isMe);
                    } else if (msg.type == 'file' || msg.type == 'video') {
                      return _fileBubble(decrypted, msg, isMe, isDark);
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue : Colors.white10,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(isMe ? 14 : 3),
                          bottomRight: Radius.circular(isMe ? 3 : 14),
                        ),
                      ),
                      child: Text(decrypted,
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                    );
                  },
                ),

                // Indicateur "Vu ✓✓" sous le dernier message envoyé et lu
                if (showVu) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.done_all_rounded, size: 12, color: Colors.lightBlueAccent),
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
          if (!isMe) const SizedBox(width: 16),
          if (isMe) ...[
            const SizedBox(width: 4),
            UserAvatar(
              photoBase64: _currentUser != null
                  ? _chatService.getUserPhoto(_currentUser!.id)
                  : null,
              initial: _currentUser?.username ?? '?',
              radius: 12,
              backgroundColor: Colors.blue,
            ),
          ],
        ],
      ),
    ));
  }

  /// Formater l'heure de lecture pour l'affichage "Vu 14:32"
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

  /// Bulle Image mobile
  Widget _imageBubble(String base64Data, ChatMessageModel msg, bool isMe) {
    // Si le déchiffrement a échoué, afficher un placeholder propre
    if (base64Data.startsWith('🔒') || base64Data.startsWith('🔐')) {
      return Container(
        width: 180,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_rounded, color: Colors.white38, size: 28),
          const SizedBox(height: 6),
          Text('Image chiffrée', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      );
    }

    try {
      final bytes = base64Decode(base64Data);
      return GestureDetector(
        onTap: () => _showMediaPreview(base64Data, msg.fileName ?? 'image.png', 'image'),
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 180, height: 120,
                child: Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 28)),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      return Container(
        width: 180, height: 120,
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
        child: const Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 28)),
      );
    }
  }

  /// Bulle Fichier mobile
  Widget _fileBubble(String base64, ChatMessageModel msg, bool isMe, bool isDark) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue.withOpacity(0.85) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            msg.type == 'video' ? Icons.play_circle_fill : Icons.insert_drive_file,
            color: isMe ? Colors.white : Colors.blue,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg.fileName ?? 'Fichier',
                  style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_formatFileSize(msg.fileSize),
                  style: TextStyle(color: isMe ? Colors.white70 : Colors.black54, fontSize: 10)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.download_rounded, color: isMe ? Colors.white : Colors.blue, size: 20),
            onPressed: () => _handleDownload(base64, msg.fileName ?? 'fichier'),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(bool isDark, AppL10n l) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedFiles.isNotEmpty) _buildSelectedFilesPreview(l),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.black45,
            child: Row(children: [
              IconButton(
                onPressed: () => _pickFiles(l),
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: Colors.white54, size: 24),
                tooltip: 'Ajouter des fichiers',
              ),
              // NOUVEAU : Bouton Microphone
              IconButton(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                icon: Icon(
                  _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                  color: _isRecording ? Colors.red : Colors.white54,
                  size: 24,
                ),
                tooltip: 'Message vocal',
              ),
              const SizedBox(width: 5),
              Expanded(
                  child: TextField(
                controller: messageController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco(
                  _isRecording ? 'Enregistrement...' : l.t('chat_message_hint'), 
                  isDark, 
                  small: true
                ),
                onSubmitted: (_) => sendMessage(l),
                enabled: !_isRecording,
                textInputAction: TextInputAction.send,
              )),
              IconButton(
                onPressed: () => sendMessage(l),
                icon: const Icon(Icons.send_rounded, color: Colors.blue),
              ),
            ]),
          ),
        ],
      );

  Widget _buildSelectedFilesPreview(AppL10n l) {
    return Container(
      height: 80,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white10,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: () => _pickFiles(l),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white70),
            ),
          ),
          ..._selectedFiles.asMap().entries.map((entry) {
            int index = entry.key;
            var file = entry.value;
            final ext = file.name.split('.').last.toLowerCase();
            final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: isImage && file.bytes != null
                          ? Image.memory(file.bytes!, fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.insert_drive_file_rounded,
                                    color: Colors.white70, size: 20),
                                Text(file.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 7),
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
          }).toList(),
        ],
      ),
    );
  }

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
