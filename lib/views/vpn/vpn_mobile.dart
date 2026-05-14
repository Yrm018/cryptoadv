import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/backround.dart';
import '../../models/certificate_model.dart';
import '../../models/vpn_message_model.dart';
import '../../services/vpn_service.dart';
import '../../widgets/common/app_drawer.dart';

class VpnMobile extends StatefulWidget {
  const VpnMobile({super.key});

  @override
  State<VpnMobile> createState() => _VpnMobileState();
}

class _VpnMobileState extends State<VpnMobile> with SingleTickerProviderStateMixin {
  final _vpnService = VpnService();
  late TabController _tabController;

  bool _hasKeys = false;
  bool _isGenerating = false;
  CertificateData? _myCert;
  String? _myPublicKey;

  final _receiverCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSending = false;
  String? _sendStep;
  String? _sendError;
  bool _sendSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPkiStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _receiverCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPkiStatus() async {
    final has = await _vpnService.hasKeys();
    if (mounted) setState(() => _hasKeys = has);
    if (has) _loadCertificate();
  }

  Future<void> _loadCertificate() async {
    final cert = await _vpnService.getMyCertificate();
    final pub = await _vpnService.getMyPublicKey();
    if (mounted) setState(() { _myCert = cert; _myPublicKey = pub; });
  }

