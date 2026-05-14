import 'package:flutter/foundation.dart';
import '../models/password_item_model.dart';
import '../services/password_service.dart';

/// PasswordProvider — gère la liste de mots de passe en mémoire.
///
/// Utilisation dans une vue :
///
///   // Lire les mots de passe
///   final passwords = context.watch<PasswordProvider>().passwords;
///
///   // Ajouter un mot de passe (déjà chiffré)
///   await context.read<PasswordProvider>().add(
///     userId: userId, title: 'Gmail', encryptedPassword: encrypted, ...
///   );
class PasswordProvider extends ChangeNotifier {
  final PasswordService _service = PasswordService();

  List<PasswordItemModel> _passwords = [];
  List<PasswordItemModel> get passwords => _passwords;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Charger les mots de passe ─────────────────────────────────────────────

  Future<void> load(String userId) async {
    _isLoading = true;
    notifyListeners();

    _passwords = await _service.getPasswords(userId);

    _isLoading = false;
    notifyListeners();
  }

  // ── Ajouter ───────────────────────────────────────────────────────────────

  Future<void> add({
    required String userId,
    required String title,
    required String encryptedPassword,
    String username = '',
    String website = '',
  }) async {
    final item = await _service.addPassword(
      userId: userId,
      title: title,
      encryptedPassword: encryptedPassword,
      username: username,
      website: website,
    );

    // Ajouter directement en mémoire (évite un re-SELECT)
    _passwords.add(item);
    // Retrier par titre pour maintenir l'ordre cohérent
    _passwords.sort((a, b) => a.title.compareTo(b.title));
    notifyListeners();
  }

  // ── Mettre à jour ─────────────────────────────────────────────────────────

  Future<void> update({
    required String id,
    required String userId,
    String? title,
    String? username,
    String? encryptedPassword,
    String? website,
  }) async {
    await _service.updatePassword(
      id: id,
      userId: userId,
      title: title,
      username: username,
      encryptedPassword: encryptedPassword,
      website: website,
    );

    // Recharger pour avoir les données fraîches
    _passwords = await _service.getPasswords(userId);
    notifyListeners();
  }

  // ── Supprimer ─────────────────────────────────────────────────────────────

  Future<void> delete({
    required String id,
    required String userId,
  }) async {
    await _service.deletePassword(id: id, userId: userId);
    _passwords.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // ── Vider ─────────────────────────────────────────────────────────────────

  Future<void> clear(String userId) async {
    await _service.clearPasswords(userId);
    _passwords = [];
    notifyListeners();
  }
}
