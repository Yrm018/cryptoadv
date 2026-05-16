import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message_model.dart';
import '../services/auth_service.dart';
import '../services/network_service.dart';
import '../services/socket_service.dart';
import '../backend/crypto/cryptavance.dart';

/// Modèle d'un groupe
class GroupModel {
  final String  id;
  final String  name;
  final String? description;
  final String? photoBase64;
  final String  createdBy;
  final String  role;          // 'admin' ou 'member'
  final int     memberCount;
  final String? lastTimestamp;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.photoBase64,
    required this.createdBy,
    required this.role,
    required this.memberCount,
    this.lastTimestamp,
  });

  factory GroupModel.fromMap(Map<String, dynamic> m) => GroupModel(
    id:            m['id']?.toString()          ?? '',
    name:          m['name']?.toString()        ?? '',
    description:   m['description']?.toString(),
    photoBase64:   m['photo_base64']?.toString(),
    createdBy:     m['created_by']?.toString()  ?? '',
    role:          m['role']?.toString()        ?? 'member',
    memberCount:   int.tryParse(m['member_count']?.toString() ?? '0') ?? 0,
    lastTimestamp: m['last_timestamp']?.toString(),
  );
}

/// Modèle d'un membre de groupe
class GroupMember {
  final String  id;
  final String  username;
  final String  firstName;
  final String  lastName;
  final String  email;
  final String? photoBase64;
  final String? publicKey;
  final String  role;

  const GroupMember({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.photoBase64,
    this.publicKey,
    required this.role,
  });

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : username;
  }

  factory GroupMember.fromMap(Map<String, dynamic> m) => GroupMember(
    id:          m['id']?.toString()          ?? '',
    username:    m['username']?.toString()    ?? '',
    firstName:   m['first_name']?.toString()  ?? '',
    lastName:    m['last_name']?.toString()   ?? '',
    email:       m['email']?.toString()       ?? '',
    photoBase64: m['photo_base64']?.toString(),
    publicKey:   m['public_key']?.toString(),
    role:        m['role']?.toString()        ?? 'member',
  );
}

/// GroupService — gestion des groupes chiffrés
class GroupService {
  static final GroupService instance = GroupService._();
  GroupService._();

  final _authService = AuthService();
  final _network     = NetworkService.instance;
  final _socket      = SocketService.instance;

  // Caches
  final List<GroupModel>                              _groupsCache  = [];
  final Map<String, List<ChatMessageModel>>           _msgCache     = {};
  final Map<String, List<GroupMember>>                _membersCache = {};

  // Streams
  final _groupsController = StreamController<List<GroupModel>>.broadcast();
  final Map<String, StreamController<List<ChatMessageModel>>> _msgControllers = {};

  Stream<List<GroupModel>> get groupsStream => _groupsController.stream;

  // ── Clé AES de groupe ─────────────────────────────────────────────────────

  String _aesKey(String groupId) => 'grp_aes_$groupId';

  String _generateAesKey() {
    final bytes = List.generate(32, (_) => Random.secure().nextInt(256));
    return base64Encode(Uint8List.fromList(bytes));
  }

  Future<String?> getGroupKey(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_aesKey(groupId));
    if (local != null && local.isNotEmpty) return local;

