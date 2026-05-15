import 'package:cryptoadv/widgets/common/app_navbar.dart';
import 'package:flutter/material.dart';
import 'package:cryptoadv/components/backround.dart';
import '../../core/localization/app_l10n.dart';

class DocumentationDesktop extends StatelessWidget {
  const DocumentationDesktop({super.key});

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
                              Text(l.t('doc_title'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 30, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              Text(l.t('doc_intro'),
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
                              _sectionTitle(l.t('doc_hachage_title'), isDark),
                              const SizedBox(height: 14),
                              _sectionText(l.t('doc_hachage_desc'), isDark),
                              const SizedBox(height: 16),
                              _bullet(l.t('doc_hachage_b1'), isDark),
                              _bullet(l.t('doc_hachage_b2'), isDark),
                              _bullet(l.t('doc_hachage_b3'), isDark),
                              _bullet(l.t('doc_hachage_b4'), isDark),
                              const SizedBox(height: 16),
                              _sectionText(l.t('doc_hachage_algos'), isDark),
                              _bullet("MD5", isDark),
                              _bullet("SHA-1", isDark),
                              _bullet("SHA-256", isDark),
                              _bullet("SHA-512", isDark),
                              const SizedBox(height: 16),
                              _exampleBox(l.t('doc_hachage_example'), isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _glassCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle(l.t('doc_cipher_title'), isDark),
                              const SizedBox(height: 14),
                              _sectionText(l.t('doc_cipher_desc'), isDark),
                              const SizedBox(height: 16),
                              _sectionText(l.t('doc_cipher_algos'), isDark),
                              _bullet(l.t('cesar_label'), isDark),
                              _bullet(l.t('vigenere_label'), isDark),
                              const SizedBox(height: 16),
                              Text(l.t('cesar_label'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              _sectionText(l.t('doc_cesar_desc'), isDark),
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
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), color: isDark ? const Color(0xFF0047AB).withOpacity(0.22) : Colors.white.withOpacity(0.8), boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.30) : Colors.black.withOpacity(0.05), offset: const Offset(0, 14), blurRadius: 30, spreadRadius: -8)], border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.10))),
    child: child,
  );

  Widget _sectionTitle(String title, bool isDark) => Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.w700));
  Widget _sectionText(String text, bool isDark) => Text(text, style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.78), fontSize: 15, height: 1.6));
  Widget _bullet(String text, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text("• $text", style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.78), fontSize: 15)));
  Widget _exampleBox(String text, bool isDark) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: (isDark ? Colors.white : Colors.black).withOpacity(0.06), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08))), child: SelectableText(text, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, height: 1.5)));
}
