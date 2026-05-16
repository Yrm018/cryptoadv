import 'dart:convert';
import 'package:flutter/material.dart';
import '../../components/backround.dart';
import '../../models/chat_message_model.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/user_avatar.dart';

class GroupsMobile extends StatefulWidget {
  const GroupsMobile({super.key});
  @override
  State<GroupsMobile> createState() => _GroupsMobileState();
}

class _GroupsMobileState extends State<GroupsMobile> {
  final _groupService = GroupService.instance;
  final _scrollCtrl   = ScrollController();
  final _msgCtrl      = TextEditingController();

  String?    _activeGroupId;
  String?    _activeGroupName;
  LocalUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _groupService.listenToGroupEvents();
    _groupService.loadGroups();
    AuthService().currentUser.then((u) {
      if (mounted) setState(() => _currentUser = u);
    });
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
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ─── Création groupe ──────────────────────────────────────────────────────

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) {
          bool loading = false;
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Nouveau groupe', style: TextStyle(color: Colors.white, fontSize: 16)),
            content: TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nom du groupe',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true, fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: loading ? null : () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  setDlg(() => loading = true);
                  try {
                    final group = await _groupService.createGroup(name: name);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      setState(() {
                        _activeGroupId   = group.id;
                        _activeGroupName = group.name;
                      });
                    }
                  } catch (e) {
                    setDlg(() => loading = false);
                  }
                },
                child: const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Envoi ────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _activeGroupId == null) return;
    try {
      await _groupService.sendMessage(groupId: _activeGroupId!, text: text);
      _msgCtrl.clear();
      _scrollToBottom();
    } catch (_) {}
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentPage: 'groups'),
      body: Stack(children: [
        const CryptoBackground(),
        SafeArea(
          child: _activeGroupId == null ? _buildGroupsList() : _buildChat(),
        ),
      ]),
    );
  }

  // ─── Liste des groupes ────────────────────────────────────────────────────

  Widget _buildGroupsList() => Column(children: [
    _header('Groupes', actions: [
      IconButton(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    ]),
    Expanded(
      child: StreamBuilder<List<GroupModel>>(
        stream: _groupService.groupsStream,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final groups = snap.data!;
          if (groups.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.group_off_rounded, color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                const Text('Aucun groupe', style: TextStyle(color: Colors.white38)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Créer un groupe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
              ]),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  backgroundImage: g.photoBase64 != null
                      ? MemoryImage(base64Decode(g.photoBase64!)) : null,
                  child: g.photoBase64 == null
                      ? Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : 'G',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      : null,
                ),
                title: Text(g.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${g.memberCount} membre${g.memberCount > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                trailing: g.role == 'admin'
                    ? const Icon(Icons.shield_rounded, color: Colors.blue, size: 14) : null,
                onTap: () => setState(() {
                  _activeGroupId   = g.id;
                  _activeGroupName = g.name;
                }),
              );
            },
          );
        },
      ),
    ),
  ]);

  // ─── Chat de groupe ───────────────────────────────────────────────────────

  Widget _buildChat() => Column(children: [
    _header(_activeGroupName ?? 'Groupe', leading: IconButton(
      onPressed: () => setState(() { _activeGroupId = null; _activeGroupName = null; }),
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
    )),
    Expanded(
      child: StreamBuilder<List<ChatMessageModel>>(
        stream: _groupService.getMessages(_activeGroupId!),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final msgs = snap.data!;
          _scrollToBottom();
          return ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(12),
            itemCount: msgs.length,
            itemBuilder: (_, i) => _msgBubble(msgs[i]),
          );
        },
      ),
    ),
    _buildInput(),
  ]);

  Widget _msgBubble(ChatMessageModel msg) {
    final isMe = msg.senderId == _currentUser?.id;
    final name = msg.senderName.isNotEmpty ? msg.senderName : msg.senderEmail;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(initial: name, radius: 14, backgroundColor: Colors.blueGrey),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(name, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue : Colors.white12,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMe ? 14 : 2),
                      bottomRight: Radius.circular(isMe ? 2 : 14),
                    ),
                  ),
                  child: FutureBuilder<String>(
                    future: _groupService.decryptMessage(msg),
                    builder: (_, snap) => Text(
                      snap.data ?? '...',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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

  Widget _buildInput() => Container(
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
    child: Row(children: [
      Expanded(
        child: TextField(
          controller: _msgCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Message chiffré...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true, fillColor: Colors.white10,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          ),
          onSubmitted: (_) => _sendMessage(),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: _sendMessage,
        icon: const Icon(Icons.send_rounded, color: Colors.blue),
      ),
    ]),
  );

  // ─── Header générique ─────────────────────────────────────────────────────

  Widget _header(String title, {List<Widget>? actions, Widget? leading}) => Container(
    color: const Color(0xFF0D1B3E).withOpacity(0.8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: Row(children: [
      leading ?? Builder(builder: (ctx) => IconButton(
        onPressed: () => Scaffold.of(ctx).openDrawer(),
        icon: const Icon(Icons.menu_rounded, color: Colors.white),
      )),
      Expanded(child: Text(title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
      ...?actions,
    ]),
  );
}
