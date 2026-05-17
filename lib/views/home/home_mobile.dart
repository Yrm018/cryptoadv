import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/backround.dart';
import '../../core/localization/app_l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/app_drawer.dart';
import '../auth/auth_page.dart';
import '../mot_de_passe/mdp_page.dart';
import '../chiffrement/chiffrement_page.dart';
import '../documentation/documentation_page.dart';
import '../vpn/vpn_page.dart';

class HomeMobile extends StatelessWidget {
  const HomeMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);
    final bool isAuth      = context.watch<AuthProvider>().isAuthenticated;
    final themeProvider    = context.watch<ThemeProvider>();
    final localeProvider   = context.watch<LocaleProvider>();

    return Scaffold(
      drawer: const AppDrawer(currentPage: 'home'),
      appBar: AppBar(
        title: const Text('CryptoAdv'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          // ── Toggle thème ────────────────────────────────────────────────
          IconButton(
            onPressed: () => themeProvider.toggleTheme(!isDark),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.yellow.shade300 : Colors.indigo.shade400,
              size: 20,
            ),
            tooltip: isDark ? l.t('light_mode') : l.t('dark_mode'),
          ),
          // ── Sélecteur langue compact ────────────────────────────────────
          PopupMenuButton<String>(
            onSelected: (code) => localeProvider.setLocale(code),
            icon: Text(
              localeProvider.languageCode == 'fr' ? '🇫🇷'
                  : localeProvider.languageCode == 'en' ? '🇬🇧' : '🇸🇦',
              style: const TextStyle(fontSize: 20),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'fr', child: Row(children: [
                const Text('🇫🇷', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(l.t('french'), style: TextStyle(
                    fontWeight: localeProvider.languageCode == 'fr' ? FontWeight.bold : FontWeight.normal)),
              ])),
              PopupMenuItem(value: 'en', child: Row(children: [
                const Text('🇬🇧', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(l.t('english'), style: TextStyle(
                    fontWeight: localeProvider.languageCode == 'en' ? FontWeight.bold : FontWeight.normal)),
              ])),
              PopupMenuItem(value: 'ar', child: Row(children: [
                const Text('🇸🇦', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(l.t('arabic'), style: TextStyle(
                    fontWeight: localeProvider.languageCode == 'ar' ? FontWeight.bold : FontWeight.normal)),
              ])),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(
                    l.t('hero_title_1').replaceAll('\n', ' '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
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
                    child: Text(
                      l.t('hero_title_2'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l.t('hero_subtitle_mobile'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _actionButton(
                    label: isAuth ? "${l.t('our_tools')} →" : "${l.t('start_now')} →",
                    isPrimary: true,
                    isDark: isDark,
                    onTap: () {
                      if (!isAuth) {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const AuthPage(initialSignup: true)));
                      }
                    },
                  ),
                  if (!isAuth) ...[
                    const SizedBox(height: 12),
                    _actionButton(
                      label: l.t('login_btn'),
                      isPrimary: false,
                      isDark: isDark,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const AuthPage())),
                    ),
                  ],
                  const SizedBox(height: 60),
                  Text(
                    l.t('our_tools'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _featureCard(context, l.t('chiffrement'), l.t('feat_chiffrement_desc_mobile'), Icons.description, isAuth ? const ChiffrementPage() : null, isDark),
                  const SizedBox(height: 20),
                  _featureCard(context, l.t('mdp'), l.t('feat_mdp_desc_mobile'), Icons.lock, isAuth ? const MdpPage() : null, isDark),
                  const SizedBox(height: 20),
                  _featureCard(context, l.t('feat_vpn_title'), l.t('feat_vpn_desc_mobile'), Icons.vpn_lock_rounded, isAuth ? const VpnPage() : null, isDark),
                  const SizedBox(height: 20),
                  _featureCard(context, l.t('documentation'), l.t('feat_doc_desc_mobile'), Icons.menu_book, const DocumentationPage(), isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required String label, required bool isPrimary, required bool isDark, required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isPrimary ? LinearGradient(
          colors: isDark ? [const Color(0xFF00D4FF), const Color(0xFF6A5AE0)] : [const Color(0xFF3B82F6), const Color(0xFF4F46E5)],
        ) : null,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextButton(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _featureCard(BuildContext context, String title, String description, IconData icon, Widget? page, bool isDark) {
    return GestureDetector(
      onTap: page == null ? null : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? const Color(0xFF1A1F71).withOpacity(0.35) : Colors.white.withOpacity(0.8),
          border: Border.all(color: page != null ? (isDark ? const Color(0xFF7AA6FF).withOpacity(0.3) : const Color(0xFF3B82F6).withOpacity(0.2)) : (isDark ? Colors.white10 : Colors.black12)),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Icon(icon, color: isDark ? const Color(0xFF7AA6FF) : const Color(0xFF2563EB), size: 30),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  Text(description, style: TextStyle(fontSize: 14, color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.75))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white30 : Colors.black26, size: 16),
          ],
        ),
      ),
    );
  }
}
