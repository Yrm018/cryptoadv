import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_service.dart';

// ─── Exception personnalisée ──────────────────────────────────────────────────
class AuthException implements Exception {
  final String code;
  final String message;
  const AuthException({required this.code, required this.message});
  @override
  String toString() => 'AuthException[$code]: $message';
}

// ─── Modèle local ─────────────────────────────────────────────────────────────
class LocalUser {
  final String id;
  final String email;
  final String displayName;
  const LocalUser({required this.id, required this.email, required this.displayName});

  factory LocalUser.fromMap(Map map) => LocalUser(
    id: map['id'] as String,
    email: map['email'] as String,
    displayName: map['displayName'] as String,
  );
}

const _kCurrentUserId = 'current_user_id';

// ─── AuthService ──────────────────────────────────────────────────────────────
class AuthService {
  final _db = DatabaseService.instance;

  // ── Hachage SHA-256 ───────────────────────────────────────────────────────
  String _hashPassword(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  // ── ID unique ─────────────────────────────────────────────────────────────
  String _generateId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    return '${t}_${(t * 9301 + 49297) % 233280}';
  }

  // ── currentUser ───────────────────────────────────────────────────────────
  //
  // Hive : box.get(key) → retourne la Map stockée à cette clé
  //   Si la clé n'existe pas → retourne null
  //
  Future<LocalUser?> get currentUser async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kCurrentUserId);
    if (userId == null) return null;

    // Hive : chaque user est stocké à la clé = son id
    // users.get(userId) → Map{'id':…, 'email':…, …} ou null
    final userData = _db.users.get(userId);
    if (userData == null) {
      await _clearSession();
      return null;
    }
    return LocalUser.fromMap(userData);
  }

  // ── signUp ────────────────────────────────────────────────────────────────
  Future<LocalUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Hive n'a pas de WHERE — on parcourt toutes les valeurs
    // .values → Iterable de toutes les Maps stockées dans le box
    final emailExists = _db.users.values.any(
      (u) => u['email'] == normalizedEmail,
    );

    if (emailExists) {
      throw const AuthException(
        code: 'email-already-in-use',
        message: 'Un compte existe déjà avec cet email.',
      );
    }

    if (password.length < 6) {
      throw const AuthException(
        code: 'weak-password',
        message: 'Le mot de passe doit contenir au moins 6 caractères.',
      );
    }

    final userId = _generateId();
    final name = displayName ?? normalizedEmail.split('@').first;

    // Hive : box.put(key, value)
    // On stocke chaque user avec son id comme clé
    await _db.users.put(userId, {
      'id': userId,
      'email': normalizedEmail,
      'passwordHash': _hashPassword(password),
      'displayName': name,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _saveSession(userId);
    return LocalUser(id: userId, email: normalizedEmail, displayName: name);
  }

  // ── signIn ────────────────────────────────────────────────────────────────
  Future<LocalUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Chercher le user par email dans toutes les valeurs du box
    final userData = _db.users.values.firstWhere(
      (u) => u['email'] == normalizedEmail,
      orElse: () => {},
    );

    if (userData.isEmpty) {
      throw const AuthException(
        code: 'user-not-found',
        message: 'Aucun compte trouvé avec cet email.',
      );
    }

    if (userData['passwordHash'] != _hashPassword(password)) {
      throw const AuthException(
        code: 'wrong-password',
        message: 'Mot de passe incorrect.',
      );
    }

    final user = LocalUser.fromMap(userData);
    await _saveSession(user.id);
    return user;
  }

  // ── signOut ───────────────────────────────────────────────────────────────
  Future<void> signOut() async => _clearSession();

  Future<void> _saveSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentUserId, userId);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentUserId);
  }
}
