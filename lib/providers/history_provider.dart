import 'package:flutter/foundation.dart';
import '../models/crypto_history_model.dart';
import '../services/history_service.dart';

/// HistoryProvider — gère la liste d'historique en mémoire.
///
/// Utilisation dans une vue :
///
///   // Lire les items
///   final items = context.watch<HistoryProvider>().items;
///
///   // Ajouter un item
///   await context.read<HistoryProvider>().add(
///     userId: userId, type: 'hash', algorithm: 'SHA-256', ...
///   );
class HistoryProvider extends ChangeNotifier {
  final HistoryService _service = HistoryService();

  List<CryptoHistoryModel> _items = [];
  List<CryptoHistoryModel> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Charger l'historique ──────────────────────────────────────────────────

  Future<void> load(String userId) async {
    _isLoading = true;
    notifyListeners();

    _items = await _service.getHistory(userId);

    _isLoading = false;
    notifyListeners();
  }

  // ── Ajouter un item ───────────────────────────────────────────────────────

  Future<void> add({
    required String userId,
    required String type,
    required String algorithm,
    required String inputPreview,
    required String result,
    bool isEncrypted = false,
  }) async {
    await _service.addHistoryItem(
      userId: userId,
      type: type,
      algorithm: algorithm,
      inputPreview: inputPreview,
      result: result,
      isEncrypted: isEncrypted,
    );

    // Recharger la liste après l'ajout
    _items = await _service.getHistory(userId);
    notifyListeners();
  }

  // ── Supprimer un item ─────────────────────────────────────────────────────

  Future<void> delete({
    required String userId,
    required String historyId,
  }) async {
    await _service.deleteHistoryItem(userId: userId, historyId: historyId);
    _items.removeWhere((item) => item.id == historyId);
    notifyListeners();
  }

  // ── Vider l'historique ────────────────────────────────────────────────────

  Future<void> clear(String userId) async {
    await _service.clearHistory(userId);
    _items = [];
    notifyListeners();
  }
}
