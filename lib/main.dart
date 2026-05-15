import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/database/database_service.dart';
import 'providers/auth_provider.dart';
import 'providers/history_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/password_provider.dart';
import 'providers/theme_provider.dart';
import 'views/auth/auth_page.dart';
import 'views/home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
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
    final themeProvider  = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptoAdv',

      // ── Thème ──────────────────────────────────────────────────────────────
      themeMode: themeProvider.themeMode,
      theme:     ThemeData(brightness: Brightness.light, primarySwatch: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(brightness: Brightness.dark,  primarySwatch: Colors.blue, useMaterial3: true),

      // ── Localisation & RTL ─────────────────────────────────────────────────
      // GlobalWidgetsLocalizations gère automatiquement le sens de lecture :
      //   locale('ar') → textDirection RTL  (droite → gauche)
      //   locale('fr') ou ('en') → textDirection LTR (gauche → droite)
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const AppRoot(),
    );
  }
}

// ─── AppRoot ───────────────────────────────────────────────────────────────────
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A2E),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return auth.isAuthenticated ? const HomePage() : const AuthPage();
  }
}
