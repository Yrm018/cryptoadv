class CryptoHistoryModel {
  final String id;
  final String userId;

  /// "hash" | "cipher" | "password"
  final String type;

  /// ex: "SHA-256", "César", "Vigenere"
  final String algorithm;

  /// petit aperçu du texte d’entrée (pas tout pour sécurité)
  final String inputPreview;

  /// résultat final (hash ou texte chiffré)
  final String result;

  final DateTime createdAt;

  /// pour savoir si c’est chiffré côté app
  final bool isEncrypted;

  const CryptoHistoryModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.algorithm,
    required this.inputPreview,
    required this.result,
    required this.createdAt,
    required this.isEncrypted,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'algorithm': algorithm,
      'inputPreview': inputPreview,
      'result': result,
      'createdAt': createdAt.toIso8601String(),
      'isEncrypted': isEncrypted,
    };
  }

  factory CryptoHistoryModel.fromMap(Map<String, dynamic> map) {
    return CryptoHistoryModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      algorithm: map['algorithm'] ?? '',
      inputPreview: map['inputPreview'] ?? '',
      result: map['result'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      isEncrypted: map['isEncrypted'] ?? false,
    );
  }
}