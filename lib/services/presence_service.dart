import 'dart:async';
import 'package:flutter/foundation.dart';
import 'network_service.dart';
import 'socket_service.dart';

/// Maintient en temps réel la liste des utilisateurs en ligne.
/// Écoute les événements WebSocket user_online / user_offline
/// et peut aussi interroger le serveur REST /presence pour l'état initial.
class PresenceService extends ChangeNotifier {
  static final PresenceService instance = PresenceService._();
  PresenceService._();

  final _socket  = SocketService.instance;
  final _network = NetworkService.instance;

  final Set<String> _onlineIds = {};

  bool isOnline(String userId) => _onlineIds.contains(userId);

  /// À appeler une fois après la connexion WS.
  void startListening() {
    _socket.onUserOnline = (uid) {
      if (!_onlineIds.contains(uid)) {
        _onlineIds.add(uid);
        notifyListeners();
      }
    };
    _socket.onUserOffline = (uid) {
      if (_onlineIds.remove(uid)) {
        notifyListeners();
      }
    };
  }

  /// Interroge le serveur pour savoir lesquels de ces IDs sont en ligne.
  /// Utile au chargement initial de la liste des conversations.
  Future<void> fetchPresence(List<String> userIds) async {
    if (userIds.isEmpty || !_network.isAuthenticated) return;
    try {
      final online = await _network.fetchPresence(userIds);
      _onlineIds.addAll(online);
      notifyListeners();
    } catch (e) {
      debugPrint('[PresenceService] fetchPresence: $e');
    }
  }

  void clear() {
    _onlineIds.clear();
    notifyListeners();
  }
}
