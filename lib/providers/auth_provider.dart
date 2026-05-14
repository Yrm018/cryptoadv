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
    required String email,
    required String password,
  }) async {
    // AuthException est propagée — la vue la catch et affiche le message
    _currentUser = await _authService.signIn(email: email, password: password);
    notifyListeners();
  }

  // ── Inscription ───────────────────────────────────────────────────────────

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _currentUser = await _authService.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    notifyListeners();
  }

  // ── Déconnexion ───────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
