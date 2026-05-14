import '../../services/history_service.dart';
import '../../services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/backround.dart';
import '../../widgets/common/app_drawer.dart';
import 'package:cryptoadv/backend/crypto/hachage.dart';
import 'package:file_picker/file_picker.dart';

class HachageMobile extends StatefulWidget {
  const HachageMobile({super.key});

  @override
  State<HachageMobile> createState() => _HachageMobileState();
}

class _HachageMobileState extends State<HachageMobile> {
  final TextEditingController messageController = TextEditingController();
  final TextEditingController resultController = TextEditingController();

  String selectedAlgo = "sha256";
  String fileHashResult = "";
  String fileName = "Aucun fichier sélectionné";
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

  Future<void> _pickAndHashFile() async {
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
        const SnackBar(content: Text("Impossible de lire le fichier.")),
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

    return Scaffold(
      drawer: const AppDrawer(currentPage: 'hachage'),
      appBar: AppBar(
        title: const Text('Hachage'),
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
                  _hashCard(
                    isDark: isDark,
                    title: "Message",
                    icon: Icons.text_fields,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: messageController,
                          maxLines: 3,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                          decoration: _inputDeco("Entrez votre message...", isDark),
                        ),
                        const SizedBox(height: 16),
                        _algoDropdown(isDark),
                        const SizedBox(height: 16),
                        _actionButton("Hacher", isDark, () async {
                          final result = hashMessage(messageController.text, algorithm: selectedAlgo);
                          setState(() => resultController.text = result);
                          await _saveHistory(inputPreview: messageController.text, result: result);
                        }),
                        const SizedBox(height: 16),
                        _resultField(resultController, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _hashCard(
                    isDark: isDark,
                    title: "Fichier",
                    icon: Icons.insert_drive_file_outlined,
                    color: (isDark ? const Color(0xFF0047AB) : const Color(0xFFEFF6FF)).withOpacity(0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: (isDark ? const Color(0xFF1A1F71) : const Color(0xFFDBEAFE)).withOpacity(0.35),
                            border: Border.all(color: (isDark ? Colors.white12 : Colors.black12)),
                          ),
                          child: Text(fileName, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
                        ),
                        const SizedBox(height: 16),
                        _actionButton("Choisir un fichier", isDark, _pickAndHashFile),
                        const SizedBox(height: 16),
                        _resultDisplay(fileHashResult, isDark),
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

  Widget _hashCard({required bool isDark, required String title, required IconData icon, required Widget child, Color? color}) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(icon, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), size: 24),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), fontSize: 13),
      filled: true,
      fillColor: (isDark ? const Color(0xFF1A1F71) : const Color(0xFFDBEAFE)).withOpacity(0.35),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(14),
    );
  }

  Widget _algoDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1A1F71) : const Color(0xFFF8FAFC)).withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isDark ? Colors.white12 : Colors.black12)),
      ),
      child: DropdownButton<String>(
        value: selectedAlgo,
        isExpanded: true,
        dropdownColor: isDark ? const Color(0xFF2A1E7A) : Colors.white,
        underline: const SizedBox(),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _resultField(TextEditingController ctrl, bool isDark) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      maxLines: 2,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12),
      decoration: _inputDeco("Le hash apparaîtra ici...", isDark).copyWith(
        suffixIcon: IconButton(
          icon: Icon(Icons.copy, color: isDark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB), size: 20),
          onPressed: () {
            if (ctrl.text.isEmpty) return;
            Clipboard.setData(ClipboardData(text: ctrl.text));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hash copié !"), duration: Duration(seconds: 2)));
          },
        ),
      ),
    );
  }

  Widget _resultDisplay(String result, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: (isDark ? const Color(0xFF1A1F71) : const Color(0xFFDBEAFE)).withOpacity(0.35),
        border: Border.all(color: (isDark ? Colors.white12 : Colors.black12)),
      ),
      child: SelectableText(
        result.isEmpty ? "Le hash du fichier apparaîtra ici..." : result,
        style: TextStyle(
          color: result.isEmpty ? (isDark ? Colors.white54 : Colors.black45) : (isDark ? Colors.white : Colors.black87),
          fontSize: 12,
        ),
      ),
    );
  }
}
