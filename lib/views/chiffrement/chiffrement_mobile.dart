import 'package:flutter/material.dart';
import 'package:cryptoadv/backend/crypto/cesar.dart';
import 'package:cryptoadv/backend/crypto/vigenere.dart';
import 'package:cryptoadv/components/backround.dart';
import '../../core/localization/app_l10n.dart';
import '../../services/history_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_drawer.dart';

enum CipherType { cesar, vigenereNormal, vigenereAvance, vigenerePermute }

class CipherOption {
  final CipherType type;
  final String labelKey;
  final bool needsKey;
  final bool needsShift;
  final String descriptionKey;
  const CipherOption({required this.type, required this.labelKey, required this.needsKey, required this.needsShift, required this.descriptionKey});
}

const List<CipherOption> cipherOptions = [
  CipherOption(type: CipherType.cesar, labelKey: "cesar_label", needsKey: false, needsShift: true, descriptionKey: "cesar_desc"),
  CipherOption(type: CipherType.vigenereNormal, labelKey: "vigenere_label", needsKey: true, needsShift: false, descriptionKey: "vigenere_desc"),
  CipherOption(type: CipherType.vigenereAvance, labelKey: "vigenere_avance_label", needsKey: true, needsShift: false, descriptionKey: "vigenere_avance_desc"),
  CipherOption(type: CipherType.vigenerePermute, labelKey: "vigenere_permute_label", needsKey: true, needsShift: false, descriptionKey: "vigenere_permute_desc"),
];

class ChiffrementMobile extends StatefulWidget {
  const ChiffrementMobile({super.key});

  @override
  State<ChiffrementMobile> createState() => _ChiffrementMobileState();
}

class _ChiffrementMobileState extends State<ChiffrementMobile> {
  final HistoryService _historyService = HistoryService();
  final TextEditingController texteController = TextEditingController();
  final TextEditingController cleController = TextEditingController();
  final TextEditingController decalageController = TextEditingController(text: "3");
  CipherType selectedCipher = CipherType.cesar;
  String resultat = "";

  CipherOption get currentCipher => cipherOptions.firstWhere((e) => e.type == selectedCipher);

  Future<void> _saveHistory({required String inputPreview, required String result}) async {
    final user = await AuthService().currentUser;
    if (user == null) return;
    String algoLabel = selectedCipher.toString().split('.').last;
    await _historyService.addHistoryItem(userId: user.id, type: 'cipher', algorithm: algoLabel, inputPreview: inputPreview.length > 50 ? '${inputPreview.substring(0, 50)}...' : inputPreview, result: result, isEncrypted: true);
  }

  void lancerChiffrement(bool encrypt) async {
    try {
      String res = "";
      String txt = texteController.text;
      String cle = cleController.text;
      int shift = int.tryParse(decalageController.text) ?? 0;
      switch (selectedCipher) {
        case CipherType.cesar: res = encrypt ? chiffrerCesar(txt, shift) : dechiffrerCesar(txt, shift); break;
        case CipherType.vigenereNormal: res = encrypt ? chiffrerVigenereNormal(txt, cle) : dechiffrerVigenereNormal(txt, cle); break;
        case CipherType.vigenereAvance: res = encrypt ? chiffrerVigenereAvance(txt, cle) : dechiffrerVigenereAvance(txt, cle); break;
        case CipherType.vigenerePermute: res = encrypt ? chiffrerVigenerePermute(txt, cle) : dechiffrerVigenerePermute(txt, cle); break;
      }
      setState(() => resultat = res);
      await _saveHistory(inputPreview: txt, result: res);
    } catch (e) {
      setState(() => resultat = "Erreur : $e");
    }
  }

  @override
  void dispose() {
    texteController.dispose(); cleController.dispose(); decalageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);

    return Scaffold(
      drawer: const AppDrawer(currentPage: 'chiffrement'),
      appBar: AppBar(title: Text(l.t('chiffrement')), backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black)),
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
                        _label(l.t('algo_label'), isDark),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<CipherType>(
                          value: selectedCipher,
                          dropdownColor: isDark ? const Color(0xFF0F1B38) : Colors.white,
                          decoration: _fieldDeco(l.t('cipher_choice_hint'), isDark),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                          items: cipherOptions.map((o) => DropdownMenuItem(value: o.type, child: Text(l.t(o.labelKey)))).toList(),
                          onChanged: (v) => setState(() { selectedCipher = v!; resultat = ""; }),
                        ),
                        const SizedBox(height: 16),
                        _label(l.t('text_label'), isDark),
                        const SizedBox(height: 10),
                        TextField(controller: texteController, maxLines: 4, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14), decoration: _fieldDeco(l.t('text_hint_mobile'), isDark)),
                        const SizedBox(height: 16),
                        if (currentCipher.needsKey) ...[
                          _label(l.t('key_label'), isDark),
                          const SizedBox(height: 10),
                          TextField(controller: cleController, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14), decoration: _fieldDeco(l.t('key_hint'), isDark)),
                          const SizedBox(height: 16),
                        ],
                        if (currentCipher.needsShift) ...[
                          _label(l.t('shift_label'), isDark),
                          const SizedBox(height: 10),
                          TextField(controller: decalageController, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14), decoration: _fieldDeco(l.t('shift_hint_mobile'), isDark)),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: [
                            Expanded(child: _actionButton(l.t('encrypt_btn'), isDark, true, () => lancerChiffrement(true))),
                            const SizedBox(width: 10),
                            Expanded(child: _actionButton(l.t('decrypt_btn'), isDark, false, () => lancerChiffrement(false))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (resultat.isNotEmpty)
                    _glassCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(l.t('result_label'), isDark),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: (isDark ? Colors.white : Colors.black).withOpacity(0.06)),
                            child: SelectableText(resultat, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                          ),
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

  InputDecoration _fieldDeco(String hint, bool isDark) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), fontSize: 13), filled: true, fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05), contentPadding: const EdgeInsets.all(14),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF7AA6FF) : const Color(0xFF3B82F6))),
  );

  Widget _label(String text, bool isDark) => Text(text, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14));

  Widget _actionButton(String text, bool isDark, bool isPrimary, VoidCallback onTap) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(backgroundColor: isPrimary ? (isDark ? const Color(0xFF0047AB) : const Color(0xFF2563EB)) : (isDark ? Colors.white10 : Colors.white), foregroundColor: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black87), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
  );
}
