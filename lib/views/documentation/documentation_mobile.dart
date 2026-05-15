import 'package:flutter/material.dart';
import '../../components/backround.dart';
import '../../core/localization/app_l10n.dart';
import '../../widgets/common/app_drawer.dart';

class DocumentationMobile extends StatelessWidget {
  const DocumentationMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);

    return Scaffold(
      drawer: const AppDrawer(currentPage: 'documentation'),
      appBar: AppBar(
        title: Text(l.t('documentation')),
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
                        Text(l.t('doc_title'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(l.t('doc_intro_mobile'),
                            style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.78), fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _glassCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(l.t('doc_hachage_title'), isDark),
                        const SizedBox(height: 10),
                        _sectionText(l.t('doc_hachage_desc'), isDark),
                        const SizedBox(height: 12),
                        _bullet(l.t('doc_hachage_algos_mobile'), isDark),
                        _bullet(l.t('doc_hachage_integrity_mobile'), isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _glassCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(l.t('doc_cipher_title'), isDark),
                        const SizedBox(height: 10),
                        _sectionText(l.t('doc_cipher_desc'), isDark),
                        const SizedBox(height: 12),
                        _bullet(l.t('doc_cesar_mobile'), isDark),
                        _bullet(l.t('doc_vigenere_mobile'), isDark),
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
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: isDark ? const Color(0xFF0047AB).withOpacity(0.2) : Colors.white.withOpacity(0.8), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
    child: child,
  );

  Widget _sectionTitle(String title, bool isDark) => Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold));
  Widget _sectionText(String text, bool isDark) => Text(text, style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.78), fontSize: 13));
  Widget _bullet(String text, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Icon(Icons.circle, size: 6, color: isDark ? Colors.white70 : Colors.black54), const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 13)))]));
}
