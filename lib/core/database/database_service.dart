import 'package:hive_flutter/hive_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DatabaseService — initialise hive et expose les "boxes" (collections).
//
// Hive vs SQLite :
//   SQLite → tables avec colonnes fixes, requêtes SQL
//   Hive   → "boxes" = des fichiers clé-valeur, comme des Maps persistantes
//
// Chaque box = une collection (ex: "users", "history_userId", "passwords_userId").
// Les données sont stockées en JSON (Map<String, dynamic>).
//
// Sur MOBILE  → fichier binaire dans le dossier documents de l'app
// Sur DESKTOP → même chose
// Sur WEB     → IndexedDB dans le navigateur (automatique avec hive_flutter)
//
// Aucune génération de code, aucune dépendance native → fonctionne partout.
// ─────────────────────────────────────────────────────────────────────────────

class DatabaseService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  static DatabaseService get instance => _instance;

  bool _initialized = false;

  // ── Noms des boxes ─────────────────────────────────────────────────────────
  //
  // On centralise les noms ici pour éviter les fautes de frappe.
  // Si tu changes un nom, tu le changes UNE seule fois ici.
  //
  static const String usersBox = 'users';
  // History et passwords : une box par userId
  static String historyBoxName(String userId)   => 'history_$userId';
  static String passwordsBoxName(String userId) => 'passwords_$userId';

  // ── Initialisation ─────────────────────────────────────────────────────────
  //
  // À appeler UNE FOIS dans main() avant runApp().
  // initFlutter() détecte automatiquement la plateforme :
  //   - mobile/desktop → utilise le dossier documents
  //   - web            → utilise IndexedDB dans le navigateur
  //
  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();

    // On ouvre les boxes globales au démarrage (les boxes par userId
    // sont ouvertes à la demande dans les services)
    await Hive.openBox<Map>(usersBox);

    _initialized = true;
  }

  // ── Accesseurs de boxes ────────────────────────────────────────────────────
  //
  // Utilisation dans les services :
  //   final usersBox = DatabaseService.instance.users;
  //   await usersBox.put(userId, userMap);
  //
  Box<Map> get users => Hive.box<Map>(usersBox);

  // Ces boxes sont ouvertes à la demande (lazy) car on ne connaît
  // le userId qu'après la connexion.
  Future<Box<Map>> historyBox(String userId) async {
    final name = historyBoxName(userId);
    if (!Hive.isBoxOpen(name)) {
      await Hive.openBox<Map>(name);
    }
    return Hive.box<Map>(name);
  }

  Future<Box<Map>> passwordsBox(String userId) async {
    final name = passwordsBoxName(userId);
    if (!Hive.isBoxOpen(name)) {
      await Hive.openBox<Map>(name);
    }
    return Hive.box<Map>(name);
  }

  /// Box de messages VPN (chiffrés RSA) — toujours stockés localement
  Future<Box<Map>> messagesBox(String convId) async {
    final name = 'messages_$convId';
    if (!Hive.isBoxOpen(name)) await Hive.openBox<Map>(name);
    return Hive.box<Map>(name);
  }

  // ── Nettoyage complet (logout ou reset) ───────────────────────────────────
  Future<void> deleteAll() async {
    await Hive.deleteFromDisk();
    _initialized = false;
  }
}
