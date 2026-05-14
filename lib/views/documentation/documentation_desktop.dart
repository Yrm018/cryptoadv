import 'package:cryptoadv/widgets/common/app_navbar.dart';
import 'package:flutter/material.dart';
import 'package:cryptoadv/components/backround.dart';

class DocumentationDesktop extends StatelessWidget {
  const DocumentationDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: Column(
              children: [
                const AppNavbar(currentPage: 'documentation'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _glassCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Documentation", style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 30, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              Text("Cette application permet de manipuler plusieurs outils liés à la cybersécurité et au traitement de texte : hachage, chiffrement et génération de mots de passe.",
                                  style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.78), fontSize: 15, height: 1.6)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _glassCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle("1. Hachage", isDark),
                              const SizedBox(height: 14),
                              _sectionText("Le hachage consiste à transformer une donnée en une empreinte unique de longueur fixe. Cette empreinte sert surtout à vérifier l’intégrité d’un texte ou d’un fichier.", isDark),
                              const SizedBox(height: 16),
                              _bullet("Le hachage n’est pas un chiffrement.", isDark),
                              _bullet("On ne peut normalement pas retrouver le texte d’origine à partir du hash.", isDark),
                              _bullet("Deux textes identiques produisent le même hash.", isDark),
                              _bullet("Un petit changement dans le texte change complètement le résultat.", isDark),
                              const SizedBox(height: 16),
                              _sectionText("Exemples d’algorithmes de hachage :", isDark),
                              _bullet("MD5", isDark),
                              _bullet("SHA-1", isDark),
                              _bullet("SHA-256", isDark),
                              _bullet("SHA-512", isDark),
                              const SizedBox(height: 16),
                              _exampleBox("Exemple :\nTexte : bonjour\nSHA-256 : 2cf24dba5fb0a30e26e83b2ac5b9e29e...\n", isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _glassCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle("2. Chiffrement", isDark),
                              const SizedBox(height: 14),
                              _sectionText("Le chiffrement transforme un texte lisible en texte illisible afin de protéger son contenu. Contrairement au hachage, il est possible de retrouver le message d’origine.", isDark),
                              const SizedBox(height: 16),
                              _sectionText("Algorithmes disponibles :", isDark),
                              _bullet("César", isDark),
                              _bullet("Vigenère", isDark),
                              const SizedBox(height: 16),
                              Text("César", style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              _sectionText("Le chiffrement de César décale chaque lettre d’un nombre fixe. Par exemple, avec un décalage de 3 : A devient D, B devient E.", isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child, required bool isDark}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), color: isDark ? const Color(0xFF0047AB).withOpacity(0.22) : Colors.white.withOpacity(0.8), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.10))),
    child: child,
  );

  Widget _sectionTitle(String title, bool isDark) => Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.w700));
  Widget _sectionText(String text, bool isDark) => Text(text, style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.78), fontSize: 15, height: 1.6));
  Widget _bullet(String text, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text("• $text", style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.78), fontSize: 15)));
  Widget _exampleBox(String text, bool isDark) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: (isDark ? Colors.white : Colors.black).withOpacity(0.06), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08))), child: SelectableText(text, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, height: 1.5)));
}
