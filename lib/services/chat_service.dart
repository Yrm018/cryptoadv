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
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  final _authService = AuthService();
  final _socket      = SocketService.instance;
  final _network     = NetworkService.instance;

  final Map<String, List<ChatMessageModel>> _messagesCache      = {};
  final List<Map<String, dynamic>>          _conversationsCache = [];
  final Map<String, String>                 _userPhotoCache     = {};
  final Map<String, Map<String, dynamic>>   _userDataCache      = {};

  /// Cache mémoire des clés AES (une entrée par conversation, par session).
  /// Le serveur est autoritaire : on l'interroge une fois par conversation
  /// et on met en cache le résultat pour éviter un aller-retour à chaque message.
  final Map<String, String> _keyCache = {};

  final Map<String, StreamController<List<ChatMessageModel>>> _msgControllers = {};
  final _convController = StreamController<List<Map<String, dynamic>>>.broadcast();

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

  /// Retourne la clé AES de la conversation.
  ///
  /// Stratégie (le serveur est autoritaire) :
  /// 1. Cache mémoire → réponse immédiate sans réseau (déjà résolu cette session)
  /// 2. Serveur PostgreSQL → source de vérité partagée entre tous les appareils
  /// 3. SharedPreferences → fallback offline / anciennes conversations
  ///
  /// Si une clé locale existe mais que le serveur n'en a pas encore,
  /// on pousse la clé locale au serveur (migration des anciennes convs).
  Future<String?> getConversationKey(String convId) async {
    // 1. Cache mémoire (déjà résolu cette session → pas de réseau)
    final cached = _keyCache[convId];
    if (cached != null && cached.isNotEmpty) return cached;

    final prefs = await SharedPreferences.getInstance();

    // 2. Serveur (autoritaire — synchronise tous les appareils)
    if (_network.isAuthenticated) {
      try {
        final serverKey = await _network.fetchConversationKey(convId);
        if (serverKey != null && serverKey.isNotEmpty) {
          // Adopter la clé du serveur, mettre à jour local + mémoire
          _keyCache[convId] = serverKey;
          await prefs.setString('aes_conv_$convId', serverKey);
          return serverKey;
        }
      } catch (e) {
        debugPrint('[ChatService] getConversationKey server: $e');
      }
    }

    // 3. Fallback local (offline ou serveur sans clé)
    final local = prefs.getString('aes_conv_$convId');
    if (local != null && local.isNotEmpty) {
      _keyCache[convId] = local;
      // Migrer l'ancienne clé locale vers le serveur (fire-and-forget)
      if (_network.isAuthenticated) {
        _network.pushConversationKey(convId, local).then((confirmed) {
          if (confirmed != local) {
            // Conflit : le serveur avait déjà une autre clé → adopter celle du serveur
            _keyCache[convId] = confirmed;
            prefs.setString('aes_conv_$convId', confirmed);
            debugPrint('[ChatService] Clé serveur adoptée (migration conflit) pour $convId');
          }
        }).catchError((_) {});
      }
      return local;
    }

    return null;
  }

  /// Stocke la clé AES en mémoire, en local ET sur le serveur.
  /// Si le serveur retourne une clé différente (conflit), on l'adopte.
  Future<void> _setConversationKey(String convId, String key) async {
    _keyCache[convId] = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aes_conv_$convId', key);

    if (_network.isAuthenticated) {
      try {
        final confirmed = await _network.pushConversationKey(convId, key);
        if (confirmed != key) {
          _keyCache[convId] = confirmed;
          await prefs.setString('aes_conv_$convId', confirmed);
          debugPrint('[ChatService] Clé serveur adoptée (conflit) pour $convId');
        }
      } catch (e) {
        debugPrint('[ChatService] _setConversationKey push: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String emailOrUsername) async {
    final normalized = emailOrUsername.trim().toLowerCase();
    for (final user in _userDataCache.values) {
      if ((user['email']    as String?)?.toLowerCase() == normalized ||
          (user['username'] as String?)?.toLowerCase() == normalized) {
        return user;
      }
    }
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
              if (r['photo_base64'] != null) _userPhotoCache[uid] = r['photo_base64'] as String;
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

  Future<String> getOrCreateConversation(String otherUserId, String otherUserEmail) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) throw Exception('Utilisateur non connecté');
    final convId = _buildConversationId(currentUser.id, otherUserId);
    // Si on n'a pas encore de clé, on en génère une et on la stocke localement.
    // La clé sera poussée vers le serveur lors du premier envoi de message (via aesKey dans POST /messages),
    // ce qui garantit que la conversation existe déjà dans la DB à ce moment-là.
    final existingKey = await getConversationKey(convId);
    if (existingKey == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('aes_conv_$convId', _generateAesKey());
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
        if (otherId.isNotEmpty) {
          final userData = {
            'id':           otherId,
            'email':        otherEmail,
            'username':     username,
            'displayName':  _buildDisplayName(c.map((k, v) => MapEntry(k.toString(), v))),
            'rsaPublicKey': pubKey,
            'public_key':   pubKey,
            'photoBase64':  photo,
          };
          _userDataCache[otherId] = userData;
          if (photo != null) _userPhotoCache[otherId] = photo;
        }
        final convId   = _buildConversationId(currentUser.id, otherId);
        final lastType = c['last_type']?.toString();
        mapped.add({
          'conversationId': convId,
          'email':          otherEmail,
          'name':           username.isNotEmpty ? username : otherEmail,
          'lastMessage':    _previewFromType(lastType),
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

  Stream<List<ChatMessageModel>> getMessages(String conversationId) {
    _msgControllers[conversationId] ??=
        StreamController<List<ChatMessageModel>>.broadcast();
    final cached = _messagesCache[conversationId];
    if (cached != null) Future.microtask(() => _pushCachedMessages(conversationId));
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
          .map((m) => _mapServerMessage(Map<String, dynamic>.from(m), conversationId, currentUser))
          .toList()
        ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
      _messagesCache[conversationId] = msgs;
      _pushCachedMessages(conversationId);
    } catch (e) {
      debugPrint('[ChatService] _loadMessages $conversationId: $e');
      if (!_messagesCache.containsKey(conversationId)) {
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
      'nonce':           m['iv'] ?? '',        // iv = nonce dans notre protocole
      'mac':             m['mac'] ?? '',       // tag AES-GCM stocké en DB
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
      iv         = nonce;

      // Chiffre la clé AES avec la clé RSA publique du destinataire pour qu'il puisse déchiffrer
      final receiverPubJson = (receiverData['rsaPublicKey'] ?? receiverData['public_key']) as String?;
      if (receiverPubJson != null && receiverPubJson.isNotEmpty) {
        try {
          final receiverPubKey = RsaService.decodePublicKey(receiverPubJson);
          final aesKeyBytes    = base64Decode(key);
          encryptedAesKey = base64Encode(RsaService.encryptWithPublicKey(aesKeyBytes, receiverPubKey));
        } catch (_) {}
      }
    }

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

    if (_network.isAuthenticated) {
      try {
        // Pour le mode symétrique, on inclut la clé AES dans le POST messages.
        // Le serveur la stocke dans conversations.aes_key (COALESCE : first writer wins).
        // Ainsi, l'autre appareil peut la récupérer via GET /conversations/:convId/key.
        final convAesKey = mode == 'symmetric' ? await getConversationKey(conversationId) : null;

        await _network.sendMessage(
          id:              msgId,
          conversationId:  conversationId,
          receiverId:      receiverId,
          cipherText:      cipherText,
          mode:            mode,
          algorithm:       mode == 'asymmetric' ? 'rsa+aes-gcm' : algorithm,
          type:            type,
          fileName:        fileName,
          fileSize:        fileSize,
          encryptedAesKey: encryptedAesKey,
          iv:              iv,
          mac:             mac.isNotEmpty ? mac : null,
          signature:       signature,
          aesKey:          convAesKey,
        );
      } catch (e) {
        debugPrint('[ChatService] Envoi serveur échoué: $e');
      }
    }
  }

  void _updateConversationPreview(String convId, String timestamp, String type) {
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
      'mac':             data['mac'] ?? '',        // tag AES-GCM livré par WS
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
    _loadConversations();
  }

  Future<void> markConversationRead(String conversationId) async {
    if (!_network.isAuthenticated) return;
    try {
      await _network.markMessagesRead(conversationId);
    } catch (e) {
      debugPrint('[ChatService] markConversationRead: $e');
    }
  }

  Future<void> deleteMessageForEveryone(String messageId, String conversationId) async {
    await _network.deleteMessage(messageId);
    _removeFromCache(messageId, conversationId);
  }

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

  Future<void> deleteConversation(String conversationId) async {
    await _network.deleteConversation(conversationId);
    _messagesCache.remove(conversationId);
    _conversationsCache.removeWhere((c) => c['conversationId'] == conversationId);
    if (!_convController.isClosed) _convController.add(List.from(_conversationsCache));
  }

  void listenToReadReceipts() {
    _socket.onMessageDeleted = (data) {
      final msgId  = data['messageId']      as String?;
      final convId = data['conversationId'] as String?;
      if (msgId != null && convId != null) _removeFromCache(msgId, convId);
    };

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

  Future<void> syncFromServer() async {
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

    // Message optimiste (envoyé dans cette session) : texte clair dispo
    if (currentUser != null &&
        msg.senderId == currentUser.id &&
        msg.senderPlainText.isNotEmpty) {
      return msg.senderPlainText;
    }

    // Message chargé depuis le serveur → déchiffrement AES avec clé locale
    String? key = await getConversationKey(msg.conversationId);

    // Clé absente localement : essayer de la dériver depuis encryptedAesKey (chiffrée avec notre RSA privé)
    if ((key == null || key.isEmpty) && msg.encryptedAesKey.isNotEmpty) {
      key = await _deriveSymmetricKey(msg.conversationId, msg.encryptedAesKey, currentUser);
    }

    if (key == null || key.isEmpty) {
      return currentUser?.id == msg.senderId
          ? '🔐 Message envoyé'
          : '🔒 Message chiffré (clé manquante)';
    }
    try {
      return await CryptoAvance.decryptMessage(
        cipherText: msg.cipherText,
        nonce:      msg.nonce.isNotEmpty ? msg.nonce : (msg.toMap()['iv'] ?? ''),
        mac:        msg.mac,
        key:        key,
        algorithm:  msg.algorithm.isEmpty ? 'aes-gcm' : msg.algorithm,
      );
    } catch (_) {
      return currentUser?.id == msg.senderId
          ? '🔐 Message envoyé'
          : '🔒 Message chiffré';
    }
  }

  /// Tente de déchiffrer la clé AES via la clé RSA privée locale, puis la met en cache.
  Future<String?> _deriveSymmetricKey(
    String conversationId,
    String encryptedAesKey,
    LocalUser? currentUser,
  ) async {
    if (currentUser == null) return null;
    try {
      final prefs    = await SharedPreferences.getInstance();
      final privJson = prefs.getString('rsa_priv_${currentUser.id}');
      if (privJson == null) return null;
      final privKey     = RsaService.decodePrivateKey(privJson);
      final encBytes    = base64Decode(encryptedAesKey);
      final aesKeyBytes = RsaService.decryptWithPrivateKey(encBytes, privKey);
      final aesKeyStr   = base64Encode(aesKeyBytes);
      await _setConversationKey(conversationId, aesKeyStr);
      return aesKeyStr;
    } catch (_) {
      return null;
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
