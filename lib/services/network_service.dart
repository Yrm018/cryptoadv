import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

/// Service REST — communique avec le backend EC2 via HTTP
class NetworkService {
  static final NetworkService instance = NetworkService._();
  NetworkService._();

  String? _token;

  void setToken(String token) => _token = token;
  void clearToken()           => _token = null;
  bool  get isAuthenticated   => _token != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    required String password,
    String? publicKey,
  }) async {
    final res = await http.post(_uri('/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'email': email, 'username': username,
        'firstName': firstName, 'lastName': lastName,
        'password': password,
        if (publicKey != null) 'publicKey': publicKey,
      }),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final res = await http.post(_uri('/auth/login'),
      headers: _headers,
      body: jsonEncode({ 'identifier': identifier, 'password': password }),
    );
    final data = _parse(res);
    if (data['token'] != null) setToken(data['token']);
    return data;
  }

  // ── Utilisateurs ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(_uri('/users/me'), headers: _headers);
    return _parse(res);
  }

  Future<List<dynamic>> searchUsers(String query) async {
    final res = await http.get(
      _uri('/users/search?q=${Uri.encodeComponent(query)}'),
      headers: _headers,
    );
    return _parse(res) as List;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? photoBase64,
    String? publicKey,
  }) async {
    final res = await http.patch(_uri('/users/me'),
      headers: _headers,
      body: jsonEncode({
        if (firstName  != null) 'firstName':   firstName,
        if (lastName   != null) 'lastName':    lastName,
        if (photoBase64 != null) 'photoBase64': photoBase64,
        if (publicKey  != null) 'publicKey':   publicKey,
      }),
    );
    return _parse(res);
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getConversations() async {
    final res = await http.get(_uri('/messages/conversations'), headers: _headers);
    return _parse(res) as List;
  }

  Future<List<dynamic>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    final res = await http.get(
      _uri('/messages/$conversationId?limit=$limit&offset=$offset'),
      headers: _headers,
    );
    return _parse(res) as List;
  }

  Future<Map<String, dynamic>> sendMessage({
    required String id,
    required String conversationId,
    required String receiverId,
    required String cipherText,
    required String mode,
    required String algorithm,
    required String type,
    String? fileName,
    int?    fileSize,
    String? encryptedAesKey,
    String? iv,
    String? mac,
    String? signature,
    String? aesKey,          // clé AES de la conversation (stockée dans conversations.aes_key)
  }) async {
    final res = await http.post(_uri('/messages'),
      headers: _headers,
      body: jsonEncode({
        'id': id, 'conversationId': conversationId,
        'receiverId': receiverId, 'cipherText': cipherText,
        'mode': mode, 'algorithm': algorithm, 'type': type,
        if (fileName        != null) 'fileName':        fileName,
        if (fileSize        != null) 'fileSize':        fileSize,
        if (encryptedAesKey != null) 'encryptedAesKey': encryptedAesKey,
        if (iv              != null) 'iv':              iv,
        if (mac             != null) 'mac':             mac,
        if (signature       != null) 'signature':       signature,
        if (aesKey          != null) 'aesKey':          aesKey,
      }),
    );
    return _parse(res);
  }

  // ── Clés AES de conversation ──────────────────────────────────────────────

  /// Récupère la clé AES partagée depuis le serveur.
  /// Retourne null si aucune clé n'est encore stockée.
  Future<String?> fetchConversationKey(String conversationId) async {
    final res = await http.get(
      _uri('/messages/conversations/$conversationId/key'),
      headers: _headers,
    );
    if (res.statusCode == 403 || res.statusCode == 404) return null;
    final body = _parse(res) as Map<String, dynamic>;
    final key = body['aes_key'];
    return (key is String && key.isNotEmpty) ? key : null;
  }

  /// Pousse la clé AES vers le serveur (premier arrivé gagnant).
  /// Si le serveur avait déjà une clé différente, retourne cette clé existante.
  Future<String> pushConversationKey(String conversationId, String key) async {
    final res = await http.put(
      _uri('/messages/conversations/$conversationId/key'),
      headers: _headers,
      body: jsonEncode({'aes_key': key}),
    );
    final body = _parse(res) as Map<String, dynamic>;
    // Si conflit (une autre clé existait), on retourne la clé du serveur
    return (body['aes_key'] as String?) ?? key;
  }

  /// Supprime un message pour tout le monde (expéditeur seulement)
  Future<void> deleteMessage(String messageId) async {
    final res = await http.delete(_uri('/messages/$messageId'), headers: _headers);
    if (res.statusCode >= 400) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw NetworkException(
        statusCode: res.statusCode,
        message: (body is Map && body['error'] != null) ? body['error'] : 'Erreur',
      );
    }
  }

  /// Supprime toute une conversation et ses messages
  Future<void> deleteConversation(String conversationId) async {
    final res = await http.delete(
      _uri('/messages/conversation/$conversationId'),
      headers: _headers,
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw NetworkException(
        statusCode: res.statusCode,
        message: (body is Map && body['error'] != null) ? body['error'] : 'Erreur',
      );
    }
  }

  /// Marque tous les messages reçus de la conversation comme lus
  Future<void> markMessagesRead(String conversationId) async {
    final res = await http.patch(
      _uri('/messages/$conversationId/read'),
      headers: _headers,
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      throw NetworkException(
        statusCode: res.statusCode,
        message: (body is Map && body['error'] != null) ? body['error'] : 'Erreur réseau',
      );
    }
  }

  // ── Santé du serveur ──────────────────────────────────────────────────────

  Future<bool> isServerReachable() async {
    try {
      final res = await http.get(_uri('/health')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  dynamic _parse(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw NetworkException(
      statusCode: res.statusCode,
      message: (body is Map && body['error'] != null) ? body['error'] : 'Erreur réseau',
    );
  }
}

class NetworkException implements Exception {
  final int    statusCode;
  final String message;
  const NetworkException({ required this.statusCode, required this.message });

  @override
  String toString() => 'NetworkException($statusCode): $message';
}
