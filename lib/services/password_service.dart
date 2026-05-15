import '../core/database/database_service.dart';
import '../models/password_item_model.dart';

/// PasswordService avec hive.
class PasswordService {
  final _db = DatabaseService.instance;

  String _generateId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    return '${t}_${t % 999979}';
  }

  // ── Ajouter ───────────────────────────────────────────────────────────────
  Future<PasswordItemModel> addPassword({
    required String userId,
    required String title,
    required String encryptedPassword,
    String username = '',
    String website = '',
  }) async {
    final box = await _db.passwordsBox(userId);
    final id = _generateId();
    final now = DateTime.now();

    await box.put(id, {
      'id': id,
      'userId': userId,
      'title': title.trim(),
      'username': username.trim(),
      'encryptedPassword': encryptedPassword,
      'website': website.trim(),
      'createdAt': now.toIso8601String(),
    });

    return PasswordItemModel(
      id: id, userId: userId, title: title.trim(),
      username: username.trim(), encryptedPassword: encryptedPassword,
      website: website.trim(), createdAt: now,
    );
  }

  // ── Lire tous ─────────────────────────────────────────────────────────────
  Future<List<PasswordItemModel>> getPasswords(String userId) async {
    final box = await _db.passwordsBox(userId);

    return box.values
        .map((map) => PasswordItemModel.fromMap(Map<String, dynamic>.from(map)))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title)); // tri alphabétique
  }

  // ── Mettre à jour ─────────────────────────────────────────────────────────
  Future<void> updatePassword({
    required String id,
    required String userId,
    String? title,
    String? username,
    String? encryptedPassword,
    String? website,
  }) async {
    final box = await _db.passwordsBox(userId);
    final existing = Map<String, dynamic>.from(box.get(id) ?? {});
    if (existing.isEmpty) return;

    // On merge les nouvelles valeurs dans la Map existante
    if (title != null)             existing['title'] = title;
    if (username != null)          existing['username'] = username;
    if (encryptedPassword != null) existing['encryptedPassword'] = encryptedPassword;
    if (website != null)           existing['website'] = website;

    await box.put(id, existing);
  }

  // ── Supprimer ─────────────────────────────────────────────────────────────
  Future<void> deletePassword({
    required String id,
    required String userId,
  }) async {
    final box = await _db.passwordsBox(userId);
    await box.delete(id);
  }

  // ── Vider ─────────────────────────────────────────────────────────────────
  Future<void> clearPasswords(String userId) async {
    final box = await _db.passwordsBox(userId);
    await box.clear();
  }
}
