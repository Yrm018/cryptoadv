import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_service.dart';
import '../models/chat_message_model.dart';
import '../services/auth_service.dart';
import '../backend/crypto/cryptavance.dart';
import '../backend/security/rsa_service.dart';
import '../services/socket_service.dart';
import '../services/network_service.dart';

/// ChatService — chat local avec hive + intégration WebSocket/Network
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  final _db          = DatabaseService.instance;
  final _authService = AuthService();
  final _socket      = SocketService.instance;
  final _network     = NetworkService.instance;

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

  String _generateAesKey() {
    final bytes = List.generate(32, (_) => Random.secure().nextInt(256));
    return base64Encode(Uint8List.fromList(bytes));
  }

  // ── Utilisateurs ──────────────────────────────────────────────────────────

  /// Cherche un utilisateur par email ou username (Local + Remote)
  Future<Map<String, dynamic>?> getUserByEmail(String emailOrUsername) async {
    final normalized = emailOrUsername.trim().toLowerCase();
    
    // 1. Chercher d'abord dans la base locale (utilisateurs déjà rencontrés)
    var found = _db.users.values.firstWhere(
      (u) => u['email'] == normalized || (u['username'] as String?)?.toLowerCase() == normalized, 
      orElse: () => {},
    );
    if (found.isNotEmpty) return Map<String, dynamic>.from(found);

    // 2. Si pas trouvé, chercher sur le serveur EC2
    if (_network.isAuthenticated) {
      try {
        final results = await _network.searchUsers(normalized);
        if (results.isNotEmpty) {
          // On cherche une correspondance exacte dans les résultats
          final remote = results.firstWhere(
            (u) => (u['email'] as String).toLowerCase() == normalized || 
                   (u['username'] as String).toLowerCase() == normalized,
            orElse: () => null,
          );
          
          if (remote != null) {
            // Normalisation des champs pour l'UI (mapping snake_case -> camelCase)
            return {
              ...remote,
              'rsaPublicKey': remote['public_key'],
              'photoBase64': remote['photo_base64'],
              'displayName': '${remote['first_name'] ?? ''} ${remote['last_name'] ?? ''}'.trim().isNotEmpty 
                  ? '${remote['first_name']} ${remote['last_name']}'
                  : remote['username'] ?? remote['email'],
            };
          }
        }
      } catch (e) {
        debugPrint("Erreur getUserByEmail distant: $e");
      }
    }
    return null;
  }

  // ── Conversations ─────────────────────────────────────────────────────────

  Future<String> getOrCreateConversation(String otherUserId, String otherUserEmail) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) throw Exception('Utilisateur non connecté');

    final conversationId = _buildConversationId(currentUser.id, otherUserId);

    if (_db.conversations.containsKey(conversationId)) {
      return conversationId;
    }

    // Récupérer les infos de l'autre utilisateur (on attend l'async ici)
    final otherData = await getUserByEmail(otherUserEmail);
    final receiverEmail = otherData?['email'] ?? otherUserEmail;
    final receiverName  = otherData?['displayName'] ?? otherUserEmail;

    final symmetricKey = _generateAesKey();

    await _db.conversations.put(conversationId, {
      'id': conversationId,
      'participants':      jsonEncode([currentUser.id, otherUserId]),
      'participantEmails': jsonEncode([currentUser.email, receiverEmail]),
      'participantNames':  jsonEncode([currentUser.displayName, receiverName]),
      'lastMessageAt':     DateTime.now().toIso8601String(),
      'lastMessagePreview':'Conversation sécurisée',
      'symmetricKey':      symmetricKey,
    });

    return conversationId;
  }

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
          final ids    = List<String>.from(jsonDecode(c['participants']      ?? '[]'));
          final emails = List<String>.from(jsonDecode(c['participantEmails'] ?? '[]'));
          final names  = List<String>.from(jsonDecode(c['participantNames']  ?? '[]'));
          final otherId = ids.firstWhere((id) => id != currentUser.id, orElse: () => '');
          final otherIndex = ids.indexOf(otherId);

          // Email réel du destinataire (indispensable pour sendMessage)
          String otherEmail = otherIndex >= 0 && otherIndex < emails.length
              ? emails[otherIndex]
              : '';

          // Nom d'affichage : priorité Hive → participantNames → username du Hive → email
          String displayName = 'Utilisateur';
          if (otherId.isNotEmpty) {
            final d = _db.users.get(otherId);
            if (d != null) {
              displayName = (d['username'] as String?)?.isNotEmpty == true
                  ? d['username'] as String
                  : (d['email'] as String? ?? 'Utilisateur');
              if (otherEmail.isEmpty) otherEmail = (d['email'] as String?) ?? '';
            } else if (otherIndex >= 0 && otherIndex < names.length && names[otherIndex].isNotEmpty) {
              displayName = names[otherIndex];
            }
          }

          return {
            'conversationId': c['id'],
            'email':          otherEmail.isNotEmpty ? otherEmail : displayName,
            'name':           displayName,
            'lastMessage':    c['lastMessagePreview'] ?? 'Conversation sécurisée',
            'updatedAt':      c['lastMessageAt'],
            'otherUserId':    otherId,
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
    // Marquer les messages reçus comme lus dès l'ouverture de la conversation
    markConversationRead(conversationId);
    return _msgControllers[conversationId]!.stream;
  }

  /// Notifie le serveur que le currentUser a lu les messages de cette conversation.
  /// Le serveur met à jour read_at et envoie un event WS message_read à l'expéditeur.
  Future<void> markConversationRead(String conversationId) async {
    if (!_network.isAuthenticated) return;
    try {
      await _network.markMessagesRead(conversationId);
    } catch (e) {
      debugPrint('[ChatService] markConversationRead: $e');
    }
  }

  /// Appelé par AuthProvider après le login pour brancher le callback WS message_read
  void listenToReadReceipts() {
    _socket.onMessageRead = (data) async {
      final convId  = data['conversationId'] as String?;
      final readAt  = data['readAt'] as String?;
      if (convId == null || readAt == null) return;

      // Mettre à jour en local : tous les messages de la box qui n'ont pas encore readAt
      final box = await _db.messagesBox(convId);
      bool changed = false;
      for (final key in box.keys) {
        final m = Map<String, dynamic>.from(box.get(key) ?? {});
        if (m['readAt'] == null) {
          m['readAt'] = readAt;
          await box.put(key, m);
          changed = true;
        }
      }
      if (changed) _pushMessageUpdate(convId);
    };
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

  Future<void> sendMessage({
    required String receiverEmail,
    required String text,
    required String mode,
    String algorithm = 'aes-gcm',
    String type = 'text',
    String? fileName,
    int? fileSize,
  }) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) throw Exception('Utilisateur non connecté');

    final receiverData = await getUserByEmail(receiverEmail.trim().toLowerCase());
    if (receiverData == null) throw Exception('Utilisateur introuvable');
    final receiverId   = receiverData['id'] as String;

    final conversationId = await getOrCreateConversation(receiverId, receiverEmail);
    final msgId = _generateId();
    final now   = DateTime.now().toIso8601String();

    String cipherText;
    String nonce = '';
    String mac = '';
    String? encryptedAesKey;
    String? iv;
    String? signature;

    if (mode == 'asymmetric') {
      final prefs    = await SharedPreferences.getInstance();
      final privJson = prefs.getString('rsa_priv_${currentUser.id}');
      if (privJson == null) throw Exception('rsa_keys_missing');

      final receiverPubJson = (receiverData['rsaPublicKey'] ?? receiverData['public_key']) as String?;
      if (receiverPubJson == null) throw Exception('rsa_receiver_no_keys');

      final privKey        = RsaService.decodePrivateKey(privJson);
      final receiverPubKey = RsaService.decodePublicKey(receiverPubJson);

      final msgBytes  = Uint8List.fromList(utf8.encode(text));
      final sigBytes  = RsaService.sign(msgBytes, privKey);
      signature       = base64Encode(sigBytes);

      final aesKeyBytes = Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)));
      final aesKeyStr   = base64Encode(aesKeyBytes);
      final payload     = '$text|SIG|$signature';
      final encrypted   = await CryptoAvance.encryptMessage(message: payload, key: aesKeyStr);

      cipherText      = encrypted.cipherText;
      nonce           = encrypted.nonce;
      mac             = encrypted.mac;
      iv              = nonce; 
      encryptedAesKey = base64Encode(RsaService.encryptWithPublicKey(aesKeyBytes, receiverPubKey));
    } else {
      String? key = getConversationKey(conversationId);
      if (key == null) {
        key = _generateAesKey();
        final conv = Map<String, dynamic>.from(_db.conversations.get(conversationId) ?? {});
        conv['symmetricKey'] = key;
        await _db.conversations.put(conversationId, conv);
      }
      final payload = await CryptoAvance.encryptMessage(message: text, key: key, algorithm: algorithm);
      cipherText = payload.cipherText;
      nonce      = payload.nonce;
      mac        = payload.mac;
    }

    // 1. Sauvegarde locale
    final box = await _db.messagesBox(conversationId);
    await box.put(msgId, {
      'id':             msgId,
      'conversationId': conversationId,
      'senderId':       currentUser.id,
      'senderEmail':    currentUser.email,
      'senderName':     currentUser.displayName,
      'receiverId':     receiverId,
      'receiverEmail':  receiverEmail.trim().toLowerCase(),
      'receiverName':   receiverData['displayName'] ?? receiverEmail,
      'encryptionMode': mode,
      'cipherText':     cipherText,
      'nonce':          nonce,
      'mac':            mac,
      'algorithm':      mode == 'asymmetric' ? 'rsa+aes-gcm' : algorithm,
      'encryptedAesKey': encryptedAesKey,
      'signature':      signature,
      'iv':             iv,
      'createdAt':      now,
      'type':           type,
      'fileName':       fileName,
      'fileSize':       fileSize,
      'senderPlainText': text,
    });

    // 2. Persistance sur le serveur EC2 (indispensable pour la livraison hors-ligne)
    //    Le serveur tentera une livraison WebSocket en temps réel si le destinataire
    //    est connecté, sinon le message reste en DB jusqu'à sa prochaine connexion.
    if (_network.isAuthenticated) {
      try {
        await _network.sendMessage(
          id:             msgId,
          conversationId: conversationId,
          receiverId:     receiverId,
          cipherText:     cipherText,
          mode:           mode,
          algorithm:      mode == 'asymmetric' ? 'rsa+aes-gcm' : algorithm,
          type:           type,
          fileName:       fileName,
          fileSize:       fileSize,
          encryptedAesKey: encryptedAesKey,
          // Pour les messages symétriques, iv = nonce (le serveur stocke sous "iv")
          iv:             iv ?? nonce,
          signature:      signature,
        );
      } catch (e) {
        // Échec réseau → le message est déjà en local, on continue sans planter
        debugPrint('[ChatService] Envoi serveur échoué (sera réessayé plus tard): $e');
      }
    }

    String preview = type == 'text' ? (mode == 'asymmetric' ? 'Chiffré RSA' : 'Chiffré') : 'Fichier chiffré ($fileName)';
    _updateConvPreview(conversationId, now, preview);
    _pushMessageUpdate(conversationId);
    _pushConversationUpdate();
  }

  // ── Synchronisation depuis le serveur ────────────────────────────────────

  /// Appelé après le login pour récupérer les conversations et messages
  /// manqués pendant que l'utilisateur était hors ligne.
  Future<void> syncFromServer() async {
    if (!_network.isAuthenticated) return;
    try {
      final conversations = await _network.getConversations();
      for (final conv in conversations) {
        final otherId    = conv['other_id']?.toString() ?? '';
        final otherEmail = conv['other_email']?.toString() ?? '';
        final otherName  = conv['other_username']?.toString() ?? otherEmail;

        if (otherId.isEmpty) continue;

        // Reconstruire la conversationId locale (même logique que _buildConversationId)
        final currentUser = await _authService.currentUser;
        if (currentUser == null) return;
        final convId = _buildConversationId(currentUser.id, otherId);

        // Créer la conversation localement si absente
        if (!_db.conversations.containsKey(convId)) {
          await _db.conversations.put(convId, {
            'id':               convId,
            'participants':      jsonEncode([currentUser.id, otherId]),
            'participantEmails': jsonEncode([currentUser.email, otherEmail]),
            'participantNames':  jsonEncode([currentUser.displayName, otherName]),
            'lastMessageAt':     conv['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            'lastMessagePreview':'Conversation sécurisée',
            'symmetricKey':      '',  // clé AES gérée localement
          });
        }

        // Sauvegarder l'utilisateur distant en local pour l'UI
        if (!_db.users.containsKey(otherId)) {
          await _db.users.put(otherId, {
            'id':          otherId,
            'email':       otherEmail,
            'username':    otherName,
            'displayName': '${conv['first_name'] ?? ''} ${conv['last_name'] ?? ''}'.trim().isNotEmpty
                             ? '${conv['first_name']} ${conv['last_name']}'
                             : otherName,
            'photoBase64': conv['photo_base64'],
          });
        }

        // Récupérer les messages du serveur
        try {
          final msgs = await _network.getMessages(convId);
          final box  = await _db.messagesBox(convId);
          for (final m in msgs) {
            final id = m['id']?.toString() ?? '';
            if (id.isEmpty || box.containsKey(id)) continue;
            // Mapper les champs snake_case du serveur
            await box.put(id, {
              'id':             id,
              'conversationId': convId,
              'senderId':       m['sender_id']?.toString() ?? '',
              'senderEmail':    '',
              'senderName':     '',
              'receiverId':     otherId,
              'receiverEmail':  otherEmail,
              'receiverName':   otherName,
              'encryptionMode': m['mode'] ?? 'symmetric',
              'cipherText':     m['cipher_text'] ?? '',
              'nonce':          m['iv'] ?? '',
              'mac':            '',
              'algorithm':      m['algorithm'] ?? 'aes-gcm',
              'encryptedAesKey': m['encrypted_aes_key'],
              'signature':      m['signature'],
              'iv':             m['iv'],
              'createdAt':      m['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
              'type':           m['type'] ?? 'text',
              'fileName':       m['file_name'],
              'fileSize':       m['file_size'],
              'senderPlainText': '',
            });
          }
          if (msgs.isNotEmpty) _pushMessageUpdate(convId);
        } catch (e) {
          debugPrint('[ChatService] syncMessages $convId: $e');
        }
      }
      _pushConversationUpdate();
    } catch (e) {
      debugPrint('[ChatService] syncFromServer: $e');
    }
  }

  /// Sauvegarde un message reçu depuis le WebSocket/Network dans Hive
  Future<void> saveReceivedMessage(Map<String, dynamic> data) async {
    final conversationId = data['conversationId'] as String?;
    if (conversationId == null) return;

    final msgId = data['id'] ?? _generateId();
    final box = await _db.messagesBox(conversationId);
    
    await box.put(msgId, data);
    
    _updateConvPreview(conversationId, data['createdAt'] ?? DateTime.now().toIso8601String(), 'Nouveau message');
    _pushMessageUpdate(conversationId);
    _pushConversationUpdate();
  }

  void _updateConvPreview(String convId, String now, String preview) async {
    final conv = Map<String, dynamic>.from(_db.conversations.get(convId) ?? {
      'id': convId,
      'participants': '[]',
      'participantEmails': '[]',
      'participantNames': '[]',
    });
    conv['lastMessageAt']      = now;
    conv['lastMessagePreview'] = preview;
    await _db.conversations.put(convId, conv);
  }

  // ── Déchiffrement ─────────────────────────────────────────────────────────

  Future<String> decryptMessage(ChatMessageModel msg) async {
    if (msg.encryptionMode == 'asymmetric') {
      return _decryptAsymmetric(msg);
    }

    // Pour les messages envoyés par soi-même : retourner le texte en clair directement
    final currentUser = await _authService.currentUser;
    if (currentUser != null && msg.senderId == currentUser.id) {
      return msg.senderPlainText.isNotEmpty ? msg.senderPlainText : '🔐 Message envoyé';
    }

    final key = getConversationKey(msg.conversationId) ?? '';
    if (key.isEmpty) return '🔒 Message chiffré';
    try {
      return await CryptoAvance.decryptMessage(
        cipherText: msg.cipherText, nonce: msg.nonce, mac: msg.mac,
        key: key, algorithm: msg.algorithm.isEmpty ? 'aes-gcm' : msg.algorithm,
      );
    } catch (_) {
      return '🔒 Message chiffré';
    }
  }

  Future<String> _decryptAsymmetric(ChatMessageModel msg) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) return '🔒';

    if (msg.senderId == currentUser.id) {
      return msg.senderPlainText.isNotEmpty ? msg.senderPlainText : '🔐 Message envoyé';
    }

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
      const sep   = '|SIG|';
      final sepIdx = payload.lastIndexOf(sep);
      return sepIdx >= 0 ? payload.substring(0, sepIdx) : payload;
    } catch (_) {
      return '🔒 Déchiffrement RSA impossible';
    }
  }

  String? getUserPhoto(String userId) {
    return _db.users.get(userId)?['photoBase64'] as String?;
  }

  Future<bool> currentUserHasRsaKeys() async {
    final user = await _authService.currentUser;
    if (user == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('rsa_priv_${user.id}');
  }

  /// Vérifie si le destinataire a des clés RSA (Local + Remote)
  Future<bool> receiverHasRsaKeys(String emailOrUsername) async {
    final data = await getUserByEmail(emailOrUsername);
    return data?['rsaPublicKey'] != null || data?['public_key'] != null;
  }
}
