import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/network_service.dart';
import '../services/socket_service.dart';

const _kSavedToken = 'saved_jwt_token';

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

  /// Charge l'utilisateur et le token JWT depuis la session sauvegardée.
  Future<void> _init() async {
    _currentUser = await _authService.currentUser;

    // Restaurer le token JWT et reconnecter le socket si l'utilisateur est connu
    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kSavedToken);
      if (token != null) {
        _network.setToken(token);
        ChatService.instance.listenToReadReceipts();
        await _socket.connect(token);
        // Récupérer les messages manqués pendant la déconnexion
        ChatService.instance.syncFromServer().catchError(
          (e) => debugPrint('[AuthProvider] sync init échoué: $e'),
        );
      }
    }

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
      // Persister le token JWT pour la reconnexion après rechargement de page
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSavedToken, token);

      _network.setToken(token);
      ChatService.instance.listenToReadReceipts();

      // Sauvegarder la session localement (SharedPreferences + Hive)
      // afin que ChatService.currentUser puisse retrouver l'utilisateur.
      await _authService.saveServerSession(Map<String, dynamic>.from(userMap!));

      _currentUser = LocalUser.fromMap(userMap!);
      await _socket.connect(token);
      notifyListeners();

      // Synchroniser les conversations et messages manqués depuis le serveur
      ChatService.instance.syncFromServer().catchError(
        (e) => debugPrint('[AuthProvider] sync échoué: $e'),
      );
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSavedToken);
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
