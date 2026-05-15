import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

/// AuthProvider — expose l'utilisateur connecté à toute l'application.
///
/// C'est le remplacement de FirebaseAuth.instance.currentUser.
/// Toutes les vues qui ont besoin du userId font maintenant :
///
///   context.read<AuthProvider>().currentUser?.id
///
/// Pourquoi un Provider ?
/// Sans Provider, chaque vue appellerait AuthService().currentUser qui
/// fait une lecture SharedPreferences + une requête SQLite à chaque fois.
/// Avec Provider, on charge une seule fois au démarrage et on notifie
/// les widgets quand l'état change (connexion/déconnexion).
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // L'utilisateur actuellement connecté (null = personne)
  LocalUser? _currentUser;
  LocalUser? get currentUser => _currentUser;

  // true pendant le chargement initial (splash screen / vérification de session)
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // true si un utilisateur est connecté
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    // Dès la création du Provider (au démarrage de l'app),
    // on vérifie si une session existe déjà dans SharedPreferences
    _init();
  }

  /// Charge l'utilisateur depuis la session sauvegardée.
  Future<void> _init() async {
    _currentUser = await _authService.currentUser;
    _isLoading = false;
    notifyListeners(); // prévient tous les widgets qui écoutent
  }

  // ── Connexion ─────────────────────────────────────────────────────────────

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    _currentUser = await _authService.signIn(identifier: identifier, password: password);
    notifyListeners();
  }

  // ── Inscription ───────────────────────────────────────────────────────────

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
    String? displayName,
  }) async {
    _currentUser = await _authService.signUp(
      email: email,
      password: password,
      username: username,
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
    );
    notifyListeners();
  }

  // ── Mise à jour du nom d'utilisateur ─────────────────────────────────────

  Future<void> updateUsername(String newUsername) async {
    final userId = _currentUser?.id;
    if (userId == null) return;
    _currentUser = await _authService.updateUsername(userId: userId, newUsername: newUsername);
    notifyListeners();
  }

  // ── Mise à jour du mot de passe ───────────────────────────────────────────

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final userId = _currentUser?.id;
    if (userId == null) return;
    await _authService.updatePassword(
      userId: userId,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  // ── Mise à jour du profil (prénom / nom) ──────────────────────────────────

  Future<void> updateProfile({String? firstName, String? lastName}) async {
    final userId = _currentUser?.id;
    if (userId == null) return;
    _currentUser = await _authService.updateProfile(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
    );
    notifyListeners();
  }

  // ── Mise à jour de la photo de profil ────────────────────────────────────

  Future<void> updatePhoto(String? base64Image) async {
    final userId = _currentUser?.id;
    if (userId == null) return;
    _currentUser = await _authService.updatePhoto(userId: userId, base64Image: base64Image);
    notifyListeners();
  }

  // ── Déconnexion ───────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
