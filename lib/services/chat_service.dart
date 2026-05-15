import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_service.dart';
import '../models/chat_message_model.dart';
import '../services/auth_service.dart';
import '../backend/crypto/cryptavance.dart';
import '../backend/security/rsa_service.dart';

/// ChatService — chat local avec hive.
///
/// Deux modes de chiffrement disponibles :
///   • symmetric  — clé AES auto-générée par conversation (stockée dans hive)
///   • asymmetric — RSA-2048 + AES-GCM (signature incluse), nécessite les clés VPN
class ChatService {
  final _db          = DatabaseService.instance;
  final _authService = AuthService();

  final Map<String, StreamController<List<ChatMessageModel>>> _msgControllers = {};
  final _convController = StreamController<List<Map<String, dynamic>>>.broadcast();

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _buildConversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _generateId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    return '${t}_${(t * 9301 + 49297) % 233280}';
  }

  /// Génère une clé AES-256 aléatoire encodée en base64.
  String _generateAesKey() {
    final bytes = List.generate(32, (_) => Random.secure().nextInt(256));
    return base64Encode(Uint8List.fromList(bytes));
  }

  // ── Utilisateurs ──────────────────────────────────────────────────────────

  Map<String, dynamic>? getUserByEmail(String emailOrUsername) {
    final normalized = emailOrUsername.trim().toLowerCase();
    var found = _db.users.values.firstWhere(
      (u) => u['email'] == normalized, orElse: () => {},
    );
    if (found.isEmpty) {
      found = _db.users.values.firstWhere(
        (u) => (u['username'] as String?)?.toLowerCase() == normalized, orElse: () => {},
      );
    }
    return found.isEmpty ? null : Map<String, dynamic>.from(found);
  }

  // ── Conversations ─────────────────────────────────────────────────────────

  /// Crée ou récupère une conversation. Génère automatiquement une clé symétrique
  /// si la conversation est nouvelle.
  Future<String> getOrCreateConversation(String otherUserId, String otherUserEmail) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) throw Exception('Utilisateur non connecté');

    final conversationId = _buildConversationId(currentUser.id, otherUserId);

    if (_db.conversations.containsKey(conversationId)) {
      return conversationId;
    }

    final otherData     = _db.users.get(otherUserId);
    final receiverEmail = otherData?['email'] ?? otherUserEmail;
    final receiverName  = otherData?['displayName'] ?? otherUserEmail;

    // Clé symétrique auto-générée pour cette conversation
    final symmetricKey = _generateAesKey();

    await _db.conversations.put(conversationId, {
      'id': conversationId,
      'participants':      jsonEncode([currentUser.id, otherUserId]),
      'participantEmails': jsonEncode([currentUser.email, receiverEmail]),
      'participantNames':  jsonEncode([currentUser.displayName, receiverName]),
      'lastMessageAt':     DateTime.now().toIso8601String(),
      'lastMessagePreview':'Conversation sécurisée',
      'symmetricKey':      symmetricKey,   // ← clé auto
    });

    return conversationId;
  }

  /// Retourne la clé symétrique stockée pour une conversation.
  String? getConversationKey(String conversationId) {
    final conv = _db.conversations.get(conversationId);
    return conv?['symmetricKey'] as String?;
  }

  // ── Conversations récentes ────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getRecentConversations() {
    _pushConversationUpdate();
    return _convController.stream;
  }

  void _pushConversationUpdate() async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) { _convController.add([]); return; }

    final convs = _db.conversations.values
        .where((c) {
          final ids = List<String>.from(jsonDecode(c['participants'] ?? '[]'));
          return ids.contains(currentUser.id);
        })
        .map((c) {
          final ids = List<String>.from(jsonDecode(c['participants'] ?? '[]'));
          final otherId = ids.firstWhere((id) => id != currentUser.id, orElse: () => '');
          String displayName = 'Utilisateur';
          if (otherId.isNotEmpty) {
            final d = _db.users.get(otherId);
            if (d != null) displayName = (d['username'] as String?) ?? (d['email'] as String? ?? 'Utilisateur');
          }
          return {
            'conversationId': c['id'],
            'email':          displayName,
            'name':           displayName,
            'lastMessage':    c['lastMessagePreview'] ?? 'Conversation sécurisée',
            'updatedAt':      c['lastMessageAt'],
          };
        })
        .toList()
      ..sort((a, b) => (b['updatedAt'] as String).compareTo(a['updatedAt'] as String));

    if (!_convController.isClosed) _convController.add(convs);
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Stream<List<ChatMessageModel>> getMessages(String conversationId) {
    _msgControllers[conversationId] ??=
        StreamController<List<ChatMessageModel>>.broadcast();
    _pushMessageUpdate(conversationId);
    return _msgControllers[conversationId]!.stream;
  }

  void _pushMessageUpdate(String conversationId) async {
    final box  = await _db.messagesBox(conversationId);
    final msgs = box.values
        .map((m) => ChatMessageModel.fromMap(m['id'] ?? '', Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

    final ctrl = _msgControllers[conversationId];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(msgs);
  }

  // ── Envoi ─────────────────────────────────────────────────────────────────

  /// Envoie un message dans le mode choisi.
  /// [mode] = 'symmetric' ou 'asymmetric'
  /// [algorithm] = 'aes-gcm' ou 'chacha20' (seulement pour le mode symétrique)
  Future<void> sendMessage({
    required String receiverEmail,
    required String text,
    required String mode,
    String algorithm = 'aes-gcm',
  }) async {
    if (mode == 'asymmetric') {
      await _sendAsymmetric(receiverEmail: receiverEmail, text: text);
    } else {
      await _sendSymmetric(receiverEmail: receiverEmail, text: text, algorithm: algorithm);
    }
  }

  Future<void> _sendSymmetric({
    required String receiverEmail,
    required String text,
    required String algorithm,
  }) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) throw Exception('Utilisateur non connecté');

    final receiverData = getUserByEmail(receiverEmail.trim().toLowerCase());
    if (receiverData == null) throw Exception('Utilisateur introuvable');

    final receiverId   = receiverData['id'] as String;
    if (receiverId == currentUser.id) throw Exception('Tu ne peux pas t\'envoyer un message à toi-même');

    final conversationId = await getOrCreateConversation(receiverId, receiverEmail);

    // Si la conversation n'a pas encore de clé symétrique (ex: ancienne conversation),
    // on en génère une et on la persiste AVANT de chiffrer.
    String? key = getConversationKey(conversationId);
    if (key == null) {
      key = _generateAesKey();
      final conv = Map<String, dynamic>.from(_db.conversations.get(conversationId) ?? {});
      conv['symmetricKey'] = key;
      await _db.conversations.put(conversationId, conv);
    }

    final payload = await CryptoAvance.encryptMessage(
      message: text, key: key, algorithm: algorithm,
    );

    final msgId = _generateId();
    final now   = DateTime.now().toIso8601String();
    final box   = await _db.messagesBox(conversationId);

    await box.put(msgId, {
      'id':             msgId,
      'conversationId': conversationId,
      'senderId':       currentUser.id,
      'senderEmail':    currentUser.email,
      'senderName':     currentUser.displayName,
      'receiverId':     receiverId,
      'receiverEmail':  receiverEmail.trim().toLowerCase(),
      'receiverName':   receiverData['displayName'] ?? receiverEmail,
      'encryptionMode': 'symmetric',
      'cipherText':     payload.cipherText,
      'nonce':          payload.nonce,
      'mac':            payload.mac,
      'algorithm':      payload.algorithm,
      'createdAt':      now,
    });

    _updateConvPreview(conversationId, now, 'Message chiffré (${payload.algorithm.toUpperCase()})');
    _pushMessageUpdate(conversationId);
    _pushConversationUpdate();
  }

  Future<void> _sendAsymmetric({
    required String receiverEmail,
    required String text,
  }) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) throw Exception('Utilisateur non connecté');

    // Vérifier que l'expéditeur a des clés RSA
    final prefs    = await SharedPreferences.getInstance();
    final privJson = prefs.getString('rsa_priv_${currentUser.id}');
    if (privJson == null) throw Exception('rsa_keys_missing');

    // Trouver le destinataire
    final receiverData = getUserByEmail(receiverEmail.trim().toLowerCase());
    if (receiverData == null) throw Exception('Utilisateur introuvable');
    final receiverId   = receiverData['id'] as String;
    if (receiverId == currentUser.id) throw Exception('Tu ne peux pas t\'envoyer un message à toi-même');

    // Vérifier que le destinataire a des clés RSA
    final receiverPubJson = receiverData['rsaPublicKey'] as String?;
    if (receiverPubJson == null) throw Exception('rsa_receiver_no_keys');

    // Chiffrement RSA+AES
    final privKey        = RsaService.decodePrivateKey(privJson);
    final receiverPubKey = RsaService.decodePublicKey(receiverPubJson);

    // Signature du message
    final msgBytes  = Uint8List.fromList(utf8.encode(text));
    final signature = RsaService.sign(msgBytes, privKey);
    final sigB64    = base64Encode(signature);

    // Chiffrement AES-GCM du payload texte+signature
    final aesKeyBytes = Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)));
    final aesKeyStr   = base64Encode(aesKeyBytes);
    final payload     = '$text|SIG|$sigB64';
    final encrypted   = await CryptoAvance.encryptMessage(message: payload, key: aesKeyStr);

    // Chiffrement de la clé AES avec RSA
    final encAesKey = RsaService.encryptWithPublicKey(aesKeyBytes, receiverPubKey);

    final conversationId = await getOrCreateConversation(receiverId, receiverEmail);
    final msgId          = _generateId();
    final now            = DateTime.now().toIso8601String();
    final box            = await _db.messagesBox(conversationId);

    await box.put(msgId, {
      'id':              msgId,
      'conversationId':  conversationId,
      'senderId':        currentUser.id,
      'senderEmail':     currentUser.email,
      'senderName':      currentUser.displayName,
      'receiverId':      receiverId,
      'receiverEmail':   receiverEmail.trim().toLowerCase(),
      'receiverName':    receiverData['displayName'] ?? receiverEmail,
      'encryptionMode':  'asymmetric',
      'encryptedAesKey': base64Encode(encAesKey),
      'cipherText':      encrypted.cipherText,
      'nonce':           encrypted.nonce,
      'mac':             encrypted.mac,
      'algorithm':       'rsa+aes-gcm',
      'senderPlainText': text,   // pour affichage côté expéditeur
      'createdAt':       now,
    });

    _updateConvPreview(conversationId, now, 'Message chiffré (RSA+AES)');
    _pushMessageUpdate(conversationId);
    _pushConversationUpdate();
  }

  void _updateConvPreview(String convId, String now, String preview) async {
    final conv = Map<String, dynamic>.from(_db.conversations.get(convId) ?? {});
    conv['lastMessageAt']      = now;
    conv['lastMessagePreview'] = preview;
    await _db.conversations.put(convId, conv);
  }

  // ── Déchiffrement ─────────────────────────────────────────────────────────

  /// Déchiffre un message automatiquement selon son mode.
  /// Ne requiert plus de clé manuelle.
  Future<String> decryptMessage(ChatMessageModel msg) async {
    if (msg.encryptionMode == 'asymmetric') {
      return _decryptAsymmetric(msg);
    }
    // Mode symétrique : récupère la clé stockée dans la conversation
    final key = getConversationKey(msg.conversationId) ?? '';
    if (key.isEmpty) return '🔒';
    try {
      return await CryptoAvance.decryptMessage(
        cipherText: msg.cipherText, nonce: msg.nonce, mac: msg.mac,
        key: key, algorithm: msg.algorithm.isEmpty ? 'aes-gcm' : msg.algorithm,
      );
    } catch (_) {
      return '🔒 Déchiffrement impossible';
    }
  }

  Future<String> _decryptAsymmetric(ChatMessageModel msg) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) return '🔒';

    // Côté expéditeur : afficher le texte sauvegardé
    if (msg.senderId == currentUser.id) {
      return msg.senderPlainText.isNotEmpty ? msg.senderPlainText : '🔐 Message envoyé';
    }

    // Côté destinataire : déchiffrer avec la clé privée RSA
    final prefs    = await SharedPreferences.getInstance();
    final privJson = prefs.getString('rsa_priv_${currentUser.id}');
    if (privJson == null) return '🔒 Clé RSA manquante';

    try {
      final privKey    = RsaService.decodePrivateKey(privJson);
      final encAesKey  = base64Decode(msg.encryptedAesKey);
      final aesKeyBytes = RsaService.decryptWithPrivateKey(encAesKey, privKey);
      final aesKeyStr  = base64Encode(aesKeyBytes);

      final payload    = await CryptoAvance.decryptMessage(
        cipherText: msg.cipherText, nonce: msg.nonce, mac: msg.mac, key: aesKeyStr,
      );
      // Extraire le texte (format : "texte|SIG|signature")
      const sep   = '|SIG|';
      final sepIdx = payload.lastIndexOf(sep);
      return sepIdx >= 0 ? payload.substring(0, sepIdx) : payload;
    } catch (_) {
      return '🔒 Déchiffrement RSA impossible';
    }
  }

  // ── Photo de profil ───────────────────────────────────────────────────────

  /// Retourne la photo base64 d'un utilisateur (lisible par tous).
  String? getUserPhoto(String userId) {
    return _db.users.get(userId)?['photoBase64'] as String?;
  }

  // ── Vérification des clés RSA ─────────────────────────────────────────────

  Future<bool> currentUserHasRsaKeys() async {
    final user = await _authService.currentUser;
    if (user == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('rsa_priv_${user.id}');
  }

  bool receiverHasRsaKeys(String emailOrUsername) {
    final data = getUserByEmail(emailOrUsername);
    return data?['rsaPublicKey'] != null;
  }
}
