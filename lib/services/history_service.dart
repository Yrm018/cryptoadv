import 'dart:async';
import '../core/database/database_service.dart';
import '../models/crypto_history_model.dart';

/// HistoryService avec hive.
///
/// Hive vs SQL pour l'historique :
///   SQL  : SELECT * FROM history WHERE userId=? ORDER BY createdAt DESC
///   Hive : box.values.where(...).toList()..sort(...)
///
/// Chaque userId a son propre box "history_<userId>" → pas besoin de filtrer.
class HistoryService {
  final _db = DatabaseService.instance;

  // ── Stream simulé ─────────────────────────────────────────────────────────
  final Map<String, StreamController<List<CryptoHistoryModel>>> _controllers = {};

  StreamController<List<CryptoHistoryModel>> _getController(String userId) {
    return _controllers.putIfAbsent(
      userId,
      () => StreamController<List<CryptoHistoryModel>>.broadcast(),
    );
  }

  Future<void> _pushUpdate(String userId) async {
    final items = await getHistory(userId);
    final ctrl = _getController(userId);
    if (!ctrl.isClosed) ctrl.add(items);
  }

  // ── ID unique ─────────────────────────────────────────────────────────────
  String _generateId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    return '${t}_${t % 999983}';
  }

  // ── Ajouter ───────────────────────────────────────────────────────────────
  Future<void> addHistoryItem({
    required String userId,
    required String type,
    required String algorithm,
    required String inputPreview,
    required String result,
    bool isEncrypted = false,
  }) async {
    final box = await _db.historyBox(userId);
    final id = _generateId();

    // Hive : box.put(id, map)
    // L'id est la clé, la Map est la valeur
    await box.put(id, {
      'id': id,
      'userId': userId,
      'type': type,
      'algorithm': algorithm,
      'inputPreview': inputPreview,
      'result': result,
      'createdAt': DateTime.now().toIso8601String(),
      'isEncrypted': isEncrypted,
    });

    await _pushUpdate(userId);
  }

  // ── Lire l'historique ─────────────────────────────────────────────────────
  Future<List<CryptoHistoryModel>> getHistory(String userId) async {
    final box = await _db.historyBox(userId);

    // box.values → tous les items du box (pas besoin de filtrer par userId)
    // On trie par createdAt décroissant (le plus récent d'abord)
    final items = box.values
        .map((map) => CryptoHistoryModel.fromMap(Map<String, dynamic>.from(map)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return items;
  }

  // ── Stream ────────────────────────────────────────────────────────────────
  Stream<List<CryptoHistoryModel>> getHistoryStream(String userId) {
    final ctrl = _getController(userId);
    getHistory(userId).then((items) {
      if (!ctrl.isClosed) ctrl.add(items);
    });
    return ctrl.stream;
  }

  // ── Supprimer un item ─────────────────────────────────────────────────────
  Future<void> deleteHistoryItem({
    required String userId,
    required String historyId,
  }) async {
    final box = await _db.historyBox(userId);
    // Hive : box.delete(key) — la clé = l'id de l'item
    await box.delete(historyId);
    await _pushUpdate(userId);
  }

  // ── Vider l'historique ────────────────────────────────────────────────────
  Future<void> clearHistory(String userId) async {
    final box = await _db.historyBox(userId);
    // box.clear() supprime TOUS les items du box
    await box.clear();
    await _pushUpdate(userId);
  }

  void dispose(String userId) {
    _controllers[userId]?.close();
    _controllers.remove(userId);
  }
}
