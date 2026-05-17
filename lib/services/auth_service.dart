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
  final String username;
  final String displayName;
  final String firstName;
  final String lastName;
  final String? photoBase64;

  const LocalUser({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    this.photoBase64,
  });

  factory LocalUser.fromMap(Map map) {
    final id = (map['id'] ?? map['user_id'] ?? '').toString();
    final email = (map['email'] ?? '').toString();
    final username = (map['username'] ?? map['user_name'] ?? email).toString();
    final fName = (map['firstName'] ?? map['first_name'] ?? '').toString();
    final lName = (map['lastName'] ?? map['last_name'] ?? '').toString();

    String dName = (map['displayName'] ?? map['display_name'] ?? '').toString();
    if (dName.isEmpty) {
      dName = '$fName $lName'.trim();
    }
    if (dName.isEmpty) dName = username;

    return LocalUser(
      id: id,
      email: email,
      username: username,
      displayName: dName,
      firstName: fName,
      lastName: lName,
      photoBase64: (map['photoBase64'] ?? map['photo_base64'])?.toString(),
    );
  }
}

const _kCurrentUserId = 'current_user_id';

// ─── AuthService ──────────────────────────────────────────────────────────────
class AuthService {
  final _db = DatabaseService.instance;

  String _hashPassword(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  String _generateId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    return '${t}_${(t * 9301 + 49297) % 233280}';
  }

