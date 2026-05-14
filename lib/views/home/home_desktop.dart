import 'package:cryptoadv/widgets/common/app_navbar.dart';
import 'package:flutter/material.dart';
import '../../components/backround.dart';
import '../mot_de_passe/mdp_page.dart';
import '../chiffrement/chiffrement_page.dart';
import '../documentation/documentation_page.dart';
import '../vpn/vpn_page.dart';

class HomeDesktop extends StatelessWidget {
  const HomeDesktop({super.key});

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
                const AppNavbar(currentPage: 'home'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
                    child: Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          Text(
                            "Gérez vos risques\nnumériques",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: isDark 
                                  ? [const Color(0xFF00D4FF), const Color(0xFFD1A7FF)]
                                  : [const Color(0xFF2563EB), const Color(0xFF7C3AED)],
                            ).createShader(bounds),
                            child: const Text(
                              "en toute sécurité",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: 700,
                            child: Text(
                              "YRM - Votre gestionnaire de risques gratuit et open source. "
                                  "Chiffrez vos données, générez des mots de passe sécurisés "
                                  "et protégez votre vie numérique.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _actionButton(
                                label: "Commencer maintenant →",
                                isPrimary: true,
                                isDark: isDark,
                                onTap: () {},
                              ),
                              const SizedBox(width: 20),
                              _actionButton(
                                label: "En savoir plus",
                                isPrimary: false,
                                isDark: isDark,
                                onTap: () {},
                              ),
                            ],
                          ),
                          const SizedBox(height: 120),
                          Text(
                            "Trois outils puissants pour votre sécurité",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Tout ce dont vous avez besoin pour protéger votre vie numérique",
                            style: TextStyle(
                              fontSize: 18,
                              color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 60),
                          Wrap(
                            spacing: 40,
                            runSpacing: 40,
                            alignment: WrapAlignment.center,
                            children: [
                              _featureCard(context, "Chiffrement", "Chiffrez et déchiffrez vos fichiers et messages sensibles.", Icons.description, const ChiffrementPage(), isDark),
                              _featureCard(context, "Mot de passe", "Générez et testez la robustesse de vos mots de passe.", Icons.lock, const MdpPage(), isDark),
                              _featureCard(context, "Messagerie VPN", "Messagerie sécurisée RSA+AES avec certificats X.509 et signature numérique.", Icons.vpn_lock_rounded, const VpnPage(), isDark),
                              _featureCard(context, "Documentation", "Apprenez les bonnes pratiques de sécurité.", Icons.menu_book, const DocumentationPage(), isDark),
                            ],
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required String label, required bool isPrimary, required bool isDark, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        gradient: isPrimary ? LinearGradient(
          colors: isDark ? [const Color(0xFF00D4FF), const Color(0xFF6A5AE0)] : [const Color(0xFF3B82F6), const Color(0xFF4F46E5)],
        ) : null,
        borderRadius: BorderRadius.circular(40),
        border: !isPrimary ? Border.all(color: isDark ? Colors.white24 : Colors.black12) : null,
      ),
      child: TextButton(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              color: isPrimary ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
              fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureCard(BuildContext context, String title, String description, IconData icon, Widget? page, bool isDark) {
    return GestureDetector(
      onTap: page == null ? null : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: isDark ? const Color(0xFF1A1F71).withOpacity(0.35) : Colors.white.withOpacity(0.8),
          border: Border.all(color: page != null ? (isDark ? const Color(0xFF7AA6FF).withOpacity(0.3) : const Color(0xFF3B82F6).withOpacity(0.2)) : (isDark ? Colors.white10 : Colors.black12)),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: page != null ? (isDark ? const Color(0xFF7AA6FF) : const Color(0xFF2563EB)) : (isDark ? const Color(0xFF00D4FF) : const Color(0xFF0891B2)), size: 40),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 12),
            Text(description, style: TextStyle(fontSize: 16, color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.75))),
            if (page != null) ...[
              const SizedBox(height: 16),
              Text('Accéder →', style: TextStyle(color: (isDark ? const Color(0xFF7AA6FF) : const Color(0xFF2563EB)).withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