  Future<void> _generateKeys() async {
    setState(() => _isGenerating = true);
    try {
      await _vpnService.generateAndRegisterKeys();
      await _loadPkiStatus();
      if (mounted) _showSnack('Clés RSA générées avec succès !', success: true);
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _sendMessage() async {
    final receiver = _receiverCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (receiver.isEmpty || message.isEmpty) return;
    setState(() { _isSending = true; _sendError = null; _sendSuccess = false; _sendStep = 'Signature RSA...'; });
    try {
      await _vpnService.sendMessage(receiverEmail: receiver, message: message);
      if (mounted) setState(() { _sendSuccess = true; _sendStep = 'Envoyé !'; _messageCtrl.clear(); });
    } catch (e) {
      if (mounted) setState(() { _sendError = e.toString(); _sendStep = null; });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openDecryptDialog(VpnMessage msg) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Color(0xFF1E1E2E),
        content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        title: Text('Déchiffrement...', style: TextStyle(color: Colors.white)),
      ),
    );
    try {
      final result = await _vpnService.decryptAndVerify(msg);
      if (!mounted) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Row(children: [
            Icon(Icons.lock_open, color: Colors.blue),
            SizedBox(width: 8),
            Text('Message déchiffré', style: TextStyle(color: Colors.white)),
          ]),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _securityBadge(Icons.verified_user, 'Certificat', result.certificateValid && !result.certRevoked),
              const SizedBox(width: 8),
              _securityBadge(Icons.draw, 'Signature', result.signatureValid),
            ]),
            if (result.certRevoked) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _securityBadge(Icons.block, 'Révoqué', false),
            ),
            const Divider(color: Colors.white12, height: 24),
            Text('De : ${result.senderEmail}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 10),
            SelectableText(result.message, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
          ])),
          actions: [
            TextButton(
              onPressed: () { Clipboard.setData(ClipboardData(text: result.message)); _showSnack('Message copié !', success: true); },
              child: const Text('Copier'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnack('Erreur : $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(currentPage: 'vpn'),
      appBar: AppBar(
        title: const Text('VPN Sécurisé'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(icon: Icon(Icons.key, size: 16), text: 'Clés'),
            Tab(icon: Icon(Icons.send, size: 16), text: 'Envoi'),
            Tab(icon: Icon(Icons.inbox, size: 16), text: 'Reçus'),
          ],
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPkiTab(isDark),
                _buildSendTab(isDark),
                _buildInboxTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPkiTab(bool isDark) {
    if (_isGenerating) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(),
      SizedBox(height: 16),
      Text('Génération RSA 2048 bits...', style: TextStyle(color: Colors.white54)),
    ]));
    if (!_hasKeys) return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_outlined, size: 64, color: Colors.white24),
        const SizedBox(height: 16),
        const Text('Aucune clé RSA', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Générez votre paire de clés pour activer le VPN sécurisé', style: TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _generateKeys,
          icon: const Icon(Icons.vpn_key),
          label: const Text('Générer Clés RSA'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
        ),
      ]),
    ));
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      _card(isDark, 'Ma Clé Publique', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
          child: SelectableText(_myPublicKey ?? '', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.blue)),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () { Clipboard.setData(ClipboardData(text: _myPublicKey ?? '')); _showSnack('Clé copiée !', success: true); },
          icon: const Icon(Icons.copy, size: 14),
          label: const Text('Copier', style: TextStyle(fontSize: 12)),
        ),
      ])),
      if (_myCert != null) _card(isDark, 'Mon Certificat X.509', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _certRow(Icons.person, 'Sujet', _myCert!.subject),
        const SizedBox(height: 6),
        _certRow(Icons.schedule, 'Expire le', _myCert!.notAfter.toString()),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.4)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green),
            SizedBox(width: 6),
            Text('Certificat actif', style: TextStyle(color: Colors.green, fontSize: 12)),
          ]),
        ),
      ])),
      if (_myCert == null && _myPublicKey != null) _card(isDark, 'Certificat X.509', const Row(children: [
        Icon(Icons.pending, color: Colors.orange, size: 16),
        SizedBox(width: 8),
        Text('En attente de l\'autorité de certification', style: TextStyle(color: Colors.orange, fontSize: 12)),
      ])),
    ]));
  }

  Widget _buildSendTab(bool isDark) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: _card(isDark, 'Envoyer un message chiffré', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('RSA-OAEP + AES-256-GCM', style: TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 12),
      TextField(controller: _receiverCtrl, decoration: _fieldDeco('Email destinataire', isDark, Icons.email)),
      const SizedBox(height: 10),
      TextField(controller: _messageCtrl, maxLines: 4, decoration: _fieldDeco('Message...', isDark, Icons.message)),
      const SizedBox(height: 16),
      if (_sendStep != null) Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (_sendSuccess ? Colors.green : Colors.blue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          if (_isSending) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          if (!_isSending && _sendSuccess) const Icon(Icons.check_circle, color: Colors.green, size: 14),
          const SizedBox(width: 8),
          Text(_sendStep!, style: TextStyle(color: _sendSuccess ? Colors.green : Colors.blue, fontSize: 12)),
        ]),
      ),
      if (_sendError != null) Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(_sendError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
      ),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _isSending ? null : _sendMessage,
        icon: _isSending
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send),
        label: Text(_isSending ? 'Envoi en cours...' : 'Envoyer'),
      )),
    ])),
  );

  Widget _buildInboxTab(bool isDark) => StreamBuilder<List<VpnMessage>>(
    stream: _vpnService.getInbox(),
    builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final msgs = snap.data!;
      if (msgs.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox, size: 48, color: Colors.white24),
        SizedBox(height: 12),
        Text('Aucun message reçu', style: TextStyle(color: Colors.white38, fontSize: 15)),
      ]));
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: msgs.length,
        itemBuilder: (context, i) {
          final msg = msgs[i];
          return _card(isDark, 'De : ${msg.senderEmail}', InkWell(
            onTap: () => _openDecryptDialog(msg),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const Icon(Icons.lock, color: Colors.blue, size: 14),
                const SizedBox(width: 6),
                const Expanded(child: Text('Appuyer pour déchiffrer', style: TextStyle(color: Colors.white38, fontSize: 12))),
                const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
              ]),
            ),
          ));
        },
      );
    },
  );

  Widget _card(bool isDark, String title, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      color: isDark ? Colors.white10 : Colors.white.withOpacity(0.8),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 10),
      child,
    ]),
  );

  InputDecoration _fieldDeco(String hint, bool isDark, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 18, color: Colors.white38),
    filled: true,
    fillColor: Colors.white10,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue)),
  );

  Widget _certRow(IconData icon, String label, String value) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 14, color: Colors.white38),
    const SizedBox(width: 6),
    Expanded(child: RichText(text: TextSpan(children: [
      TextSpan(text: '$label : ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      TextSpan(text: value, style: const TextStyle(color: Colors.white, fontSize: 12)),
    ]))),
  ]);

  Widget _securityBadge(IconData icon, String label, bool ok) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: (ok ? Colors.green : Colors.red).withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: (ok ? Colors.green : Colors.red).withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: ok ? Colors.green : Colors.red),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: ok ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
    ]),
  );
}