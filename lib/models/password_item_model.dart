/// Représente un mot de passe sauvegardé dans le gestionnaire.
///
/// Toutes les colonnes correspondent exactement aux colonnes de la table
/// SQLite "passwords" définie dans DatabaseService.
class PasswordItemModel {
  final String id;
  final String userId;
  final String title;             // ex: "Gmail", "GitHub"
  final String username;          // identifiant (email ou pseudo)
  final String encryptedPassword; // mot de passe chiffré — JAMAIS en clair
  final String website;           // URL optionnelle
  final DateTime createdAt;

  const PasswordItemModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.username,
    required this.encryptedPassword,
    required this.website,
    required this.createdAt,
  });

  /// Convertit le modèle en Map pour un INSERT SQLite.
  ///
  /// Les clés correspondent aux noms de colonnes de la table.
  /// DateTime → String ISO 8601 (SQLite ne gère pas nativement les dates).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'username': username,
      'encryptedPassword': encryptedPassword,
      'website': website,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Recrée un PasswordItemModel depuis une ligne SQLite (Map<String, dynamic>).
  ///
  /// SQLite retourne tout en Object?, donc on caste + on gère les null.
  factory PasswordItemModel.fromMap(Map<String, dynamic> map) {
    return PasswordItemModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      username: (map['username'] as String?) ?? '',
      encryptedPassword: map['encryptedPassword'] as String,
      website: (map['website'] as String?) ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Permet de créer une copie modifiée (utile pour les updates).
  PasswordItemModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? username,
    String? encryptedPassword,
    String? website,
    DateTime? createdAt,
  }) {
    return PasswordItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      username: username ?? this.username,
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      website: website ?? this.website,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