    // Chercher sur le serveur
    if (_network.isAuthenticated) {
      try {
        final serverKey = await _network.fetchGroupKey(groupId);
        if (serverKey != null && serverKey.isNotEmpty) {
          await prefs.setString(_aesKey(groupId), serverKey);
          return serverKey;
        }
      } catch (e) {
        debugPrint('[GroupService] getGroupKey: $e');
      }
    }
    return null;
  }

  Future<void> _setGroupKey(String groupId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aesKey(groupId), key);

    if (_network.isAuthenticated) {
      try {
        final confirmed = await _network.pushGroupKey(groupId, key);
        // Si conflit (une autre clé existait), adopter la clé du serveur
        if (confirmed != key) {
          await prefs.setString(_aesKey(groupId), confirmed);
          debugPrint('[GroupService] Clé adoptée depuis serveur (conflit) pour $groupId');
        }
      } catch (e) {
        debugPrint('[GroupService] _setGroupKey push: $e');
      }
    }
  }

  // ── CRUD Groupes ──────────────────────────────────────────────────────────

  Future<GroupModel> createGroup({
    required String name,
    String? description,
    String? photoBase64,
    List<String> memberIds = const [],
  }) async {
    final result = await _network.createGroup(
      name:        name,
      description: description,
      photoBase64: photoBase64,
      memberIds:   memberIds,
    );
    final groupId = result['id'] as String;

    // Générer et pousser la clé AES pour le groupe
    final key = _generateAesKey();
    await _setGroupKey(groupId, key);

    await loadGroups();
    return GroupModel.fromMap(result);
  }

  Future<void> loadGroups() async {
    if (!_network.isAuthenticated) {
      if (!_groupsController.isClosed) _groupsController.add([]);
      return;
    }
    try {
      final raw = await _network.getGroups();
      final groups = raw.map((g) => GroupModel.fromMap(Map<String, dynamic>.from(g))).toList();
      _groupsCache..clear()..addAll(groups);
      if (!_groupsController.isClosed) _groupsController.add(List.from(groups));
    } catch (e) {
      debugPrint('[GroupService] loadGroups: $e');
    }
  }

  Future<List<GroupMember>> getMembers(String groupId) async {
    try {
      final raw = await _network.getGroupMembers(groupId);
      final members = raw.map((m) => GroupMember.fromMap(Map<String, dynamic>.from(m))).toList();
      _membersCache[groupId] = members;
      return members;
    } catch (e) {
      debugPrint('[GroupService] getMembers: $e');
      return _membersCache[groupId] ?? [];
    }
  }

  Future<void> addMember(String groupId, String userId) async {
    await _network.addGroupMember(groupId, userId);
    // Pousser la clé AES au nouveau membre via le serveur (il la récupérera via GET /key)
    final key = await getGroupKey(groupId);
    if (key != null) await _network.pushGroupKey(groupId, key);
    _membersCache.remove(groupId); // invalider le cache
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _network.removeGroupMember(groupId, userId);
    _membersCache.remove(groupId);
  }

  Future<void> deleteGroup(String groupId) async {
    await _network.deleteGroup(groupId);
    _msgCache.remove(groupId);
    _membersCache.remove(groupId);
    _groupsCache.removeWhere((g) => g.id == groupId);
    if (!_groupsController.isClosed) _groupsController.add(List.from(_groupsCache));
    // Supprimer la clé locale
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_aesKey(groupId));
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Stream<List<ChatMessageModel>> getMessages(String groupId) {
    _msgControllers[groupId] ??=
        StreamController<List<ChatMessageModel>>.broadcast();
    final cached = _msgCache[groupId];
    if (cached != null) Future.microtask(() => _pushMessages(groupId));
    _loadMessages(groupId);
    return _msgControllers[groupId]!.stream;
  }

  Future<void> _loadMessages(String groupId) async {
    if (!_network.isAuthenticated) return;
    try {
      final currentUser = await _authService.currentUser;
      if (currentUser == null) return;
      final raw  = await _network.getGroupMessages(groupId);
      final msgs = raw
          .map((m) => _mapServerMsg(Map<String, dynamic>.from(m), groupId, currentUser))
          .toList()
        ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
      _msgCache[groupId] = msgs;
      _pushMessages(groupId);
    } catch (e) {
      debugPrint('[GroupService] _loadMessages $groupId: $e');
      _msgCache.putIfAbsent(groupId, () => []);
      _pushMessages(groupId);
    }
  }

  String _genId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    return 'gmsg_${t}_${(t * 9301 + 49297) % 233280}';
  }

  ChatMessageModel _mapServerMsg(
    Map<String, dynamic> m,
    String groupId,
    LocalUser currentUser,
  ) {
    final senderId = m['sender_id']?.toString() ?? '';
    return ChatMessageModel.fromMap(m['id']?.toString() ?? _genId(), {
      'conversationId':  groupId,       // on réutilise le champ conversationId pour le groupId
      'senderId':        senderId,
      'senderEmail':     senderId == currentUser.id ? currentUser.email : (m['email'] ?? ''),
      'senderName':      senderId == currentUser.id
          ? currentUser.displayName
          : '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim(),
      'receiverId':      '',
      'receiverEmail':   '',
      'receiverName':    '',
      'encryptionMode':  'symmetric',
      'cipherText':      m['cipher_text'] ?? '',
      'nonce':           m['iv'] ?? '',
      'mac':             m['mac'] ?? '',
      'algorithm':       m['algorithm'] ?? 'aes-gcm',
      'encryptedAesKey': '',
      'signature':       null,
      'iv':              m['iv'],
      'createdAt':       m['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      'type':            m['type'] ?? 'text',
      'fileName':        m['file_name'],
      'fileSize':        m['file_size'] is int
                           ? m['file_size']
                           : int.tryParse(m['file_size']?.toString() ?? ''),
      'senderPlainText': '',
    });
  }

  void _pushMessages(String groupId) {
    final msgs = _msgCache[groupId] ?? [];
    final ctrl  = _msgControllers[groupId];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(List.from(msgs));
  }

  Future<void> sendMessage({
    required String groupId,
    required String text,
    String algorithm = 'aes-gcm',
    String type      = 'text',
    String? fileName,
    int?    fileSize,
  }) async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) throw Exception('Utilisateur non connecté');

    // Récupérer (ou générer) la clé AES du groupe
    String? key = await getGroupKey(groupId);
    if (key == null) {
      key = _generateAesKey();
      await _setGroupKey(groupId, key);
    }

    final msgId   = _genId();
    final now     = DateTime.now().toIso8601String();
    final payload = await CryptoAvance.encryptMessage(
      message: text, key: key, algorithm: algorithm,
    );

    // Message optimiste (affiché immédiatement)
    final optimistic = ChatMessageModel.fromMap(msgId, {
      'conversationId':  groupId,
      'senderId':        currentUser.id,
      'senderEmail':     currentUser.email,
      'senderName':      currentUser.displayName,
      'receiverId':      '',
      'receiverEmail':   '',
      'receiverName':    '',
      'encryptionMode':  'symmetric',
      'cipherText':      payload.cipherText,
      'nonce':           payload.nonce,
      'mac':             payload.mac,
      'algorithm':       algorithm,
      'encryptedAesKey': '',
      'signature':       null,
      'iv':              payload.nonce,
      'createdAt':       now,
      'type':            type,
      'fileName':        fileName,
      'fileSize':        fileSize,
      'senderPlainText': text,
    });

    _msgCache.putIfAbsent(groupId, () => []).add(optimistic);
    _pushMessages(groupId);

    // Envoyer au serveur
    if (_network.isAuthenticated) {
      try {
        await _network.sendGroupMessage(
          id:         msgId,
          groupId:    groupId,
          cipherText: payload.cipherText,
          algorithm:  algorithm,
          type:       type,
          fileName:   fileName,
          fileSize:   fileSize,
          iv:         payload.nonce,
          mac:        payload.mac.isNotEmpty ? payload.mac : null,
        );
      } catch (e) {
        debugPrint('[GroupService] sendMessage: $e');
      }
    }
  }

  /// Déchiffrer un message de groupe
  Future<String> decryptMessage(ChatMessageModel msg) async {
    final currentUser = await _authService.currentUser;

    // Message optimiste de cette session
    if (currentUser != null &&
        msg.senderId == currentUser.id &&
        msg.senderPlainText.isNotEmpty) {
      return msg.senderPlainText;
    }

    final key = await getGroupKey(msg.conversationId);
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

  // ── WebSocket — réception temps réel ─────────────────────────────────────

  void listenToGroupEvents() {
    _socket.onGroupMessage = (data) async {
      final groupId = data['groupId'] as String?;
      if (groupId == null) return;

      final currentUser = await _authService.currentUser;
      if (currentUser == null) return;

      final msgId = (data['id'] ?? _genId()).toString();
      final msg   = ChatMessageModel.fromMap(msgId, {
        'conversationId':  groupId,
        'senderId':        data['senderId']?.toString() ?? '',
        'senderEmail':     '',
        'senderName':      '',
        'receiverId':      '',
        'receiverEmail':   '',
        'receiverName':    '',
        'encryptionMode':  'symmetric',
        'cipherText':      data['cipherText'] ?? '',
        'nonce':           data['iv'] ?? '',
        'mac':             data['mac'] ?? '',
        'algorithm':       data['algorithm'] ?? 'aes-gcm',
        'encryptedAesKey': '',
        'signature':       null,
        'iv':              data['iv'],
        'createdAt':       data['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
        'type':            data['msgType'] ?? 'text',
        'fileName':        data['fileName'],
        'fileSize':        data['fileSize'] is int
                             ? data['fileSize']
                             : int.tryParse(data['fileSize']?.toString() ?? ''),
        'senderPlainText': '',
      });

      _msgCache.putIfAbsent(groupId, () => []).add(msg);
      _pushMessages(groupId);
      await loadGroups(); // Rafraîchir la liste (dernier message)
    };

    _socket.onGroupCreated = (_) => loadGroups();
    _socket.onGroupAdded   = (_) => loadGroups();
    _socket.onGroupDeleted = (data) {
      final groupId = data['groupId'] as String?;
      if (groupId == null) return;
      _msgCache.remove(groupId);
      _membersCache.remove(groupId);
      _groupsCache.removeWhere((g) => g.id == groupId);
      if (!_groupsController.isClosed) _groupsController.add(List.from(_groupsCache));
    };
    _socket.onGroupRemoved = (data) {
      final groupId = data['groupId'] as String?;
      if (groupId == null) return;
      _msgCache.remove(groupId);
      _membersCache.remove(groupId);
      _groupsCache.removeWhere((g) => g.id == groupId);
      if (!_groupsController.isClosed) _groupsController.add(List.from(_groupsCache));
    };
  }
}
