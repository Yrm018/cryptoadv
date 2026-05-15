import 'package:flutter/material.dart';
import '../../components/backround.dart';
import '../../core/localization/app_l10n.dart';
import '../../widgets/common/app_drawer.dart';

class HistoryMobile extends StatelessWidget {
  const HistoryMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);

    return Scaffold(
      drawer: const AppDrawer(currentPage: 'history'),
      appBar: AppBar(
        title: Text(l.t('history')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _glassCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.t('history_title_mobile'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _historyItem(icon: Icons.fingerprint, title: l.t('hachage'), subtitle: "SHA-256", value: "2cf24dba...", isDark: isDark),
                        _historyItem(icon: Icons.lock_outline, title: l.t('chiffrement'), subtitle: "César (3)", value: "KHOOR...", isDark: isDark),
                        _historyItem(icon: Icons.password, title: l.t('mdp'), subtitle: l.t('password'), value: "A7!kP9...", isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child, required bool isDark}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: isDark ? const Color(0xFF0047AB).withOpacity(0.2) : Colors.white.withOpacity(0.8), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
    child: child,
  );

  Widget _historyItem({required IconData icon, required String title, required String subtitle, required String value, required bool isDark}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: (isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB)).withOpacity(0.1)), child: Icon(icon, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.bold)), Text("$subtitle: $value", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.6), fontSize: 12))])),
      ],
    ),
  );
}
