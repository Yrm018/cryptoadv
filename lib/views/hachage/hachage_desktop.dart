import 'package:cryptoadv/widgets/common/app_navbar.dart';
import '../../services/history_service.dart';
import '../../services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/backround.dart';
import 'package:cryptoadv/backend/crypto/hachage.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/localization/app_l10n.dart';

class HachageDesktop extends StatefulWidget {
  const HachageDesktop({super.key});

  @override
  State<HachageDesktop> createState() => _HachageDesktopState();
}

class _HachageDesktopState extends State<HachageDesktop> {
  final TextEditingController messageController = TextEditingController();
  final TextEditingController resultController = TextEditingController();

  String selectedAlgo = "sha256";
  String fileHashResult = "";
  String fileName = "";
  final HistoryService _historyService = HistoryService();

  Future<void> _saveHistory({
    required String inputPreview,
    required String result,
  }) async {
    final user = await AuthService().currentUser;
    if (user == null) return;

    await _historyService.addHistoryItem(
      userId: user.id,
      type: 'hash',
      algorithm: selectedAlgo.toUpperCase(),
      inputPreview: inputPreview.length > 80
          ? '${inputPreview.substring(0, 80)}...'
          : inputPreview,
      result: result,
      isEncrypted: false,
    );
  }

  Future<void> _pickAndHashFile(AppL10n l) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('err_read_file'))),
      );
      return;
    }

    final resultHash = hashBytes(bytes, algorithm: selectedAlgo);

    setState(() {
      fileName = file.name;
      fileHashResult = resultHash;
    });

    await _saveHistory(
      inputPreview: 'Fichier: ${file.name}',
      result: resultHash,
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppL10n.of(context);
    if (fileName.isEmpty) fileName = l.t('no_file_selected');

    return Scaffold(
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: Column(
              children: [
                const AppNavbar(currentPage: 'hachage'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 1100,
                            padding: const EdgeInsets.all(35),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: isDark
                                  ? const Color(0xFF1A1F71).withOpacity(0.70)
                                  : Colors.white.withOpacity(0.8),
                              border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                              boxShadow: isDark ? [] : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.t('hachage_title'),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l.t('hachage_subtitle'),
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _hashCard(
                                        isDark: isDark,
                                        title: l.t('hash_message_title'),
                                        icon: Icons.text_fields,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _label(l.t('message_label'), isDark),
                                            const SizedBox(height: 10),
                                            TextField(
                                              controller: messageController,
                                              maxLines: 5,
                                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                              decoration: _inputDeco(l.t('message_hint'), isDark),
                                            ),
                                            const SizedBox(height: 20),
                                            _label(l.t('algo_label'), isDark),
                                            const SizedBox(height: 10),
                                            _algoDropdown(isDark),
                                            const SizedBox(height: 20),
                                            _actionButton(l.t('hash_message_btn'), isDark, () async {
                                              final result = hashMessage(messageController.text, algorithm: selectedAlgo);
                                              setState(() => resultController.text = result);
                                              await _saveHistory(inputPreview: messageController.text, result: result);
                                            }),
                                            const SizedBox(height: 25),
                                            _label(l.t('result_label'), isDark),
                                            const SizedBox(height: 10),
                                            _resultField(resultController, isDark, l),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 25),
                                    Expanded(
                                      child: _hashCard(
                                        isDark: isDark,
                                        title: l.t('hash_file_title'),
                                        icon: Icons.insert_drive_file_outlined,
                                        color: (isDark ? const Color(0xFF0047AB) : const Color(0xFFEFF6FF)).withOpacity(0.35),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(15),
                                                color: (isDark ? const Color(0xFF1A1F71) : const Color(0xFFDBEAFE)).withOpacity(0.35),
                                                border: Border.all(color: (isDark ? Colors.white12 : Colors.black12)),
                                              ),
                                              child: Text(fileName, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 16)),
                                            ),
                                            const SizedBox(height: 20),
                                            _actionButton(l.t('choose_file_btn'), isDark, () => _pickAndHashFile(l)),
                                            const SizedBox(height: 25),
                                            _label(l.t('file_hash_label'), isDark),
                                            const SizedBox(height: 10),
                                            Container(
                                              width: double.infinity,
                                              constraints: const BoxConstraints(minHeight: 130),
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(15),
                                                color: (isDark ? const Color(0xFF1A1F71) : const Color(0xFFDBEAFE)).withOpacity(0.35),
                                                border: Border.all(color: (isDark ? Colors.white12 : Colors.black12)),
                                              ),
                                              child: Text(
                                                fileHashResult.isEmpty ? l.t('file_hash_hint') : fileHashResult,
                                                style: TextStyle(
                                                  color: fileHashResult.isEmpty ? (isDark ? Colors.white54 : Colors.black45) : (isDark ? Colors.white : Colors.black87),
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _hashCard({required bool isDark, required String title, required IconData icon, required Widget child, Color? color}) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color ?? (isDark ? const Color(0xFF720183) : const Color(0xFFF1F5F9)).withOpacity(0.45),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), size: 30),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 25),
          child,
        ],
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Text(text, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 16, fontWeight: FontWeight.w600));
  }

  InputDecoration _inputDeco(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
      filled: true,
      fillColor: (isDark ? const Color(0xFF1A1F71) : const Color(0xFFDBEAFE)).withOpacity(0.35),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: const EdgeInsets.all(18),
    );
  }

  Widget _algoDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1A1F71) : const Color(0xFFF8FAFC)).withOpacity(0.35),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: (isDark ? Colors.white12 : Colors.black12)),
      ),
      child: DropdownButton<String>(
        value: selectedAlgo,
        isExpanded: true,
        dropdownColor: isDark ? const Color(0xFF2A1E7A) : Colors.white,
        underline: const SizedBox(),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
        items: const [
          DropdownMenuItem(value: "md5", child: Text("MD5")),
          DropdownMenuItem(value: "sha1", child: Text("SHA-1")),
          DropdownMenuItem(value: "sha224", child: Text("SHA-224")),
          DropdownMenuItem(value: "sha256", child: Text("SHA-256")),
          DropdownMenuItem(value: "sha384", child: Text("SHA-384")),
          DropdownMenuItem(value: "sha512", child: Text("SHA-512")),
        ],
        onChanged: (value) => setState(() => selectedAlgo = value!),
      ),
    );
  }

  Widget _actionButton(String text, bool isDark, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: ButtonStyle(
        padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 35, vertical: 18)),
        backgroundColor: MaterialStateProperty.all(isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB)),
        shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
    );
  }

  Widget _resultField(TextEditingController ctrl, bool isDark, AppL10n l) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      maxLines: 4,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: _inputDeco(l.t('result_hint'), isDark).copyWith(
        suffixIcon: IconButton(
          icon: Icon(Icons.copy, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB)),
          onPressed: () {
            if (ctrl.text.isEmpty) return;
            Clipboard.setData(ClipboardData(text: ctrl.text));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('hash_copied')), duration: const Duration(seconds: 2)));
          },
        ),
      ),
    );
  }
}
