import 'dart:convert';
import 'package:flutter/material.dart';
import '../../components/backround.dart';
import '../../models/chat_message_model.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../widgets/common/app_navbar.dart';
import '../../widgets/common/user_avatar.dart';

class GroupsDesktop extends StatefulWidget {
  const GroupsDesktop({super.key});

  @override
  State<GroupsDesktop> createState() => _GroupsDesktopState();
}

class _GroupsDesktopState extends State<GroupsDesktop> {
  final _groupService   = GroupService.instance;
  final _scrollCtrl     = ScrollController();
  final _msgCtrl        = TextEditingController();

  String?   _activeGroupId;
  String?   _activeGroupName;
  LocalUser? _currentUser;
  bool      _sending = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _groupService.listenToGroupEvents();
    _groupService.loadGroups();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().currentUser;
    if (mounted) setState(() => _currentUser = user);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Création d'un groupe ──────────────────────────────────────────────────

  void _showCreateGroupDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final List<Map<String, String>> members = []; // {id, email}
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(children: [
            Icon(Icons.group_add_rounded, color: Colors.blue, size: 22),
            SizedBox(width: 10),
            Text('Nouveau groupe', style: TextStyle(color: Colors.white, fontSize: 17)),
          ]),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dlgField(nameCtrl, 'Nom du groupe *', Icons.group_rounded),
              const SizedBox(height: 12),
              _dlgField(descCtrl, 'Description (optionnel)', Icons.notes_rounded),
              const SizedBox(height: 18),
              // Ajouter des membres
              Row(children: [
                Expanded(child: _dlgField(emailCtrl, 'Email/username du membre', Icons.person_add_rounded)),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final email = emailCtrl.text.trim();
                    if (email.isEmpty) return;
                    // Chercher l'utilisateur
                    try {
                      final results = await _groupService.searchUsers(email);
                      if (results.isEmpty) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Utilisateur introuvable')));
                        }
                        return;
                      }
                      final user = results.first;
                      final uid = user['id'].toString();
                      if (members.any((m) => m['id'] == uid)) return;
                      setDlg(() => members.add({'id': uid, 'email': user['email'] ?? email}));
                      emailCtrl.clear();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Erreur : $e')));
                      }
                    }
                  },
                  child: const Icon(Icons.add_rounded),
                ),
              ]),
              if (members.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: members.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_rounded, color: Colors.white54, size: 18),
                      title: Text(members[i]['email']!,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                        onPressed: () => setDlg(() => members.removeAt(i)),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: loading ? null : () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                setDlg(() => loading = true);
                try {
                  final group = await _groupService.createGroup(
                    name:        name,
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    memberIds:   members.map((m) => m['id']!).toList(),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    setState(() {
                      _activeGroupId   = group.id;
                      _activeGroupName = group.name;
                    });
                  }
                } catch (e) {
                  setDlg(() => loading = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent));
                  }
                }
              },
              child: loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Membres d'un groupe ───────────────────────────────────────────────────

  void _showMembersDialog(String groupId) async {
    final members = await _groupService.getMembers(groupId);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.group_rounded, color: Colors.blue, size: 20),
          SizedBox(width: 10),
          Text('Membres', style: TextStyle(color: Colors.white, fontSize: 17)),
        ]),
        content: SizedBox(
          width: 340,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (_, i) {
              final m = members[i];
              final isAdmin = m.role == 'admin';
              return ListTile(
                leading: UserAvatar(
                  photoBase64: m.photoBase64,
                  initial: m.displayName,
                  radius: 18,
                  backgroundColor: isAdmin ? Colors.blue : Colors.grey,
                ),
                title: Text(m.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: Text(m.email,
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                trailing: isAdmin
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.4)),
                        ),
                        child: const Text('Admin',
                            style: TextStyle(color: Colors.blue, fontSize: 10)),
                      )
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ── Envoi d'un message ────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _activeGroupId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _groupService.sendMessage(groupId: _activeGroupId!, text: text);
      _msgCtrl.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(children: [
        const CryptoBackground(),
        SafeArea(
          child: Column(children: [
            const AppNavbar(currentPage: 'groups'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(children: [
                  SizedBox(width: 290, child: _buildSidebar(isDark)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildChatPanel(isDark)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────

  Widget _buildSidebar(bool isDark) => _glass(
    isDark: isDark,
    child: Column(children: [
      Row(children: [
        Icon(Icons.group_rounded,
            color: isDark ? const Color(0xFF7AA6FF) : const Color(0xFF2563EB), size: 18),
        const SizedBox(width: 10),
        const Text('Groupes',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
          onPressed: _showCreateGroupDialog,
          icon: const Icon(Icons.add_rounded, color: Colors.blue, size: 22),
          tooltip: 'Nouveau groupe',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: StreamBuilder<List<GroupModel>>(
          stream: _groupService.groupsStream,
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final groups = snap.data!;
            if (groups.isEmpty) {
              return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.group_off_rounded, color: Colors.white24, size: 40),
                const SizedBox(height: 10),
                const Text('Aucun groupe',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateGroupDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Créer un groupe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]);
            }
            return ListView.builder(
              itemCount: groups.length,
              itemBuilder: (_, i) => _groupTile(groups[i], isDark),
            );
          },
        ),
      ),
    ]),
  );

  Widget _groupTile(GroupModel g, bool isDark) {
    final active = _activeGroupId == g.id;
    return ListTile(
      selected: active,
      selectedTileColor: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: active ? Colors.blue : Colors.blueGrey.withOpacity(0.4),
        backgroundImage: g.photoBase64 != null
            ? MemoryImage(base64Decode(g.photoBase64!))
            : null,
        child: g.photoBase64 == null
            ? Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : 'G',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            : null,
      ),
      title: Text(g.name,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${g.memberCount} membre${g.memberCount > 1 ? 's' : ''}',
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: g.role == 'admin'
          ? const Icon(Icons.shield_rounded, color: Colors.blue, size: 14)
          : null,
      onTap: () => setState(() {
        _activeGroupId   = g.id;
        _activeGroupName = g.name;
      }),
    );
  }

  // ── Chat panel ────────────────────────────────────────────────────────────

  Widget _buildChatPanel(bool isDark) => _glass(
    isDark: isDark,
    padding: EdgeInsets.zero,
    child: Column(children: [
      _chatHeader(isDark),
      Expanded(child: _buildMessages(isDark)),
      _buildInput(isDark),
    ]),
  );

  Widget _chatHeader(bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.white10)),
    ),
    child: Row(children: [
      const Icon(Icons.lock_rounded, color: Colors.greenAccent, size: 14),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          _activeGroupId != null ? _activeGroupName ?? 'Groupe' : 'Chat de groupe chiffré',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      if (_activeGroupId != null) ...[
        const Chip(
          label: Text('AES-GCM', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
          backgroundColor: Colors.transparent,
          side: BorderSide(color: Colors.greenAccent, width: 0.5),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _showMembersDialog(_activeGroupId!),
          icon: const Icon(Icons.people_rounded, color: Colors.white54, size: 20),
          tooltip: 'Voir les membres',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ]),
  );

  Widget _buildMessages(bool isDark) {
    if (_activeGroupId == null) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.group_rounded, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text('Sélectionne un groupe', style: TextStyle(color: Colors.white38)),
        ]),
      );
    }
    return StreamBuilder<List<ChatMessageModel>>(
      stream: _groupService.getMessages(_activeGroupId!),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final msgs = snap.data!;
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          itemCount: msgs.length,
          itemBuilder: (_, i) => _msgBubble(msgs[i]),
        );
      },
    );
  }

  void _showDeleteMenu(ChatMessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              title: const Text('Supprimer pour tout le monde',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _groupService.deleteGroupMessageForEveryone(
                      _activeGroupId!, msg.id);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e'),
                        backgroundColor: Colors.redAccent));
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.orange),
            title: const Text('Supprimer pour moi',
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              await _groupService.deleteGroupMessageForMe(_activeGroupId!, msg.id);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _msgBubble(ChatMessageModel msg) {
    final isMe = msg.senderId == _currentUser?.id;
    final senderName = msg.senderName.isNotEmpty ? msg.senderName : msg.senderEmail;

    return GestureDetector(
      onLongPress: () => _showDeleteMenu(msg, isMe),
      child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(
              initial: senderName,
              radius: 14,
              backgroundColor: Colors.blueGrey,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(senderName,
                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ),
                // Badge AES-GCM
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.lock_rounded, size: 9, color: Colors.greenAccent),
                        SizedBox(width: 3),
                        Text('AES-GCM',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 8,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  constraints: const BoxConstraints(maxWidth: 480),
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
                    future: _groupService.decryptMessage(msg),
                    builder: (_, snap) {
                      if (!snap.hasData) {
                        return const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54));
                      }
                      final text = snap.data!;
                      if (msg.type == 'image' && !text.startsWith('🔒') && !text.startsWith('🔐')) {
                        return _imageBubble(text, msg);
                      }
                      return Text(text, style: const TextStyle(color: Colors.white, fontSize: 14));
                    },
                  ),
                ),
                if (msg.createdAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${msg.createdAt!.hour.toString().padLeft(2, '0')}:'
                    '${msg.createdAt!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            UserAvatar(
              initial: _currentUser?.username ?? '?',
              radius: 14,
              backgroundColor: Colors.blue,
            ),
          ],
        ],
        ),
      ),
    );
  }

  Widget _imageBubble(String base64Data, ChatMessageModel msg) {
    try {
      final bytes = base64Decode(base64Data);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, width: 200, height: 150, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, color: Colors.white38, size: 32)),
      );
    } catch (_) {
      return const Icon(Icons.broken_image, color: Colors.white38, size: 32);
    }
  }

  Widget _buildInput(bool isDark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white10)),
    ),
    child: Row(children: [
      Expanded(
        child: TextField(
          controller: _msgCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: _activeGroupId != null ? 'Message chiffré...' : 'Sélectionne un groupe',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          enabled: _activeGroupId != null,
          onSubmitted: (_) => _sendMessage(),
          maxLines: null,
          textInputAction: TextInputAction.send,
        ),
      ),
      const SizedBox(width: 10),
      IconButton(
        onPressed: _activeGroupId != null ? _sendMessage : null,
        icon: _sending
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue))
            : const Icon(Icons.send_rounded, color: Colors.blue),
      ),
    ]),
  );

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _glass({required Widget child, EdgeInsets? padding, required bool isDark}) =>
      Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF0D1B3E).withOpacity(0.6),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      );

  Widget _dlgField(TextEditingController ctrl, String hint, IconData icon) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.white38, size: 18),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      );
}
