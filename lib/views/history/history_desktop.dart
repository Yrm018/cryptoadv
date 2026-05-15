import 'package:cryptoadv/widgets/common/app_navbar.dart';
import 'package:flutter/material.dart';
import '../../components/backround.dart';
import '../../core/localization/app_l10n.dart';

class HistoryDesktop extends StatelessWidget {
  const HistoryDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: Column(
              children: [
                const AppNavbar(currentPage: 'history'),
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
                              Text(l.t('history_title'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text(l.t('history_subtitle'), style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.72), fontSize: 15)),
                              const SizedBox(height: 24),
                              _historyItem(icon: Icons.fingerprint, title: l.t('history_hachage'), subtitle: l.t('history_hachage_sub'), value: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824", isDark: isDark),
                              _historyItem(icon: Icons.lock_outline, title: l.t('history_cipher'), subtitle: l.t('history_cipher_sub'), value: "KHOOR ZRUOG", isDark: isDark),
                              _historyItem(icon: Icons.password, title: l.t('history_mdp'), subtitle: l.t('history_mdp_sub'), value: "A7!kP9@Lm2#Q", isDark: isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _glassCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.t('history_coming_soon'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 16),
                              _bullet(l.t('history_b1'), isDark),
                              _bullet(l.t('history_b2'), isDark),
                              _bullet(l.t('history_b3'), isDark),
                              _bullet(l.t('history_b4'), isDark),
                            ],
                          ),
                        ),
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
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), color: isDark ? const Color(0xFF0047AB).withOpacity(0.22) : Colors.white.withOpacity(0.8), boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.30) : Colors.black.withOpacity(0.05), offset: const Offset(0, 14), blurRadius: 30, spreadRadius: -8)], border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.10))),
    child: child,
  );

  Widget _historyItem({required IconData icon, required String title, required String subtitle, required String value, required bool isDark}) => Container(
    width: double.infinity, margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: (isDark ? Colors.white : Colors.black).withOpacity(0.06), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: (isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB)).withOpacity(0.18)), child: Icon(icon, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), size: 26)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(subtitle, style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.70), fontSize: 14)), const SizedBox(height: 10), SelectableText(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, height: 1.4))])),
    ]),
  );

  Widget _bullet(String text, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text("• $text", style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 15)));
}
