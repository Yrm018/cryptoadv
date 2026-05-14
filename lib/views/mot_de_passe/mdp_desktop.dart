import 'package:cryptoadv/backend/crypto/mdp.dart';
import 'package:cryptoadv/widgets/common/app_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/backround.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/history_service.dart';

class MdpDesktop extends StatefulWidget {
  const MdpDesktop({super.key});

  @override
  State<MdpDesktop> createState() => _MdpDesktopState();
}

class _MdpDesktopState extends State<MdpDesktop> {
  final HistoryService _historyService = HistoryService();
  TextEditingController controller = TextEditingController();
  TextEditingController controller2 = TextEditingController();
  double longueur = 12;
  bool majuscules = false;
  bool minuscules = false;
  bool chiffres = false;
  bool caracteresSpeciaux = false;
  PasswordAnalysis analysis = analyzePassword("");

  Future<void> _saveHistory(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _historyService.addHistoryItem(userId: user.uid, type: 'password', algorithm: 'Generator', inputPreview: 'Mot de passe généré', result: password, isEncrypted: false);
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      setState(() { analysis = analyzePassword(controller.text); });
    });
  }

  @override
  void dispose() {
    controller.dispose(); controller2.dispose();
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
                const AppNavbar(currentPage: 'mdp'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
                    child: Column(
                      children: [
                        Center(child: Text("Gestionnaire de mot de passe", textAlign: TextAlign.center, style: TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)))),
                        const SizedBox(height: 50),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildTesterCard(isDark),
                            _buildGeneratorCard(isDark),
                          ],
                        ),
                        const SizedBox(height: 30),
                        _buildConseilsCard(isDark),
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

  Widget _buildTesterCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: isDark ? const Color(0xFF1A1F71).withOpacity(0.7) : Colors.white.withOpacity(0.8), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
      width: 500, padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.security, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), size: 40), const SizedBox(width: 10), Text('Tester un mot de passe', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)))]),
          const SizedBox(height: 30),
          _label("Entrez votre mot de passe", isDark),
          const SizedBox(height: 14),
          TextField(controller: controller, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600), decoration: _inputDeco("Entrez votre mot de passe", isDark)),
          const SizedBox(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Force du mot de passe", style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600)), Row(children: [Icon(Icons.check_circle_outline, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB)), const SizedBox(width: 8), Text(analysis.strengthLabel, style: TextStyle(color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), fontSize: 16, fontWeight: FontWeight.bold))])]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(30), child: LinearProgressIndicator(value: analysis.progress, minHeight: 14, backgroundColor: isDark ? const Color(0xFF4D1F85) : Colors.black12, valueColor: AlwaysStoppedAnimation(isDark ? const Color(0xFF00D4FF) : const Color(0xFF3B82F6)))),
          const SizedBox(height: 28),
          Row(children: [
            _statBox("${analysis.length}", "Caractères", isDark),
            const SizedBox(width: 16),
            _statBox("${analysis.score}/8", "Score", isDark),
          ]),
          const SizedBox(height: 28),
          _checkLine("Contient des majuscules", analysis.hasUppercase, isDark),
          const SizedBox(height: 10),
          _checkLine("Contient des minuscules", analysis.hasLowercase, isDark),
          const SizedBox(height: 10),
          _checkLine("Contient des chiffres", analysis.hasNumbers, isDark),
          const SizedBox(height: 10),
          _checkLine("Contient des symboles", analysis.hasSymbols, isDark),
          const SizedBox(height: 10),
          _checkLine("Au moins 12 caractères", analysis.hasMinLength, isDark),
        ],
      ),
    );
  }

  Widget _buildGeneratorCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: isDark ? const Color(0xFF720183).withOpacity(0.7) : Colors.white.withOpacity(0.8), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
      width: 500, padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Row(children: [Icon(Icons.security_update, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), size: 40), const SizedBox(width: 10), Text('Générer un mot de passe', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)))]),
          const SizedBox(height: 30),
          TextField(readOnly: true, controller: controller2, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _inputDeco("Générer un mot de passe...", isDark).copyWith(suffixIcon: IconButton(icon: Icon(Icons.copy, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB)), onPressed: () { Clipboard.setData(ClipboardData(text: controller2.text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mot de passe copié !"), duration: Duration(seconds: 2))); }))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Longueur", style: TextStyle(color: isDark ? const Color(0xFF7FE7FF) : const Color(0xFF1E40AF), fontSize: 19, fontWeight: FontWeight.bold)), Text(longueur.toInt().toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 19, fontWeight: FontWeight.bold))]),
          Slider(value: longueur, min: 8, max: 64, divisions: 56, activeColor: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), onChanged: (v) => setState(() => longueur = v)),
          _mdpCheckbox("Majuscules (A-Z)", majuscules, (v) => setState(() => majuscules = v!), isDark),
          const SizedBox(height: 12),
          _mdpCheckbox("Minuscules (a-z)", minuscules, (v) => setState(() => minuscules = v!), isDark),
          const SizedBox(height: 12),
          _mdpCheckbox("Chiffres (0-9)", chiffres, (v) => setState(() => chiffres = v!), isDark),
          const SizedBox(height: 12),
          _mdpCheckbox("Caractères spéciaux", caracteresSpeciaux, (v) => setState(() => caracteresSpeciaux = v!), isDark),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () async { final gen = generatePassword(majuscules, chiffres, caracteresSpeciaux, minuscules, longueur); setState(() => controller2.text = gen); await _saveHistory(gen); }, style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text("Générer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        ],
      ),
    );
  }

  Widget _buildConseilsCard(bool isDark) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), color: (isDark ? const Color(0xFF3E3AA8) : Colors.white).withOpacity(isDark ? 0.45 : 0.8), border: Border.all(color: (isDark ? const Color(0xFF00D4FF) : const Color(0xFF3B82F6)).withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.check_circle_outline, color: isDark ? const Color(0xFF00FF9D) : const Color(0xFF059669), size: 34), const SizedBox(width: 14), Text("Conseils pour un mot de passe sécurisé", style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 30),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _conseilItem("Longueur minimale", "Utilisez au moins 12 caractères, idéalement 16+", isDark),
          const SizedBox(width: 40),
          _conseilItem("Mélange de caractères", "Combinez majuscules, minuscules, chiffres et symboles", isDark),
        ]),
        const SizedBox(height: 26),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _conseilItem("Évitez les mots communs", "Ne pas utiliser de mots du dictionnaire", isDark),
          const SizedBox(width: 40),
          _conseilItem("Mots de passe uniques", "Utilisez un mot de passe différent pour chaque compte", isDark),
        ]),
      ]),
    );
  }

  Widget _statBox(String val, String label, bool isDark) => Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: (isDark ? const Color(0xFF6A2FB7) : const Color(0xFFEFF6FF)).withOpacity(0.45), borderRadius: BorderRadius.circular(20), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(val, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 16))])));
  Widget _label(String text, bool isDark) => Text(text, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 18, fontWeight: FontWeight.w600));
  InputDecoration _inputDeco(String hint, bool isDark) => InputDecoration(hintText: hint, hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)), filled: true, fillColor: (isDark ? const Color(0xFF5A2DA8) : const Color(0xFFDBEAFE)).withOpacity(0.35), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: isDark ? const Color(0xFF8D63FF) : const Color(0xFF3B82F6))), contentPadding: const EdgeInsets.all(20));
  Widget _checkLine(String text, bool valid, bool isDark) => Row(children: [Icon(valid ? Icons.check : Icons.close, color: valid ? (isDark ? const Color(0xFF00FF9D) : const Color(0xFF059669)) : Colors.redAccent, size: 22), const SizedBox(width: 10), Text(text, style: TextStyle(color: valid ? (isDark ? const Color(0xFF00FF9D) : const Color(0xFF059669)) : (isDark ? Colors.white70 : Colors.black54), fontSize: 16))]);
  Widget _conseilItem(String title, String desc, bool isDark) => Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.check, color: isDark ? const Color(0xFF00FF9D) : const Color(0xFF059669), size: 24)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: isDark ? const Color(0xFFA8FFE0) : const Color(0xFF064E3B), fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(desc, style: TextStyle(color: isDark ? const Color(0xFFB9D7FF) : const Color(0xFF1E293B), fontSize: 16, height: 1.4))]))]));
  Widget _mdpCheckbox(String text, bool value, ValueChanged<bool?> onChanged, bool isDark) => Container(width: 350, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7), decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: (isDark ? const Color(0xFF4F5BD5) : const Color(0xFF3B82F6)).withOpacity(0.15), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(text, style: TextStyle(color: isDark ? const Color(0xFF7FE7FF) : const Color(0xFF1E40AF), fontSize: 18, fontWeight: FontWeight.bold)), Checkbox(value: value, activeColor: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), checkColor: isDark ? Colors.black : Colors.white, onChanged: onChanged)]));
}