  // ── currentUser ───────────────────────────────────────────────────────────
  Future<LocalUser?> get currentUser async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kCurrentUserId);
    if (userId == null) return null;
    final userData = _db.users.get(userId);
    if (userData == null) { await _clearSession(); return null; }
    return LocalUser.fromMap(userData);
  }

  // ── Validation mot de passe ───────────────────────────────────────────────
  void _validatePassword(String password) {
    if (password.length < 8) {
      throw const AuthException(code: 'weak-password', message: 'Le mot de passe doit contenir au moins 8 caractères.');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      throw const AuthException(code: 'weak-password', message: 'Le mot de passe doit contenir au moins une majuscule.');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      throw const AuthException(code: 'weak-password', message: 'Le mot de passe doit contenir au moins une minuscule.');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      throw const AuthException(code: 'weak-password', message: 'Le mot de passe doit contenir au moins un chiffre.');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*()\-_=+\[\]{};:,.<>?/\\|~]'))) {
      throw const AuthException(code: 'weak-password', message: 'Le mot de passe doit contenir au moins un caractère spécial.');
    }
  }

  // ── signUp ────────────────────────────────────────────────────────────────
  Future<LocalUser> signUp({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
    String? displayName,
  }) async {
    final normalizedEmail    = email.trim().toLowerCase();
    final normalizedUsername = username.trim().toLowerCase();

    if (normalizedUsername.isEmpty) {
      throw const AuthException(
        code: 'invalid-username',
        message: 'Le nom d\'utilisateur ne peut pas être vide.',
      );
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_\.]+$');
    if (!usernameRegex.hasMatch(normalizedUsername)) {
      throw const AuthException(
        code: 'invalid-username',
        message: 'Le nom d\'utilisateur ne peut contenir que des lettres, chiffres, _ et .',
      );
    }

    final emailExists = _db.users.values.any(
      (u) => u['email'] == normalizedEmail,
    );
    if (emailExists) {
      throw const AuthException(
        code: 'email-already-in-use',
        message: 'Un compte existe déjà avec cet email.',
      );
    }

    final usernameExists = _db.users.values.any(
      (u) => (u['username'] as String?)?.toLowerCase() == normalizedUsername,
    );
    if (usernameExists) {
      throw const AuthException(
        code: 'username-already-in-use',
        message: 'Ce nom d\'utilisateur est déjà pris.',
      );
    }

    _validatePassword(password);

    final userId = _generateId();
    final name = displayName ?? '$firstName $lastName'.trim();

    await _db.users.put(userId, {
      'id': userId,
      'email': normalizedEmail,
      'username': normalizedUsername,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'passwordHash': _hashPassword(password),
      'displayName': name,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _saveSession(userId);
    return LocalUser(
      id: userId,
      email: normalizedEmail,
      username: normalizedUsername,
      displayName: name,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    );
  }

  // ── signIn ────────────────────────────────────────────────────────────────
  Future<LocalUser> signIn({
    required String identifier,
    required String password,
  }) async {
    final normalized = identifier.trim().toLowerCase();

    Map userData = _db.users.values.firstWhere(
      (u) => u['email'] == normalized,
      orElse: () => {},
    );

    if (userData.isEmpty) {
      userData = _db.users.values.firstWhere(
        (u) => (u['username'] as String?)?.toLowerCase() == normalized,
        orElse: () => {},
      );
    }

    if (userData.isEmpty) {
      throw const AuthException(
        code: 'user-not-found',
        message: 'Aucun compte trouvé avec cet email ou nom d\'utilisateur.',
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

  // ── updateUsername ────────────────────────────────────────────────────────
  Future<LocalUser> updateUsername({
    required String userId,
    required String newUsername,
  }) async {
    final normalized = newUsername.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const AuthException(code: 'invalid-username', message: 'Le nom d\'utilisateur ne peut pas être vide.');
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_\.]+$');
    if (!usernameRegex.hasMatch(normalized)) {
      throw const AuthException(
        code: 'invalid-username',
        message: 'Le nom d\'utilisateur ne peut contenir que des lettres, chiffres, _ et .',
      );
    }
    final usernameExists = _db.users.values.any(
      (u) => (u['username'] as String?)?.toLowerCase() == normalized && u['id'] != userId,
    );
    if (usernameExists) {
      throw const AuthException(code: 'username-already-in-use', message: 'Ce nom d\'utilisateur est déjà pris.');
    }
    final userData = _db.users.get(userId);
    if (userData == null) throw const AuthException(code: 'user-not-found', message: 'Utilisateur introuvable.');
    final updated = Map<dynamic, dynamic>.from(userData);
    updated['username'] = normalized;
    await _db.users.put(userId, updated);
    return LocalUser.fromMap(updated);
  }

  // ── updatePassword ────────────────────────────────────────────────────────
  Future<void> updatePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final userData = _db.users.get(userId);
    if (userData == null) throw const AuthException(code: 'user-not-found', message: 'Utilisateur introuvable.');
    if (userData['passwordHash'] != _hashPassword(currentPassword)) {
      throw const AuthException(code: 'wrong-password', message: 'Mot de passe actuel incorrect.');
    }
    _validatePassword(newPassword);
    final updated = Map<dynamic, dynamic>.from(userData);
    updated['passwordHash'] = _hashPassword(newPassword);
    await _db.users.put(userId, updated);
  }

  // ── updateProfile ─────────────────────────────────────────────────────────
  Future<LocalUser> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
  }) async {
    final userData = _db.users.get(userId);
    if (userData == null) throw const AuthException(code: 'user-not-found', message: 'Utilisateur introuvable.');
    final updated = Map<dynamic, dynamic>.from(userData);
    if (firstName != null) updated['firstName'] = firstName.trim();
    if (lastName != null) updated['lastName'] = lastName.trim();
    updated['displayName'] = '${updated['firstName']} ${updated['lastName']}'.trim();
    await _db.users.put(userId, updated);
    return LocalUser.fromMap(updated);
  }

  // ── updatePhoto ───────────────────────────────────────────────────────────
  Future<LocalUser> updatePhoto({
    required String userId,
    required String? base64Image,
  }) async {
    final userData = _db.users.get(userId);
    if (userData == null) throw const AuthException(code: 'user-not-found', message: 'Utilisateur introuvable.');
    final updated = Map<dynamic, dynamic>.from(userData);
    if (base64Image == null) {
      updated.remove('photoBase64');
    } else {
      updated['photoBase64'] = base64Image;
    }
    await _db.users.put(userId, updated);
    return LocalUser.fromMap(updated);
  }

  String? getUserPhotoBase64(String userId) {
    return _db.users.get(userId)?['photoBase64'] as String?;
  }

  Future<void> signOut() async => _clearSession();

  // ── saveServerSession ─────────────────────────────────────────────────────
  /// Sauvegarde une session utilisateur provenant du serveur (login EC2).
  /// Mappe les champs snake_case du serveur vers le format local camelCase,
  /// puis persiste dans Hive et SharedPreferences.
  Future<void> saveServerSession(Map<String, dynamic> serverUser) async {
    final userId = serverUser['id']?.toString() ?? '';
    if (userId.isEmpty) return;

    final firstName = (serverUser['first_name'] ?? serverUser['firstName'] ?? '').toString();
    final lastName  = (serverUser['last_name']  ?? serverUser['lastName']  ?? '').toString();
    String displayName = '$firstName $lastName'.trim();
    if (displayName.isEmpty) {
      displayName = (serverUser['username'] ?? '').toString();
    }

    final normalized = <String, dynamic>{
      'id':          userId,
      'email':       (serverUser['email']    ?? '').toString(),
      'username':    (serverUser['username'] ?? '').toString(),
      'firstName':   firstName,
      'lastName':    lastName,
      'displayName': displayName,
      'createdAt':   serverUser['created_at']?.toString()
                     ?? serverUser['createdAt']?.toString()
                     ?? DateTime.now().toIso8601String(),
    };

    // Préserver la photo si elle existait déjà localement
    final existing = _db.users.get(userId);
    if (existing != null && existing['photoBase64'] != null) {
      normalized['photoBase64'] = existing['photoBase64'];
    }

    await _db.users.put(userId, normalized);
    await _saveSession(userId);
  }

  // ── Session ───────────────────────────────────────────────────────────────
  Future<void> _saveSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentUserId, userId);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentUserId);
  }
}
