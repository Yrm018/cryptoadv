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
import '../services/socket_service.dart';

/// ChatService — chat local avec hive + intégration WebSocket/Network
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  final _db          = DatabaseService.instance;
  final _authService = AuthService();
  final _socket      = SocketService.instance;

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

    final receiverData = getUserByEmail(receiverEmail.trim().toLowerCase());
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

      final receiverPubJson = receiverData['rsaPublicKey'] as String?;
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

    // 2. Envoi via WebSocket
    if (_socket.isConnected) {
      _socket.sendChatMessage(
        receiverId:     receiverId,
        conversationId: conversationId,
        cipherText:     cipherText,
        mode:           mode,
        algorithm:      mode == 'asymmetric' ? 'rsa+aes-gcm' : algorithm,
        type:           type,
        fileName:       fileName,
        fileSize:       fileSize,
        encryptedAesKey: encryptedAesKey,
        iv:             iv,
        signature:      signature,
      );
    }

    String preview = type == 'text' ? (mode == 'asymmetric' ? 'Chiffré RSA' : 'Chiffré') : 'Fichier chiffré ($fileName)';
    _updateConvPreview(conversationId, now, preview);
    _pushMessageUpdate(conversationId);
    _pushConversationUpdate();
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

  bool receiverHasRsaKeys(String emailOrUsername) {
    final data = getUserByEmail(emailOrUsername);
    return data?['rsaPublicKey'] != null;
  }
}
