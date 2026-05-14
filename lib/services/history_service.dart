import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/crypto_history_model.dart';

class HistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _historyRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('history');
  }

  Future<void> addHistoryItem({
    required String userId,
    required String type,
    required String algorithm,
    required String inputPreview,
    required String result,
    bool isEncrypted = false,
  }) async {
    final docRef = _historyRef(userId).doc();

    final item = CryptoHistoryModel(
      id: docRef.id,
      userId: userId,
      type: type,
      algorithm: algorithm,
      inputPreview: inputPreview,
      result: result,
      createdAt: DateTime.now(),
      isEncrypted: isEncrypted,
    );

    await docRef.set(item.toMap());
  }

  Stream<List<CryptoHistoryModel>> getHistoryStream(String userId) {
    return _historyRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CryptoHistoryModel.fromMap(data);
      }).toList();
    });
  }

  Future<void> deleteHistoryItem({
    required String userId,
    required String historyId,
  }) async {
    await _historyRef(userId).doc(historyId).delete();
  }

  Future<void> clearHistory(String userId) async {
    final snapshot = await _historyRef(userId).get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}