import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/logo.dart';
import '../../services/auth_service.dart';
import '../../views/auth/auth_page.dart';
import '../../views/home/home_page.dart';
import '../../views/hachage/hachage_page.dart';
import '../../views/chiffrement/chiffrement_page.dart';
import '../../views/mot_de_passe/mdp_page.dart';
import '../../views/documentation/documentation_page.dart';
import '../../views/chat/chat_page.dart';
import '../../views/history/history_page.dart';
import '../../views/vpn/vpn_page.dart';
import '../../providers/theme_provider.dart';

class AppNavbar extends StatelessWidget {
  final String currentPage;

  const AppNavbar({
    super.key,
    required this.currentPage,
  });

  Widget _navButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    Widget? page,
    VoidCallback? onTap,
    bool active = false,
    Color? color,
    required bool isDark,
  }) {
    final activeBg = isDark 
        ? const Color(0xFF0047ab).withOpacity(0.3)
        : const Color(0xFF3B82F6).withOpacity(0.15);
    
    final defaultIconColor = isDark 
        ? const Color(0xFFD1A7FF).withOpacity(0.7)
        : const Color(0xFF4F46E5).withOpacity(0.7);

    final defaultTextColor = isDark 
        ? const Color(0xFFD1A7FF)
        : const Color(0xFF4338CA);

    return TextButton(
      onPressed: () {
        if (onTap != null) {
          onTap();
          return;
        }
        if (active || page == null) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      style: TextButton.styleFrom(
        backgroundColor: active ? activeBg : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: active 
                ? (isDark ? Colors.white : const Color(0xFF2563EB)) 
                : (color ?? defaultIconColor),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color ?? (active && !isDark ? const Color(0xFF1E40AF) : defaultTextColor),
              fontWeight: active ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  bool _isActive(String pageName) => currentPage == pageName;

  Widget _glassContainer({required List<Widget> children, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: isDark 
            ? const Color(0xFF0047ab).withOpacity(0.25)
            : Colors.white.withOpacity(0.6),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.20) : Colors.black.withOpacity(0.05),
            offset: const Offset(0, 5),
            blurRadius: 15,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDark = themeProvider.isDarkMode;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Logo
          AnimatedLogo(size: LogoSize.md),

          const Spacer(flex: 2),

          // Premier Container : Outils avec Icônes
          _glassContainer(
            isDark: isDark,
            children: [
              _navButton(
                context: context,
                text: 'Home',
                icon: Icons.home_rounded,
                page: const HomePage(),
                active: _isActive('home'),
                isDark: isDark,
              ),
              _navButton(
                context: context,
                text: 'Hachage',
                icon: Icons.fingerprint_rounded,
                page: const HachagePage(),
                active: _isActive('hachage'),
                isDark: isDark,
              ),
              _navButton(
                context: context,
                text: 'Chiffrement',
                icon: Icons.enhanced_encryption_rounded,
                page: const ChiffrementPage(),
                active: _isActive('chiffrement'),
                isDark: isDark,
              ),
              _navButton(
                context: context,
                text: 'Mots de passe',
                icon: Icons.password_rounded,
                page: const MdpPage(),
                active: _isActive('mdp'),
                isDark: isDark,
              ),
              _navButton(
                context: context,
                text: 'Chat',
                icon: Icons.chat_bubble_outline_rounded,
                page: const ChatPage(),
                active: _isActive('chat'),
                isDark: isDark,
              ),
              _navButton(
                context: context,
                text: 'VPN',
                icon: Icons.vpn_lock_rounded,
                page: const VpnPage(),
                active: _isActive('vpn'),
                isDark: isDark,
              ),
            ],
          ),

          const Spacer(flex: 2),

          // Deuxième Container : Gestion avec Icônes
          _glassContainer(
            isDark: isDark,
            children: [
              _navButton(
                context: context,
                text: 'Historique',
                icon: Icons.history_rounded,
                page: const HistoryPage(),
                active: _isActive('history'),
                isDark: isDark,
              ),
              _navButton(
                context: context,
                text: 'Documentation',
                icon: Icons.menu_book_rounded,
                page: const DocumentationPage(),
                active: _isActive('documentation'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 20,
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
              ),
              const SizedBox(width: 4),
              // Bouton Thème
              IconButton(
                onPressed: () => themeProvider.toggleTheme(!isDark),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20,
                  color: isDark ? Colors.yellow.shade200 : Colors.indigo.shade700,
                ),
                tooltip: isDark ? 'Mode clair' : 'Mode sombre',
              ),
              const SizedBox(width: 4),
              Container(
                width: 1,
                height: 20,
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
              ),
              const SizedBox(width: 8),
              _navButton(
                context: context,
                text: 'Quitter',
                icon: Icons.logout_rounded,
                color: isDark ? Colors.redAccent.shade100 : Colors.red.shade700,
                isDark: isDark,
                onTap: () async {
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthPage()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
