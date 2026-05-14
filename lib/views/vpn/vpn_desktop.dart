import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/backround.dart';
import '../../models/certificate_model.dart';
import '../../models/vpn_message_model.dart';
import '../../services/vpn_service.dart';
import '../../widgets/common/app_navbar.dart';

class VpnDesktop extends StatefulWidget {
  const VpnDesktop({super.key});

  @override
  State<VpnDesktop> createState() => _VpnDesktopState();
}

class _VpnDesktopState extends State<VpnDesktop> with SingleTickerProviderStateMixin {
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

  final _revokeEmailCtrl = TextEditingController();
  bool _isRevoking = false;
  bool _isRevokingSelf = false;
  List<String> _crl = [];
  bool _crlLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPkiStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _receiverCtrl.dispose();
    _messageCtrl.dispose();
    _revokeEmailCtrl.dispose();
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
    setState(() { _isGenerating = true; _sendError = null; });
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
      if (mounted) setState(() { _sendSuccess = true; _sendStep = 'Envoyé avec succès !'; _messageCtrl.clear(); });
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
        title: Text('Déchiffrement RSA+AES...', style: TextStyle(color: Colors.white)),
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
          content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _securityBadge(Icons.verified_user, 'Certificat', result.certificateValid && !result.certRevoked),
              const SizedBox(width: 8),
              _securityBadge(Icons.draw, 'Signature', result.signatureValid),
              if (result.certRevoked) ...[const SizedBox(width: 8), _securityBadge(Icons.block, 'Révoqué', false)],
            ]),
            const SizedBox(height: 16),
            Text('De : ${result.senderEmail}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            if (result.senderCert != null)
              Text('Cert expire : ${result.senderCert!.notAfter}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const Divider(color: Colors.white12, height: 24),
            SelectableText(result.message, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
          ]))),
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
      _showSnack('Erreur de déchiffrement : $e');
    }
  }

  Future<void> _loadCrl() async {
    setState(() => _crlLoading = true);
    try {
      final crl = await _vpnService.getCrl();
      if (mounted) setState(() => _crl = crl);
    } catch (e) {
      if (mounted) _showSnack('Erreur CRL : $e');
    } finally {
      if (mounted) setState(() => _crlLoading = false);
    }
  }

  Future<void> _revokeByEmail() async {
    final email = _revokeEmailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _isRevoking = true);
    try {
      await _vpnService.revokeUserByEmail(email);
      if (mounted) {
        _showSnack('Certificat de $email révoqué.', success: true);
        _revokeEmailCtrl.clear();
        _loadCrl();
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }

  Future<void> _revokeSelf() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Confirmer la révocation', style: TextStyle(color: Colors.white)),
        content: const Text('Révoquer votre certificat rendra vos messages futurs non vérifiables. Continuer ?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Révoquer', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isRevokingSelf = true);
    try {
      await _vpnService.revokeMyCertificate();
      if (mounted) { _showSnack('Votre certificat a été révoqué.'); _loadCrl(); }
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isRevokingSelf = false);
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
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: Column(
              children: [
                const AppNavbar(currentPage: 'vpn'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(colors: isDark
                          ? [const Color(0xFF7AA6FF), const Color(0xFF6A5AE0)]
                          : [const Color(0xFF3B82F6), const Color(0xFF2563EB)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tabs: const [
                      Tab(icon: Icon(Icons.key, size: 16), text: 'Clés & Cert'),
                      Tab(icon: Icon(Icons.send, size: 16), text: 'Envoyer'),
                      Tab(icon: Icon(Icons.inbox, size: 16), text: 'Réception'),
                      Tab(icon: Icon(Icons.security, size: 16), text: 'Tests'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPkiTab(isDark),
                      _buildSendTab(isDark),
                      _buildInboxTab(isDark),
                      _buildTestsTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPkiTab(bool isDark) {
    if (!_hasKeys) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.lock_outlined, size: 80, color: Colors.white24),
      const SizedBox(height: 20),
      const Text('Aucune clé RSA configurée', style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Générez votre paire de clés pour activer le VPN sécurisé', style: TextStyle(color: Colors.white38)),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generateKeys,
        icon: _isGenerating
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.vpn_key),
        label: Text(_isGenerating ? 'Génération RSA 2048...' : 'Générer Clés RSA'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16)),
      ),
    ]));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _glassCard(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.vpn_key, color: Colors.blue, size: 18),
            SizedBox(width: 8),
            Text('Ma Clé Publique RSA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: SelectableText(_myPublicKey ?? '', style: const TextStyle(color: Colors.blue, fontFamily: 'monospace', fontSize: 11)),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () { Clipboard.setData(ClipboardData(text: _myPublicKey ?? '')); _showSnack('Clé publique copiée !', success: true); },
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copier la clé'),
          ),
        ]))),
        const SizedBox(width: 16),
        Expanded(child: Column(children: [
          if (_myCert != null) _glassCard(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.verified_user, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text('Mon Certificat X.509', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            _certInfoRow('Sujet', _myCert!.subject),
            const SizedBox(height: 6),
            _certInfoRow('Expire le', _myCert!.notAfter.toString()),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green),
                SizedBox(width: 6),
                Text('Certificat actif', style: TextStyle(color: Colors.green, fontSize: 13)),
              ]),
            ),
          ])),
          if (_myCert == null) _glassCard(isDark: isDark, child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.pending, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('Certificat X.509', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            SizedBox(height: 12),
            Text('En attente de l\'autorité de certification.', style: TextStyle(color: Colors.white54)),
          ])),
        ])),
      ]),
    );
  }

  Widget _buildSendTab(bool isDark) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: _glassCard(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.lock, color: Colors.blue, size: 18),
          SizedBox(width: 8),
          Text('Envoyer un message chiffré', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 4),
        const Text('RSA-OAEP 2048 + AES-256-GCM avec signature numérique', style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 20),
        TextField(controller: _receiverCtrl, decoration: _fieldDeco('Email destinataire', isDark, Icons.email)),
        const SizedBox(height: 12),
        TextField(controller: _messageCtrl, maxLines: 5, decoration: _fieldDeco('Message...', isDark, Icons.message)),
        const SizedBox(height: 20),
        if (_sendStep != null) Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (_sendSuccess ? Colors.green : Colors.blue).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: (_sendSuccess ? Colors.green : Colors.blue).withOpacity(0.3)),
          ),
          child: Row(children: [
            if (_isSending) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            if (!_isSending && _sendSuccess) const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Text(_sendStep!, style: TextStyle(color: _sendSuccess ? Colors.green : Colors.blue, fontSize: 13)),
          ]),
        ),
        if (_sendError != null) Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_sendError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
          ]),
        ),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _isSending ? null : _sendMessage,
          icon: _isSending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send),
          label: Text(_isSending ? 'Chiffrement & envoi...' : 'Envoyer Sécurisé'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
      ])),
    )),
  );

  Widget _buildInboxTab(bool isDark) => StreamBuilder<List<VpnMessage>>(
    stream: _vpnService.getInbox(),
    builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final msgs = snap.data!;
      if (msgs.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox, size: 64, color: Colors.white24),
        SizedBox(height: 16),
        Text('Aucun message reçu', style: TextStyle(color: Colors.white38, fontSize: 18)),
        SizedBox(height: 8),
        Text('Les messages chiffrés apparaîtront ici', style: TextStyle(color: Colors.white24, fontSize: 13)),
      ]));
      return ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: msgs.length,
        itemBuilder: (context, i) => _messageTile(msgs[i], isDark),
      );
    },
  );

  Widget _messageTile(VpnMessage msg, bool isDark) => _glassCard(isDark: isDark, child: Row(children: [
    Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), shape: BoxShape.circle),
      child: const Icon(Icons.lock, color: Colors.blue, size: 20),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(msg.senderEmail, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      const Text('Message chiffré RSA-OAEP + AES-256-GCM', style: TextStyle(color: Colors.white38, fontSize: 12)),
      if (msg.timestamp != null)
        Text(msg.timestamp.toString().substring(0, 16), style: const TextStyle(color: Colors.white24, fontSize: 11)),
    ])),
    ElevatedButton.icon(
      onPressed: () => _openDecryptDialog(msg),
      icon: const Icon(Icons.lock_open, size: 14),
      label: const Text('Déchiffrer'),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), textStyle: const TextStyle(fontSize: 12)),
    ),
  ]));

  Widget _buildTestsTab(bool isDark) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _glassCard(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.block, color: Colors.redAccent, size: 18),
            SizedBox(width: 8),
            Text('Révocation de certificat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 4),
          const Text('Révoquer un certificat via la CRL', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(controller: _revokeEmailCtrl, decoration: _fieldDeco('Email utilisateur', isDark, Icons.person)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _isRevoking ? null : _revokeByEmail,
              icon: _isRevoking
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.gpp_bad, size: 16),
              label: Text(_isRevoking ? 'Révocation...' : 'Révoquer'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            )),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isRevokingSelf ? null : _revokeSelf,
              icon: const Icon(Icons.person_off, size: 16),
              label: const Text('Mon cert'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            ),
          ]),
        ]))),
        const SizedBox(width: 16),
        Expanded(child: _glassCard(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Row(children: [
              Icon(Icons.list_alt, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text('CRL — Liste de révocation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            IconButton(
              icon: _crlLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _crlLoading ? null : _loadCrl,
            ),
          ]),
          const SizedBox(height: 8),
          if (_crl.isEmpty) const Text('Appuyez sur actualiser pour charger la CRL.', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ..._crl.map((serial) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.cancel, color: Colors.redAccent, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(serial, style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12))),
            ]),
          )),
          if (_crl.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${_crl.length} certificat(s) révoqué(s)', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ]))),
      ]),
      const SizedBox(height: 16),
      _glassCard(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 18),
          SizedBox(width: 8),
          Text('Architecture de sécurité', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 16),
        _infoRow(Icons.lock, 'Chiffrement', 'RSA-OAEP 2048 bits + AES-256-GCM'),
        _infoRow(Icons.draw, 'Signature', 'RSA avec SHA-256'),
        _infoRow(Icons.verified_user, 'Certificats', 'X.509 émis par CA interne'),
        _infoRow(Icons.block, 'Révocation', 'CRL (Certificate Revocation List)'),
        _infoRow(Icons.storage, 'Transport', 'Canal Firebase chiffré de bout en bout'),
      ])),
    ]),
  );

  Widget _glassCard({required Widget child, required bool isDark}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: isDark ? Colors.white10 : Colors.white.withOpacity(0.8),
      border: Border.all(color: Colors.white12),
    ),
    child: child,
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

  Widget _certInfoRow(String label, String value) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 80, child: Text('$label :', style: const TextStyle(color: Colors.white54, fontSize: 13))),
    Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
  ]);

  Widget _securityBadge(IconData icon, String label, bool ok) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: (ok ? Colors.green : Colors.red).withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: (ok ? Colors.green : Colors.red).withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: ok ? Colors.green : Colors.red),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: ok ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, color: Colors.white38, size: 16),
      const SizedBox(width: 10),
      SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
    ]),
  );
}
