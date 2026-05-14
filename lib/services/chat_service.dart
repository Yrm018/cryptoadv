import 'dart:async';
import 'dart:convert';
import '../core/database/database_service.dart';
import '../models/chat_message_model.dart';
import '../services/auth_service.dart';
import '../backend/crypto/cryptavance.dart';

/// ChatService — chat local avec hive.
///
/// Note : en mode local, le chat fonctionne entre comptes sur le même appareil.
/// Pour un vrai chat entre appareils différents, il faudra un backend API (étape EC2).
class ChatService {
  final _db = DatabaseService.instance;
  final _authService = AuthService();

  // ── Stream simulé pour les messages ──────────────────────────────────────
  final Map<String, StreamController<List<ChatMessageModel>>> _msgControllers = {};
  final StreamController<List<Map<String, dynamic>>> _convController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _buildConversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _generateId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    return '${t}_${(t * 9301 + 49297) % 233280}';
  }

  String _algoLabel(String algorithm) =>
      algorithm == 'chacha20' ? 'ChaCha20-Poly1305' : 'AES-GCM';

  // ── Chercher un user par email (dans hive) ────────────────────────────────
  Map<String, dynamic>? getUserByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final found = _db.users.values.firstWhere(
      (u) => u['email'] == normalized,
      orElse: () => {},
    );
    return found.isEmpty ? null : Map<String, dynamic>.from(found);
  }

  // ── Créer ou récupérer une conversation ───────────────────────────────────
  Future<String> getOrCreateConversation(
    String otherUserId,
    String otherUserEmail,
  ) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) throw Exception("Utilisateur non connecté");

    final conversationId = _buildConversationId(currentUser.id, otherUserId);

    // Vérifier si la conversation existe déjà
    if (_db.conversations.containsKey(conversationId)) {
      return conversationId;
    }

    // Récupérer les infos du destinataire
    final otherUserData = _db.users.get(otherUserId);
    final receiverEmail = otherUserData?['email'] ?? otherUserEmail;
    final receiverName = otherUserData?['displayName'] ?? otherUserEmail;

    await _db.conversations.put(conversationId, {
      'id': conversationId,
      'participants': jsonEncode([currentUser.id, otherUserId]),
      'participantEmails': jsonEncode([currentUser.email, receiverEmail]),
      'participantNames': jsonEncode([currentUser.displayName, receiverName]),
      'lastMessageAt': DateTime.now().toIso8601String(),
      'lastMessagePreview': 'Conversation sécurisée',
    });

    return conversationId;
  }

  // ── Conversations récentes (Stream) ───────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getRecentConversations() {
    _pushConversationUpdate();
    return _convController.stream;
  }

  void _pushConversationUpdate() async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) {
      _convController.add([]);
      return;
    }

    final convs = _db.conversations.values
        .where((c) {
          final ids = List<String>.from(jsonDecode(c['participants'] ?? '[]'));
          return ids.contains(currentUser.id);
        })
        .map((c) {
          final emails = List<String>.from(
              jsonDecode(c['participantEmails'] ?? '[]'));
          final ids = List<String>.from(jsonDecode(c['participants'] ?? '[]'));
          final otherIdx = ids.indexWhere((id) => id != currentUser.id);
          final email = emails.length > otherIdx && otherIdx >= 0
              ? emails[otherIdx]
              : 'Utilisateur';
          return {
            'conversationId': c['id'],
            'email': email,
            'name': email,
            'lastMessage': c['lastMessagePreview'] ?? 'Conversation sécurisée',
            'updatedAt': c['lastMessageAt'],
          };
        })
        .toList()
      ..sort((a, b) => (b['updatedAt'] as String)
          .compareTo(a['updatedAt'] as String));

    if (!_convController.isClosed) _convController.add(convs);
  }

  // ── Messages d'une conversation (Stream) ──────────────────────────────────
  Stream<List<ChatMessageModel>> getMessages(String conversationId) {
    if (!_msgControllers.containsKey(conversationId)) {
      _msgControllers[conversationId] =
          StreamController<List<ChatMessageModel>>.broadcast();
    }
    _pushMessageUpdate(conversationId);
    return _msgControllers[conversationId]!.stream;
  }

  void _pushMessageUpdate(String conversationId) async {
    final box = await _db.messagesBox(conversationId);
    final msgs = box.values
        .map((m) => ChatMessageModel.fromMap(
            m['id'] ?? '', Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

    final ctrl = _msgControllers[conversationId];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(msgs);
  }

  // ── Envoyer un message ────────────────────────────────────────────────────
  Future<void> sendMessageToEmail({
    required String receiverEmail,
    required String text,
    required String encryptionKey,
    required String algorithm,
  }) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) throw Exception("Utilisateur non connecté");

    final normalized = receiverEmail.trim().toLowerCase();
    final receiverData = getUserByEmail(normalized);
    if (receiverData == null) {
      throw Exception("Aucun utilisateur trouvé avec cet email");
    }

    final receiverId = receiverData['id'] as String;
    if (receiverId == currentUser.id) {
      throw Exception("Tu ne peux pas t'envoyer un message à toi-même");
    }

    final receiverName = receiverData['displayName'] ?? normalized;
    final conversationId =
        await getOrCreateConversation(receiverId, normalized);

    final payload = await CryptoAvance.encryptMessage(
      message: text,
      key: encryptionKey,
      algorithm: algorithm,
    );

    final msgId = _generateId();
    final now = DateTime.now().toIso8601String();
    final box = await _db.messagesBox(conversationId);

    await box.put(msgId, {
      'id': msgId,
      'conversationId': conversationId,
      'senderId': currentUser.id,
      'senderEmail': currentUser.email,
      'senderName': currentUser.displayName,
      'receiverId': receiverId,
      'receiverEmail': normalized,
      'receiverName': receiverName,
      'cipherText': payload.cipherText,
      'nonce': payload.nonce,
      'mac': payload.mac,
      'algorithm': payload.algorithm,
      'createdAt': now,
    });

    // Mettre à jour la conversation
    final conv = Map<String, dynamic>.from(
        _db.conversations.get(conversationId) ?? {});
    conv['lastMessageAt'] = now;
    conv['lastMessagePreview'] =
        'Message chiffré (${_algoLabel(payload.algorithm)})';
    await _db.conversations.put(conversationId, conv);

    _pushMessageUpdate(conversationId);
    _pushConversationUpdate();
  }

  // ── Déchiffrer un message ─────────────────────────────────────────────────
  Future<String> decryptMessage(ChatMessageModel message, String key) async {
    if (key.trim().isEmpty) throw Exception("Clé vide");
    try {
      return await CryptoAvance.decryptMessage(
        cipherText: message.cipherText,
        nonce: message.nonce,
        mac: message.mac,
        key: key.trim(),
        algorithm: message.algorithm.isEmpty ? 'aes-gcm' : message.algorithm,
      );
    } catch (_) {
      throw Exception("Impossible de déchiffrer le message");
    }
  }
}
