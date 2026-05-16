import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/network_service.dart';
import '../services/socket_service.dart';

/// AuthProvider — expose l'utilisateur connecté à toute l'application.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final NetworkService _network = NetworkService.instance;
  final SocketService _socket = SocketService.instance;

  // L'utilisateur actuellement connecté (null = personne)
  LocalUser? _currentUser;
  LocalUser? get currentUser => _currentUser;

  // true pendant le chargement initial
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // true si un utilisateur est connecté
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _init();
  }

  /// Charge l'utilisateur depuis la session sauvegardée et connecte le socket.
  Future<void> _init() async {
    _currentUser = await _authService.currentUser;
    _isLoading = false;
    notifyListeners();
  }

  // ── Connexion ─────────────────────────────────────────────────────────────

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final response = await _network.login(
      identifier: identifier,
      password: password,
    );

    final String? token = response['token'];
    final Map? userMap = response['user'];

    if (token != null && userMap != null) {
      // IMPORTANT : Enregistrer le token pour les futurs appels API (recherche, messages, etc.)
      _network.setToken(token);
      
      _currentUser = LocalUser.fromMap(userMap);
      await _socket.connect(token);
      notifyListeners();
    }
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
    await _network.register(
      email: email,
      username: username,
      firstName: firstName,
      lastName: lastName,
      password: password,
    );

    await signIn(identifier: username, password: password);
  }

  // ── Mise à jour du profil ──────────────────────────────────────────────────

  Future<void> updateProfile({String? firstName, String? lastName}) async {
    if (_currentUser == null) return;
    final response = await _network.updateProfile(
      firstName: firstName,
      lastName: lastName,
    );
    _currentUser = LocalUser.fromMap(response);
    notifyListeners();
  }

  // ── Mise à jour du nom d'utilisateur ─────────────────────────────────────

  Future<void> updateUsername(String newUsername) async {
    if (_currentUser == null) return;
    notifyListeners();
  }

  // ── Mise à jour du mot de passe ───────────────────────────────────────────

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return;
    await _authService.updatePassword(
      userId: _currentUser!.id,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  // ── Mise à jour de la photo de profil ────────────────────────────────────

  Future<void> updatePhoto(String? base64Image) async {
    if (_currentUser == null) return;
    final response = await _network.updateProfile(
      photoBase64: base64Image,
    );
    _currentUser = LocalUser.fromMap(response);
    notifyListeners();
  }

  // ── Déconnexion ───────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _socket.disconnect();
    _network.clearToken();
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
