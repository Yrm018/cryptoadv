import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message_model.dart';
import '../services/auth_service.dart';
import '../backend/crypto/cryptavance.dart';
import '../backend/security/rsa_service.dart';
import '../services/socket_service.dart';
import '../services/network_service.dart';

/// ChatService — architecture PostgreSQL-first
///
/// Sources de données :
///   • Messages & conversations → PostgreSQL via REST (NetworkService)
///   • Clés AES symétriques    → SharedPreferences (jamais envoyées au serveur)
///   • Clés RSA                → SharedPreferences (déjà géré par VpnService)
///   • Cache session           → Map<> en mémoire (vidé à chaque rechargement)
///
/// Plus de Hive pour les messages/conversations.
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  final _authService = AuthService();
  final _socket      = SocketService.instance;
  final _network     = NetworkService.instance;

  // ── Cache in-memory (session courante) ────────────────────────────────────
  final Map<String, List<ChatMessageModel>> _messagesCache       = {};
  final List<Map<String, dynamic>>          _conversationsCache  = [];
  final Map<String, String>                 _userPhotoCache      = {}; // userId → base64
  final Map<String, Map<String, dynamic>>   _userDataCache       = {}; // userId → data

  // ── Stream controllers ────────────────────────────────────────────────────
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

  String _buildDisplayName(Map<String, dynamic> u) {
    final fn = (u['first_name'] ?? '').toString();
    final ln = (u['last_name']  ?? '').toString();
    final full = '$fn $ln'.trim();
    return full.isNotEmpty ? full : ((u['username'] ?? u['email'] ?? '').toString());
  }

  // ── Clés AES (SharedPreferences) ─────────────────────────────────────────

  /// Récupère la clé AES symétrique de la conversation (null si absente)
  Future<String?> getConversationKey(String convId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('aes_conv_$convId');
  }

  Future<void> _setConversationKey(String convId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aes_conv_$convId', key);
  }

  // ── Utilisateurs ──────────────────────────────────────────────────────────

  /// Cherche un utilisateur par email ou username — cache in-memory puis serveur
  Future<Map<String, dynamic>?> getUserByEmail(String emailOrUsername) async {
    final normalized = emailOrUsername.trim().toLowerCase();

    // 1. Cache in-memory
    for (final user in _userDataCache.values) {
      if ((user['email']    as String?)?.toLowerCase() == normalized ||
          (user['username'] as String?)?.toLowerCase() == normalized) {
        return user;
      }
    }

    // 2. Serveur
    if (_network.isAuthenticated) {
      try {
        final results = await _network.searchUsers(normalized);
        if (results.isNotEmpty) {
          final remote = results.firstWhere(
            (u) => (u['email']    as String?)?.toLowerCase() == normalized ||
                   (u['username'] as String?)?.toLowerCase() == normalized,
            orElse: () => null,
          );
          if (remote != null) {
            final r = Map<String, dynamic>.from(remote);
            final userData = <String, dynamic>{
              ...r,
              'rsaPublicKey': r['public_key'],
              'photoBase64':  r['photo_base64'],
              'displayName':  _buildDisplayName(r),
            };
            final uid = r['id']?.toString() ?? '';
            if (uid.isNotEmpty) {
              _userDataCache[uid] = userData;
              if (r['photo_base64'] != null) {
                _userPhotoCache[uid] = r['photo_base64'] as String;
              }
            }
            return userData;
          }
        }
      } catch (e) {
        debugPrint('[ChatService] getUserByEmail: $e');
      }
    }
    return null;
  }

  // ── Conversations ─────────────────────────────────────────────────────────

  /// Crée ou retrouve une conversation et s'assure qu'une clé AES existe
  Future<String> getOrCreateConversation(String otherUserId, String otherUserEmail) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) throw Exception('Utilisateur non connecté');

    final convId = _buildConversationId(currentUser.id, otherUserId);

    // Générer la clé AES si elle n'existe pas encore
    final existingKey = await getConversationKey(convId);
    if (existingKey == null) {
      await _setConversationKey(convId, _generateAesKey());
    }
    return convId;
  }

  Stream<List<Map<String, dynamic>>> getRecentConversations() {
    _loadConversations();
    return _convController.stream;
  }

  Future<void> _loadConversations() async {
    if (!_network.isAuthenticated) {
      if (!_convController.isClosed) _convController.add([]);
      return;
    }
    try {
      final currentUser = await _authService.currentUser;
      if (currentUser == null) return;

      final serverConvs = await _network.getConversations();
      final mapped = <Map<String, dynamic>>[];

      for (final c in serverConvs) {
        final otherId    = c['other_id']?.toString()       ?? '';
        final otherEmail = c['other_email']?.toString()    ?? '';
        final username   = c['other_username']?.toString() ?? '';
        final photo      = c['photo_base64'] as String?;
        final pubKey     = c['public_key']   as String?;

        // Mettre à jour le cache utilisateur
        if (otherId.isNotEmpty) {
          final userData = {
            'id':          otherId,
            'email':       otherEmail,
            'username':    username,
            'displayName': _buildDisplayName(c.map((k, v) => MapEntry(k.toString(), v))),
            'rsaPublicKey': pubKey,
            'public_key':   pubKey,
            'photoBase64':  photo,
          };
          _userDataCache[otherId] = userData;
          if (photo != null) _userPhotoCache[otherId] = photo;
        }

        final convId   = _buildConversationId(currentUser.id, otherId);
        final lastType = c['last_type']?.toString();
        final preview  = _previewFromType(lastType);

        mapped.add({
          'conversationId': convId,
          'email':          otherEmail,
          'name':           username.isNotEmpty ? username : otherEmail,
          'lastMessage':    preview,
          'updatedAt':      c['last_timestamp']?.toString() ?? c['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          'otherUserId':    otherId,
        });
      }

      mapped.sort((a, b) => (b['updatedAt'] as String).compareTo(a['updatedAt'] as String));
      _conversationsCache..clear()..addAll(mapped);
      if (!_convController.isClosed) _convController.add(List.from(mapped));
    } catch (e) {
      debugPrint('[ChatService] _loadConversations: $e');
    }
  }

  String _previewFromType(String? type) {
    switch (type) {
      case 'image': return '🖼 Image';
      case 'file':  return '📎 Fichier';
      case 'audio': return '🎵 Vocal';
      case null:    return 'Conversation sécurisée';
      default:      return 'Message chiffré';
    }
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Stream<List<ChatMessageModel>> getMessages(String conversationId) {
    _msgControllers[conversationId] ??=
        StreamController<List<ChatMessageModel>>.broadcast();

    // Émettre immédiatement les données en cache (évite le race condition)
    final cached = _messagesCache[conversationId];
    if (cached != null) {
      Future.microtask(() => _pushCachedMessages(conversationId));
    }

    _loadMessages(conversationId);
    markConversationRead(conversationId);
    return _msgControllers[conversationId]!.stream;
  }

  Future<void> _loadMessages(String conversationId) async {
    if (!_network.isAuthenticated) return;
    try {
      final currentUser = await _authService.currentUser;
      if (currentUser == null) return;

      final serverMsgs = await _network.getMessages(conversationId);
      final msgs = serverMsgs
          .map((m) => _mapServerMessage(
                Map<String, dynamic>.from(m), conversationId, currentUser))
          .toList()
        ..sort((a, b) =>
            (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

      _messagesCache[conversationId] = msgs;
      _pushCachedMessages(conversationId);
    } catch (e) {
      debugPrint('[ChatService] _loadMessages $conversationId: $e');
      // Émettre une liste vide pour sortir du CircularProgressIndicator
      if (!(_messagesCache.containsKey(conversationId))) {
        _messagesCache[conversationId] = [];
        _pushCachedMessages(conversationId);
      }
    }
  }

  ChatMessageModel _mapServerMessage(
    Map<String, dynamic> m,
    String conversationId,
    LocalUser currentUser,
  ) {
    final senderId   = m['sender_id']?.toString() ?? '';
    final parts      = conversationId.split('_');
    final receiverId = parts.firstWhere((p) => p != senderId, orElse: () => '');

    return ChatMessageModel.fromMap(m['id']?.toString() ?? _generateId(), {
      'conversationId':  conversationId,
      'senderId':        senderId,
      'senderEmail':     senderId == currentUser.id ? currentUser.email : '',
      'senderName':      senderId == currentUser.id ? currentUser.displayName : '',
      'receiverId':      receiverId,
      'receiverEmail':   '',
      'receiverName':    '',
      'encryptionMode':  m['mode'] ?? 'symmetric',
      'cipherText':      m['cipher_text'] ?? '',
      'nonce':           m['iv'] ?? '',
      'mac':             '',
      'algorithm':       m['algorithm'] ?? 'aes-gcm',
      'encryptedAesKey': m['encrypted_aes_key'] ?? '',
      'signature':       m['signature'],
      'iv':              m['iv'],
      'createdAt':       m['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      'type':            m['type'] ?? 'text',
      'fileName':        m['file_name'],
      'fileSize':        m['file_size'] is int
                           ? m['file_size']
                           : int.tryParse(m['file_size']?.toString() ?? ''),
      'senderPlainText': '',
      'readAt':          m['read_at']?.toString(),
    });
  }

  void _pushCachedMessages(String conversationId) {
    final msgs = _messagesCache[conversationId] ?? [];
    final ctrl  = _msgControllers[conversationId];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(List.from(msgs));
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
    final receiverId = receiverData['id'] as String;

    final conversationId = await getOrCreateConversation(receiverId, receiverEmail);
    final msgId = _generateId();
    final now   = DateTime.now().toIso8601String();

    String  cipherText;
    String  nonce = '';
    String  mac   = '';
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

      final msgBytes = Uint8List.fromList(utf8.encode(text));
      final sigBytes = RsaService.sign(msgBytes, privKey);
      signature      = base64Encode(sigBytes);

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
      String? key = await getConversationKey(conversationId);
      if (key == null) {
        key = _generateAesKey();
        await _setConversationKey(conversationId, key);
      }
      final payload = await CryptoAvance.encryptMessage(message: text, key: key, algorithm: algorithm);
      cipherText = payload.cipherText;
      nonce      = payload.nonce;
      mac        = payload.mac;
    }

    // Message optimiste (affiché immédiatement, avant confirmation serveur)
    final optimistic = ChatMessageModel.fromMap(msgId, {
      'conversationId':  conversationId,
      'senderId':        currentUser.id,
      'senderEmail':     currentUser.email,
      'senderName':      currentUser.displayName,
      'receiverId':      receiverId,
      'receiverEmail':   receiverEmail.trim().toLowerCase(),
      'receiverName':    receiverData['displayName'] ?? receiverEmail,
      'encryptionMode':  mode,
      'cipherText':      cipherText,
      'nonce':           nonce,
      'mac':             mac,
      'algorithm':       mode == 'asymmetric' ? 'rsa+aes-gcm' : algorithm,
      'encryptedAesKey': encryptedAesKey ?? '',
      'signature':       signature,
      'iv':              iv,
      'createdAt':       now,
      'type':            type,
      'fileName':        fileName,
      'fileSize':        fileSize,
      'senderPlainText': text,
    });

    _messagesCache.putIfAbsent(conversationId, () => []).add(optimistic);
    _pushCachedMessages(conversationId);
    _updateConversationPreview(conversationId, now, type);

    // Persistance sur le serveur
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
          iv:             iv ?? nonce,
          signature:      signature,
        );
      } catch (e) {
        debugPrint('[ChatService] Envoi serveur échoué: $e');
      }
    }
  }

  void _updateConversationPreview(String convId, String timestamp, String type) {
    final preview = _previewFromType(type == 'text' ? 'text_sent' : type);
    final idx = _conversationsCache.indexWhere((c) => c['conversationId'] == convId);
    if (idx >= 0) {
      _conversationsCache[idx] = {
        ..._conversationsCache[idx],
        'lastMessage': _previewFromType(type == 'text' ? null : type) == 'Conversation sécurisée'
            ? 'Message chiffré'
            : _previewFromType(type),
        'updatedAt': timestamp,
      };
      _conversationsCache.sort((a, b) => (b['updatedAt'] as String).compareTo(a['updatedAt'] as String));
    }
    if (!_convController.isClosed) _convController.add(List.from(_conversationsCache));
  }

  // ── Message reçu via WebSocket ────────────────────────────────────────────

  Future<void> saveReceivedMessage(Map<String, dynamic> data) async {
    final conversationId = data['conversationId'] as String?;
    if (conversationId == null) return;

    final msgId = (data['id'] ?? _generateId()).toString();
    final msg   = ChatMessageModel.fromMap(msgId, {
      'conversationId':  conversationId,
      'senderId':        data['senderId']?.toString() ?? '',
      'senderEmail':     '',
      'senderName':      '',
      'receiverId':      '',
      'receiverEmail':   '',
      'receiverName':    '',
      'encryptionMode':  data['mode'] ?? 'symmetric',
      'cipherText':      data['cipherText'] ?? '',
      'nonce':           data['iv'] ?? '',
      'mac':             '',
      'algorithm':       data['algorithm'] ?? 'aes-gcm',
      'encryptedAesKey': data['encryptedAesKey'] ?? '',
      'signature':       data['signature'],
      'iv':              data['iv'],
      'createdAt':       data['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      'type':            data['msgType'] ?? 'text',
      'fileName':        data['fileName'],
      'fileSize':        data['fileSize'] is int
                           ? data['fileSize']
                           : int.tryParse(data['fileSize']?.toString() ?? ''),
      'senderPlainText': '',
    });

    _messagesCache.putIfAbsent(conversationId, () => []).add(msg);
    _pushCachedMessages(conversationId);
    _updateConversationPreview(conversationId, DateTime.now().toIso8601String(), data['msgType'] ?? 'text');

    // Recharger la liste des conversations pour inclure les nouvelles
    _loadConversations();
  }

  // ── Read receipts ─────────────────────────────────────────────────────────

  Future<void> markConversationRead(String conversationId) async {
    if (!_network.isAuthenticated) return;
    try {
      await _network.markMessagesRead(conversationId);
    } catch (e) {
      debugPrint('[ChatService] markConversationRead: $e');
    }
  }

  // ── Suppression ───────────────────────────────────────────────────────────

  /// Supprime un message pour tout le monde (serveur + cache) — expéditeur only
  Future<void> deleteMessageForEveryone(String messageId, String conversationId) async {
    await _network.deleteMessage(messageId);
    _removeFromCache(messageId, conversationId);
  }

  /// Supprime un message uniquement pour soi — stocké en SharedPreferences
  Future<void> deleteMessageForMe(String messageId, String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList('hidden_msgs') ?? [];
    if (!hidden.contains(messageId)) {
      hidden.add(messageId);
      await prefs.setStringList('hidden_msgs', hidden);
    }
    _removeFromCache(messageId, conversationId);
  }

  void _removeFromCache(String messageId, String conversationId) {
    _messagesCache[conversationId]?.removeWhere((m) => m.id == messageId);
    _pushCachedMessages(conversationId);
  }

  /// Supprime toute la conversation (serveur + cache local)
  Future<void> deleteConversation(String conversationId) async {
    await _network.deleteConversation(conversationId);
    _messagesCache.remove(conversationId);
    _conversationsCache.removeWhere((c) => c['conversationId'] == conversationId);
    if (!_convController.isClosed) _convController.add(List.from(_conversationsCache));
  }

  /// Filtre les messages cachés (delete for me) avant de les pousser au stream
  Future<List<String>> _getHiddenMessages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('hidden_msgs') ?? [];
  }

  /// Brancher tous les callbacks WebSocket (appelé après login)
  void listenToReadReceipts() {
    // Message supprimé pour tout le monde
    _socket.onMessageDeleted = (data) {
      final msgId  = data['messageId']      as String?;
      final convId = data['conversationId'] as String?;
      if (msgId != null && convId != null) _removeFromCache(msgId, convId);
    };

    // Conversation supprimée par l'autre utilisateur
    _socket.onConversationDeleted = (data) {
      final convId = data['conversationId'] as String?;
      if (convId == null) return;
      _messagesCache.remove(convId);
      _conversationsCache.removeWhere((c) => c['conversationId'] == convId);
      if (!_convController.isClosed) _convController.add(List.from(_conversationsCache));
    };

    _socket.onMessageRead = (data) {
      final convId = data['conversationId'] as String?;
      final readAt = data['readAt'] as String?;
      if (convId == null || readAt == null) return;

      final msgs = _messagesCache[convId];
      if (msgs == null) return;

      bool changed = false;
      final updated = msgs.map((m) {
        if (m.readAt == null) {
          changed = true;
          return ChatMessageModel.fromMap(m.id, {
            ...m.toMap(),
            'id':     m.id,
            'readAt': readAt,
          });
        }
        return m;
      }).toList();

      if (changed) {
        _messagesCache[convId] = updated;
        _pushCachedMessages(convId);
      }
    };
  }

  // ── Sync on login (alias pour compatibilité avec AuthProvider) ────────────

  Future<void> syncFromServer() async {
    // Charger la photo du user courant dans le cache
    if (_network.isAuthenticated) {
      try {
        final me = await _network.getMe();
        final currentUser = await _authService.currentUser;
        if (currentUser != null && me['photo_base64'] != null) {
          _userPhotoCache[currentUser.id] = me['photo_base64'] as String;
        }
      } catch (_) {}
    }
    await _loadConversations();
  }

  // ── Déchiffrement ─────────────────────────────────────────────────────────

  Future<String> decryptMessage(ChatMessageModel msg) async {
    if (msg.encryptionMode == 'asymmetric') return _decryptAsymmetric(msg);

    final currentUser = await _authService.currentUser;
    if (currentUser != null && msg.senderId == currentUser.id) {
      return msg.senderPlainText.isNotEmpty ? msg.senderPlainText : '🔐 Message envoyé';
    }

    final key = await getConversationKey(msg.conversationId) ?? '';
    if (key.isEmpty) return '🔒 Message chiffré';
    try {
      return await CryptoAvance.decryptMessage(
        cipherText: msg.cipherText,
        nonce:      msg.nonce,
        mac:        msg.mac,
        key:        key,
        algorithm:  msg.algorithm.isEmpty ? 'aes-gcm' : msg.algorithm,
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
      final privKey     = RsaService.decodePrivateKey(privJson);
      final encAesKey   = base64Decode(msg.encryptedAesKey);
      final aesKeyBytes = RsaService.decryptWithPrivateKey(encAesKey, privKey);
      final aesKeyStr   = base64Encode(aesKeyBytes);

      final payload = await CryptoAvance.decryptMessage(
        cipherText: msg.cipherText,
        nonce:      msg.nonce,
        mac:        msg.mac,
        key:        aesKeyStr,
      );
      const sep    = '|SIG|';
      final sepIdx = payload.lastIndexOf(sep);
      return sepIdx >= 0 ? payload.substring(0, sepIdx) : payload;
    } catch (_) {
      return '🔒 Déchiffrement RSA impossible';
    }
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  String? getUserPhoto(String userId) => _userPhotoCache[userId];

  Future<bool> currentUserHasRsaKeys() async {
    final user = await _authService.currentUser;
    if (user == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('rsa_priv_${user.id}');
  }

  Future<bool> receiverHasRsaKeys(String emailOrUsername) async {
    final data = await getUserByEmail(emailOrUsername);
    return data?['rsaPublicKey'] != null || data?['public_key'] != null;
  }
}
