import 'package:flutter/material.dart';
import 'package:cryptoadv/backend/crypto/cesar.dart';
import 'package:cryptoadv/backend/crypto/vigenere.dart';
import 'package:cryptoadv/components/backround.dart';
import '../../services/history_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_navbar.dart';

enum CipherType { cesar, vigenereNormal, vigenereAvance, vigenerePermute }

class CipherOption {
  final CipherType type;
  final String label;
  final bool needsKey;
  final bool needsShift;
  final String description;
  const CipherOption({required this.type, required this.label, required this.needsKey, required this.needsShift, required this.description});
}

const List<CipherOption> cipherOptions = [
  CipherOption(type: CipherType.cesar, label: "César", needsKey: false, needsShift: true, description: "Décalage simple des lettres."),
  CipherOption(type: CipherType.vigenereNormal, label: "Vigenère", needsKey: true, needsShift: false, description: "Chiffre uniquement les lettres."),
  CipherOption(type: CipherType.vigenereAvance, label: "Vigenère avancé", needsKey: true, needsShift: false, description: "Chiffre aussi les espaces et caractères spéciaux."),
  CipherOption(type: CipherType.vigenerePermute, label: "Vigenère permuté", needsKey: true, needsShift: false, description: "Permutation puis Vigenère avancé."),
];

class ChiffrementDesktop extends StatefulWidget {
  const ChiffrementDesktop({super.key});

  @override
  State<ChiffrementDesktop> createState() => _ChiffrementDesktopState();
}

class _ChiffrementDesktopState extends State<ChiffrementDesktop> {
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
    await _historyService.addHistoryItem(userId: user.id, type: 'cipher', algorithm: algoLabel, inputPreview: inputPreview.length > 80 ? '${inputPreview.substring(0, 80)}...' : inputPreview, result: result, isEncrypted: true);
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
    return Scaffold(
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: Column(
              children: [
                const AppNavbar(currentPage: 'chiffrement'),
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
                              Text("Chiffrement de texte", style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text("Choisis un algorithme, saisis ton texte puis chiffre ou déchiffre.", style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.72), fontSize: 15)),
                              const SizedBox(height: 24),
                              _label("Algorithme", isDark),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<CipherType>(
                                value: selectedCipher,
                                dropdownColor: isDark ? const Color(0xFF0F1B38) : Colors.white,
                                decoration: _fieldDeco("Choisir un chiffrement", isDark),
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                items: cipherOptions.map((o) => DropdownMenuItem(value: o.type, child: Text(o.label))).toList(),
                                onChanged: (v) => setState(() { selectedCipher = v!; resultat = ""; }),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity, padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: (isDark ? Colors.white : Colors.black).withOpacity(0.06), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.06))),
                                child: Text(currentCipher.description, style: TextStyle(color: (isDark ? Colors.white : const Color(0xFF334155)).withOpacity(0.78), fontSize: 14)),
                              ),
                              const SizedBox(height: 24),
                              _label("Texte", isDark),
                              const SizedBox(height: 12),
                              TextField(controller: texteController, maxLines: 6, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _fieldDeco("Entre ton texte ici...", isDark)),
                              const SizedBox(height: 20),
                              if (currentCipher.needsKey) ...[
                                _label("Clé", isDark),
                                const SizedBox(height: 12),
                                TextField(controller: cleController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _fieldDeco("Entre la clé...", isDark)),
                                const SizedBox(height: 20),
                              ],
                              if (currentCipher.needsShift) ...[
                                _label("Décalage", isDark),
                                const SizedBox(height: 12),
                                TextField(controller: decalageController, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _fieldDeco("Entre le décalage...", isDark)),
                                const SizedBox(height: 20),
                              ],
                              Row(
                                children: [
                                  Expanded(child: _actionButton("Chiffrer", isDark, true, () => lancerChiffrement(true))),
                                  const SizedBox(width: 14),
                                  Expanded(child: _actionButton("Déchiffrer", isDark, false, () => lancerChiffrement(false))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _glassCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Résultat", style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 22, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 18),
                              Container(
                                width: double.infinity, constraints: const BoxConstraints(minHeight: 140), padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: (isDark ? Colors.white : Colors.black).withOpacity(0.06), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08))),
                                child: SelectableText(resultat.isEmpty ? "Le résultat s'affichera ici..." : resultat, style: TextStyle(color: resultat.isEmpty ? (isDark ? Colors.white : Colors.black).withOpacity(0.45) : (isDark ? Colors.white : Colors.black87), fontSize: 16, height: 1.5)),
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

  InputDecoration _fieldDeco(String hint, bool isDark) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.45)), filled: true, fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.07), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: isDark ? const Color(0xFF7AA6FF) : const Color(0xFF3B82F6), width: 1.2)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
  );

  Widget _label(String text, bool isDark) => Text(text, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 16));

  Widget _actionButton(String text, bool isDark, bool isPrimary, VoidCallback onTap) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(backgroundColor: isPrimary ? (isDark ? const Color(0xFF0047AB) : const Color(0xFF2563EB)) : (isDark ? Colors.white.withOpacity(0.1) : Colors.white), foregroundColor: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black87), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: !isPrimary ? BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)) : BorderSide.none)),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
  );
}
