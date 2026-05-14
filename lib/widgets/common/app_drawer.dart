import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class AppDrawer extends StatelessWidget {
  final String currentPage;

  const AppDrawer({super.key, required this.currentPage});

  bool _isActive(String pageName) => currentPage == pageName;

  Widget _drawerItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    Widget? page,
    VoidCallback? onTap,
    bool active = false,
    Color? color,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(
        icon,
        color: active 
            ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700) 
            : (color ?? (isDark ? Colors.white70 : Colors.black54)),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: active 
              ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700) 
              : (color ?? (isDark ? Colors.white : Colors.black87)),
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: active,
      onTap: () {
        Navigator.pop(context); // Close drawer
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final authService = AuthService();

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, color: Colors.white, size: 48),
                  const SizedBox(height: 10),
                  const Text(
                    'CryptoAdv',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(context: context, title: 'Home', icon: Icons.home_rounded, page: const HomePage(), active: _isActive('home')),
                _drawerItem(context: context, title: 'Hachage', icon: Icons.fingerprint_rounded, page: const HachagePage(), active: _isActive('hachage')),
                _drawerItem(context: context, title: 'Chiffrement', icon: Icons.enhanced_encryption_rounded, page: const ChiffrementPage(), active: _isActive('chiffrement')),
                _drawerItem(context: context, title: 'Mots de passe', icon: Icons.password_rounded, page: const MdpPage(), active: _isActive('mdp')),
                _drawerItem(context: context, title: 'Chat', icon: Icons.chat_bubble_outline_rounded, page: const ChatPage(), active: _isActive('chat')),
                _drawerItem(context: context, title: 'VPN', icon: Icons.vpn_lock_rounded, page: const VpnPage(), active: _isActive('vpn')),
                const Divider(),
                _drawerItem(context: context, title: 'Historique', icon: Icons.history_rounded, page: const HistoryPage(), active: _isActive('history')),
                _drawerItem(context: context, title: 'Documentation', icon: Icons.menu_book_rounded, page: const DocumentationPage(), active: _isActive('documentation')),
              ],
            ),
          ),
          const Divider(),
          _drawerItem(
            context: context,
            title: isDark ? 'Mode clair' : 'Mode sombre',
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            onTap: () => themeProvider.toggleTheme(!isDark),
          ),
          _drawerItem(
            context: context,
            title: 'Quitter',
            icon: Icons.logout_rounded,
            color: Colors.red,
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
