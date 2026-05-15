import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../views/auth/auth_page.dart';
import '../../views/home/home_page.dart';
import '../../views/hachage/hachage_page.dart';
import '../../views/chiffrement/chiffrement_page.dart';
import '../../views/mot_de_passe/mdp_page.dart';
import '../../views/documentation/documentation_page.dart';
import '../../views/chat/chat_page.dart';
import '../../views/history/history_page.dart';
import '../../views/vpn/vpn_page.dart';
import '../../views/settings/account_settings_dialog.dart';
import '../common/user_avatar.dart';

class AppDrawer extends StatelessWidget {
  final String currentPage;
  const AppDrawer({super.key, required this.currentPage});

  bool _isActive(String p) => currentPage == p;

  Widget _item({
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
      leading: Icon(icon,
          color: active
              ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700)
              : (color ?? (isDark ? Colors.white70 : Colors.black54))),
      title: Text(title,
          style: TextStyle(
            color: active
                ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700)
                : (color ?? (isDark ? Colors.white : Colors.black87)),
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          )),
      selected: active,
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) { onTap(); return; }
        if (active || page == null) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider  = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final authProvider   = context.watch<AuthProvider>();
    final l      = AppL10n.of(context);
    final isDark = themeProvider.isDarkMode;
    final user   = authProvider.currentUser;
    final initial = (user?.username.isNotEmpty == true)
        ? user!.username[0].toUpperCase()
        : '?';

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          // ── En-tête utilisateur ───────────────────────────────────────────
          DrawerHeader(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0047AB), const Color(0xFF0F172A)]
                    : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      showAccountSettings(context);
                    },
                    child: Stack(children: [
                      UserAvatar(
                        photoBase64:     user?.photoBase64,
                        initial:         initial,
                        radius:          28,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        fontSize:        20,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue.shade300, width: 1.5),
                          ),
                          child: Icon(Icons.edit, size: 10, color: Colors.blue.shade700),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(user?.displayName ?? 'Utilisateur',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('@${user?.username ?? ''}',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  Text(user?.email ?? '',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                ],
              ),
            ),
          ),

          // ── Navigation ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _item(context: context, title: l.t('home'),          icon: Icons.home_rounded,                page: const HomePage(),          active: _isActive('home')),
                _item(context: context, title: l.t('hachage'),       icon: Icons.fingerprint_rounded,         page: const HachagePage(),       active: _isActive('hachage')),
                _item(context: context, title: l.t('chiffrement'),   icon: Icons.enhanced_encryption_rounded, page: const ChiffrementPage(),   active: _isActive('chiffrement')),
                _item(context: context, title: l.t('mdp'),           icon: Icons.password_rounded,            page: const MdpPage(),           active: _isActive('mdp')),
                _item(context: context, title: l.t('chat'),          icon: Icons.chat_bubble_outline_rounded, page: const ChatPage(),          active: _isActive('chat')),
                _item(context: context, title: l.t('vpn'),           icon: Icons.vpn_lock_rounded,            page: const VpnPage(),           active: _isActive('vpn')),
                const Divider(),
                _item(context: context, title: l.t('history'),       icon: Icons.history_rounded,             page: const HistoryPage(),       active: _isActive('history')),
                _item(context: context, title: l.t('documentation'), icon: Icons.menu_book_rounded,           page: const DocumentationPage(), active: _isActive('documentation')),
              ],
            ),
          ),

          // ── Sélecteur de langue ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.t('language'),
                  style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Row(children: [
                _langBtn(context, localeProvider, '🇫🇷', 'fr', l.t('french'), isDark),
                const SizedBox(width: 8),
                _langBtn(context, localeProvider, '🇬🇧', 'en', l.t('english'), isDark),
                const SizedBox(width: 8),
                _langBtn(context, localeProvider, '🇸🇦', 'ar', l.t('arabic'), isDark),
              ]),
            ]),
          ),

          const Divider(height: 1),

          // ── Paramètres ───────────────────────────────────────────────────
          _item(context: context, title: l.t('account_settings'),
              icon: Icons.manage_accounts_outlined,
              onTap: () => showAccountSettings(context)),

          _item(context: context,
              title: isDark ? l.t('light_mode') : l.t('dark_mode'),
              icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              onTap: () => themeProvider.toggleTheme(!isDark)),

          _item(context: context, title: l.t('logout'),
              icon: Icons.logout_rounded, color: Colors.red,
              onTap: () async {
                await authProvider.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                    (route) => false,
                  );
                }
              }),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _langBtn(BuildContext context, LocaleProvider localeProvider,
      String flag, String code, String label, bool isDark) {
    final active = localeProvider.languageCode == code;
    return GestureDetector(
      onTap: () => localeProvider.setLocale(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? const Color(0xFF0047AB).withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          border: Border.all(
              color: active ? const Color(0xFF7AA6FF) : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(code.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: active
                      ? const Color(0xFF7AA6FF)
                      : (isDark ? Colors.white70 : Colors.black54))),
        ]),
      ),
    );
  }
}
