import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/database/database_service.dart';
import 'providers/auth_provider.dart';
import 'providers/history_provider.dart';
import 'providers/password_provider.dart';
import 'providers/theme_provider.dart';
import 'views/auth/auth_page.dart';
import 'views/home/home_page.dart';

Future<void> main() async {
  // Toujours appeler ça en premier dans main() quand on fait du code async
  // avant runApp() — ça initialise le binding Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise hive (remplace Firebase.initializeApp)
  // Crée les boxes "users" et "conversations" au démarrage
  await DatabaseService.instance.init();

  runApp(
    // MultiProvider = plusieurs providers en même temps
    // Sans MultiProvider, il faudrait les imbriquer manuellement :
    //   ChangeNotifierProvider(create: ..., child:
    //     ChangeNotifierProvider(create: ..., child: ...))
    //
    // Chaque provider est accessible depuis n'importe quel widget enfant via :
    //   context.read<AuthProvider>()   → lecture unique
    //   context.watch<AuthProvider>()  → écoute les changements (rebuild)
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => PasswordProvider()),
      ],
      child: const CryptoAdvApp(),
    ),
  );
}

class CryptoAdvApp extends StatelessWidget {
  const CryptoAdvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptoAdv',
      themeMode: context.watch<ThemeProvider>().themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // AppRoot gère la navigation auth vs app
      home: const AppRoot(),
    );
  }
}

// ─── AppRoot — décide quelle page afficher ─────────────────────────────────
//
// Avant (Firebase) : StreamBuilder sur authStateChanges → automatique
// Maintenant (hive) : on lit AuthProvider qui charge la session au démarrage
//
// 3 états possibles :
//   1. isLoading = true  → encore en train de vérifier la session → splash
//   2. isAuthenticated   → utilisateur connecté → HomePage
//   3. sinon             → pas connecté → AuthPage
//
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // État 1 — chargement initial (lecture SharedPreferences + hive)
    // Dure généralement < 100ms — on affiche juste un fond coloré
    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A2E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // État 2 — utilisateur connecté
    if (auth.isAuthenticated) {
      return const HomePage();
    }

    // État 3 — pas connecté
    return const AuthPage();
  }
}
