import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'views/auth/auth_page.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
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
      home: const AuthPage(),
    );
  }
}
