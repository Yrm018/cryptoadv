import 'package:cryptoadv/backend/crypto/mdp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/backround.dart';
import '../../core/localization/app_l10n.dart';
import '../../services/history_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_drawer.dart';

class MdpMobile extends StatefulWidget {
  const MdpMobile({super.key});

  @override
  State<MdpMobile> createState() => _MdpMobileState();
}

class _MdpMobileState extends State<MdpMobile> {
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
    final user = await AuthService().currentUser;
    if (user == null) return;
    await _historyService.addHistoryItem(userId: user.id, type: 'password', algorithm: 'Generator', inputPreview: 'Mot de passe généré', result: password, isEncrypted: false);
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
    final l = AppL10n.of(context);

    return Scaffold(
      drawer: const AppDrawer(currentPage: 'mdp'),
      appBar: AppBar(title: Text(l.t('mdp')), backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black)),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTesterCard(isDark, l),
                  const SizedBox(height: 20),
                  _buildGeneratorCard(isDark, l),
                  const SizedBox(height: 20),
                  _buildConseilsCard(isDark, l),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTesterCard(bool isDark, AppL10n l) {
    return _glassCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.security, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), size: 30), const SizedBox(width: 10), Text(l.t('tester_card_title_mobile'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)))]),
          const SizedBox(height: 16),
          TextField(controller: controller, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14), decoration: _inputDeco(l.t('enter_mdp_hint_mobile'), isDark)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l.t('strength_label_mobile'), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)), Text(analysis.strengthLabel, style: TextStyle(color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), fontSize: 14, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: analysis.progress, minHeight: 8, backgroundColor: isDark ? Colors.white10 : Colors.black12, valueColor: AlwaysStoppedAnimation(isDark ? const Color(0xFF00D4FF) : const Color(0xFF3B82F6)))),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _checkLine("MAJ", analysis.hasUppercase, isDark),
            _checkLine("min", analysis.hasLowercase, isDark),
            _checkLine("123", analysis.hasNumbers, isDark),
            _checkLine("#@!", analysis.hasSymbols, isDark),
            _checkLine("12+", analysis.hasMinLength, isDark),
          ]),
        ],
      ),
    );
  }

  Widget _buildGeneratorCard(bool isDark, AppL10n l) {
    return _glassCard(
      isDark: isDark,
      child: Column(
        children: [
          Row(children: [Icon(Icons.security_update, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), size: 30), const SizedBox(width: 10), Text(l.t('gen_card_title_mobile'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)))]),
          const SizedBox(height: 16),
          TextField(readOnly: true, controller: controller2, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13), decoration: _inputDeco(l.t('gen_hint_mobile'), isDark).copyWith(suffixIcon: IconButton(icon: Icon(Icons.copy, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), size: 20), onPressed: () { Clipboard.setData(ClipboardData(text: controller2.text)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('copied_mobile')), duration: const Duration(seconds: 2))); }))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${l.t('length_label_mobile')}${longueur.toInt()}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)), Text("", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold))]),
          Slider(value: longueur, min: 8, max: 64, divisions: 56, activeColor: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), onChanged: (v) => setState(() => longueur = v)),
          _mdpCheckbox(l.t('upper_case_mobile'), majuscules, (v) => setState(() => majuscules = v!), isDark),
          _mdpCheckbox(l.t('lower_case_mobile'), minuscules, (v) => setState(() => minuscules = v!), isDark),
          _mdpCheckbox(l.t('digits_label_mobile'), chiffres, (v) => setState(() => chiffres = v!), isDark),
          _mdpCheckbox(l.t('special_chars_mobile'), caracteresSpeciaux, (v) => setState(() => caracteresSpeciaux = v!), isDark),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final gen = generatePassword(majuscules, chiffres, caracteresSpeciaux, minuscules, longueur); setState(() => controller2.text = gen); await _saveHistory(gen); }, style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l.t('generate_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        ],
      ),
    );
  }

  Widget _buildConseilsCard(bool isDark, AppL10n l) {
    return _glassCard(
      isDark: isDark,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.t('tips_title_mobile'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _conseilItem(l.t('tip_len_mobile'), l.t('tip_len_desc_mobile'), isDark),
        _conseilItem(l.t('tip_mix_mobile'), l.t('tip_mix_desc_mobile'), isDark),
        _conseilItem(l.t('tip_unique_mobile'), l.t('tip_unique_desc_mobile'), isDark),
      ]),
    );
  }

  Widget _glassCard({required Widget child, required bool isDark}) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: isDark ? const Color(0xFF1A1F71).withOpacity(0.2) : Colors.white.withOpacity(0.8), border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))), child: child);
  InputDecoration _inputDeco(String hint, bool isDark) => InputDecoration(hintText: hint, hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), fontSize: 13), filled: true, fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));
  Widget _checkLine(String text, bool valid, bool isDark) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: (valid ? Colors.green : Colors.red).withOpacity(0.1)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(valid ? Icons.check : Icons.close, color: valid ? Colors.green : Colors.red, size: 14), const SizedBox(width: 4), Text(text, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11))]));
  Widget _conseilItem(String title, String desc, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(Icons.check_circle_outline, color: Colors.green, size: 16), const SizedBox(width: 8), Expanded(child: Text("$title: $desc", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)))]));
  Widget _mdpCheckbox(String text, bool value, ValueChanged<bool?> onChanged, bool isDark) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(text, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)), Checkbox(value: value, activeColor: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), onChanged: onChanged)]);
}
