import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/logo.dart';
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
import '../../views/groups/groups_page.dart';
import '../../views/history/history_page.dart';
import '../../views/vpn/vpn_page.dart';
import '../../views/settings/account_settings_dialog.dart';
import '../../main.dart'; // Pour AppRoot
import '../common/user_avatar.dart';

class AppNavbar extends StatelessWidget {
  final String currentPage;
  const AppNavbar({super.key, required this.currentPage});

  bool _isActive(String p) => currentPage == p;

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
    final defaultTextColor = isDark ? const Color(0xFFD1A7FF) : const Color(0xFF4338CA);

    return TextButton(
      onPressed: () {
        if (onTap != null) { onTap(); return; }
        if (active || page == null) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
      },
      style: TextButton.styleFrom(
        backgroundColor: active ? activeBg : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18,
              color: active
                  ? (isDark ? Colors.white : const Color(0xFF2563EB))
                  : (color ?? defaultIconColor)),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                color: color ?? (active && !isDark ? const Color(0xFF1E40AF) : defaultTextColor),
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              )),
        ],
      ),
    );
  }

  Widget _glassContainer({required List<Widget> children, required bool isDark}) =>
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: isDark
              ? const Color(0xFF0047ab).withOpacity(0.25)
              : Colors.white.withOpacity(0.6),
          border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.20) : Colors.black.withOpacity(0.05),
              offset: const Offset(0, 5),
              blurRadius: 15,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );

  // ── Popup Settings ────────────────────────────────────────────────────────

  Widget _settingsButton(BuildContext context, ThemeProvider themeProvider,
      LocaleProvider localeProvider, bool isDark, String? username, String? photoBase64, AppL10n l) {
    final initial = (username?.isNotEmpty == true) ? username![0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      onSelected: (val) async {
        if (val == 'account') {
          showAccountSettings(context);
        } else if (val == 'theme') {
          themeProvider.toggleTheme(!isDark);
        } else if (val == 'lang_fr') {
          localeProvider.setLocale('fr');
        } else if (val == 'lang_en') {
          localeProvider.setLocale('en');
        } else if (val == 'lang_ar') {
          localeProvider.setLocale('ar');
        } else if (val == 'logout') {
          await context.read<AuthProvider>().signOut();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const AppRoot()),
              (route) => false,
            );
          }
        }
      },
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      elevation: 8,
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            UserAvatar(
              photoBase64:     photoBase64,
              initial:         initial,
              radius:          18,
              backgroundColor: const Color(0xFF0047AB).withOpacity(0.7),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('@${username ?? ''}',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(l.t('my_account'),
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 11)),
            ]),
          ]),
        ),

        const PopupMenuDivider(),

        PopupMenuItem(
          value: 'account',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Icon(Icons.manage_accounts_outlined, size: 18,
                color: isDark ? const Color(0xFF7AA6FF) : const Color(0xFF0047AB)),
            const SizedBox(width: 10),
            Text(l.t('account_settings'),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
          ]),
        ),

        PopupMenuItem(
          value: 'theme',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 18,
                color: isDark ? Colors.yellow.shade300 : Colors.indigo.shade500),
            const SizedBox(width: 10),
            Text(isDark ? l.t('light_mode') : l.t('dark_mode'),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
          ]),
        ),

        const PopupMenuDivider(),

        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(l.t('language'),
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
        ),
        _langItem('lang_fr', '🇫🇷', l.t('french'),  localeProvider.languageCode == 'fr', isDark),
        _langItem('lang_en', '🇬🇧', l.t('english'), localeProvider.languageCode == 'en', isDark),
        _langItem('lang_ar', '🇸🇦', l.t('arabic'),  localeProvider.languageCode == 'ar', isDark),

        const PopupMenuDivider(),

        PopupMenuItem(
          value: 'logout',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Icon(Icons.logout_rounded, size: 18,
                color: isDark ? Colors.redAccent.shade100 : Colors.red.shade600),
            const SizedBox(width: 10),
            Text(l.t('logout'),
                style: TextStyle(
                    color: isDark ? Colors.redAccent.shade100 : Colors.red.shade600,
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark
              ? const Color(0xFF0047AB).withOpacity(0.2)
              : const Color(0xFF3B82F6).withOpacity(0.1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          UserAvatar(
            photoBase64:     photoBase64,
            initial:         initial,
            radius:          12,
            backgroundColor: const Color(0xFF0047AB),
            fontSize:        11,
          ),
          const SizedBox(width: 7),
          Text('@${username ?? '...'}',
              style: TextStyle(
                  color: isDark ? const Color(0xFFD1A7FF) : const Color(0xFF4338CA),
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16,
              color: isDark ? Colors.white54 : Colors.black38),
        ]),
      ),
    );
  }

  PopupMenuItem<String> _langItem(
      String value, String flag, String label, bool active, bool isDark) =>
      PopupMenuItem(
        value: value,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: active
                      ? const Color(0xFF7AA6FF)
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal)),
          if (active) ...[
            const Spacer(),
            const Icon(Icons.check, size: 14, color: Color(0xFF7AA6FF)),
          ],
        ]),
      );

  Widget _langFlag(BuildContext context, LocaleProvider localeProvider,
      String flag, String code, bool isDark) {
    final active = localeProvider.languageCode == code;
    return GestureDetector(
      onTap: () => localeProvider.setLocale(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active
              ? (isDark ? const Color(0xFF0047AB).withOpacity(0.5) : const Color(0xFF3B82F6).withOpacity(0.15))
              : Colors.transparent,
          border: Border.all(
              color: active ? const Color(0xFF7AA6FF).withOpacity(0.6) : Colors.transparent),
        ),
        child: Text(flag, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  Widget _authButtons(BuildContext context, bool isDark, AppL10n l) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      TextButton(
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AuthPage())),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(l.t('login_btn'),
            style: TextStyle(
              color: isDark ? const Color(0xFFD1A7FF) : const Color(0xFF4338CA),
              fontWeight: FontWeight.w600, fontSize: 14,
            )),
      ),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF00D4FF), const Color(0xFF6A5AE0)]
                : [const Color(0xFF3B82F6), const Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextButton(
          onPressed: () => Navigator.push(
            context, MaterialPageRoute(
              builder: (_) => const AuthPage(initialSignup: true))),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(l.t('signup_btn'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 14,
              )),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider  = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final authProvider   = context.watch<AuthProvider>();
    final bool isDark    = themeProvider.isDarkMode;
    final bool isAuth    = authProvider.isAuthenticated;
    final username       = authProvider.currentUser?.username;
    final photoBase64    = authProvider.currentUser?.photoBase64;
    final l              = AppL10n.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AnimatedLogo(size: LogoSize.md),
          const Spacer(flex: 2),

          if (isAuth) ...[
            _glassContainer(isDark: isDark, children: [
              _navButton(context: context, text: l.t('chat'),          icon: Icons.chat_bubble_outline_rounded, page: const ChatPage(),          active: _isActive('chat'),          isDark: isDark),
              _navButton(context: context, text: 'Groupes',           icon: Icons.group_rounded,               page: const GroupsPage(),         active: _isActive('groups'),        isDark: isDark),
              _navButton(context: context, text: l.t('hachage'),       icon: Icons.fingerprint_rounded,         page: const HachagePage(),       active: _isActive('hachage'),       isDark: isDark),
              _navButton(context: context, text: l.t('chiffrement'),   icon: Icons.enhanced_encryption_rounded, page: const ChiffrementPage(),   active: _isActive('chiffrement'),   isDark: isDark),
              _navButton(context: context, text: l.t('mdp'),           icon: Icons.password_rounded,            page: const MdpPage(),           active: _isActive('mdp'),           isDark: isDark),
              _navButton(context: context, text: l.t('vpn'),           icon: Icons.vpn_lock_rounded,            page: const VpnPage(),           active: _isActive('vpn'),           isDark: isDark),
            ]),

            const Spacer(flex: 2),

            _glassContainer(isDark: isDark, children: [
              _navButton(context: context, text: l.t('history'),       icon: Icons.history_rounded,   page: const HistoryPage(),       active: _isActive('history'),       isDark: isDark),
              _navButton(context: context, text: l.t('documentation'), icon: Icons.menu_book_rounded, page: const DocumentationPage(), active: _isActive('documentation'), isDark: isDark),
              const SizedBox(width: 6),
              Container(width: 1, height: 20,
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
              const SizedBox(width: 8),
              _settingsButton(context, themeProvider, localeProvider, isDark, username, photoBase64, l),
            ]),
          ] else ...[
            const Spacer(flex: 2),

            _glassContainer(isDark: isDark, children: [
              IconButton(
                onPressed: () => themeProvider.toggleTheme(!isDark),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 18,
                  color: isDark ? Colors.yellow.shade300 : Colors.indigo.shade400,
                ),
                tooltip: isDark ? l.t('light_mode') : l.t('dark_mode'),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              Container(width: 1, height: 18,
                  color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
              const SizedBox(width: 4),
              _langFlag(context, localeProvider, '🇫🇷', 'fr', isDark),
              _langFlag(context, localeProvider, '🇬🇧', 'en', isDark),
              _langFlag(context, localeProvider, '🇸🇦', 'ar', isDark),
            ]),

            const SizedBox(width: 12),
            _authButtons(context, isDark, l),
          ],
        ],
      ),
    );
  }
}
