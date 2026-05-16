import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/backround.dart';
import '../../core/localization/app_l10n.dart';
import '../../models/certificate_model.dart';
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

  final _revokeEmailCtrl = TextEditingController();
  bool _isRevoking = false;
  bool _isRevokingSelf = false;
  List<String> _crl = [];
  bool _crlLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPkiStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    final pub  = await _vpnService.getMyPublicKey();
    if (mounted) setState(() { _myCert = cert; _myPublicKey = pub; });
  }

  Future<void> _generateKeys(AppL10n l) async {
    setState(() { _isGenerating = true; });
    try {
      await _vpnService.generateAndRegisterKeys();
      await _loadPkiStatus();
      if (mounted) _showSnack(l.t('vpn_gen_keys_success'), success: true);
    } catch (e) {
      if (mounted) _showSnack('${l.t('error_prefix')} : $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _loadCrl(AppL10n l) async {
    setState(() => _crlLoading = true);
    try {
      final crl = await _vpnService.getCrl();
      if (mounted) setState(() => _crl = crl);
    } catch (e) {
      if (mounted) _showSnack('${l.t('error_prefix')} : $e');
    } finally {
      if (mounted) setState(() => _crlLoading = false);
    }
  }

  Future<void> _revokeByEmail(AppL10n l) async {
    final email = _revokeEmailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _isRevoking = true);
    try {
      await _vpnService.revokeUserByEmail(email);
      if (mounted) {
        _showSnack(l.t('vpn_revoked_success').replaceFirst('{email}', email), success: true);
        _revokeEmailCtrl.clear();
        _loadCrl(l);
      }
    } catch (e) {
      if (mounted) _showSnack('${l.t('error_prefix')} : $e');
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }

  Future<void> _revokeSelf(AppL10n l) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(l.t('vpn_revoke_confirm_title'), style: const TextStyle(color: Colors.white)),
        content: Text(l.t('vpn_revoke_confirm_desc'), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.t('vpn_cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.t('vpn_revoke_btn'), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isRevokingSelf = true);
    try {
      await _vpnService.revokeMyCertificate();
      if (mounted) { _showSnack(l.t('vpn_my_revoked')); _loadCrl(l); }
    } catch (e) {
      if (mounted) _showSnack('${l.t('error_prefix')} : $e');
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
    final l = AppL10n.of(context);

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
                    tabs: [
                      Tab(icon: const Icon(Icons.key, size: 16),      text: l.t('vpn_tab_keys')),
                      Tab(icon: const Icon(Icons.security, size: 16), text: l.t('vpn_tab_tests')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPkiTab(isDark, l),
                      _buildTestsTab(isDark, l),
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

  // ─── Onglet Clés & Certificats ────────────────────────────────────────────

  Widget _buildPkiTab(bool isDark, AppL10n l) {
    if (!_hasKeys) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_outlined, size: 80, color: Colors.white24),
        const SizedBox(height: 20),
        Text(l.t('vpn_no_keys_title'),
          style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(l.t('vpn_no_keys_sub'),
          style: const TextStyle(color: Colors.white38)),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _isGenerating ? null : () => _generateKeys(l),
          icon: _isGenerating
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.vpn_key),
          label: Text(_isGenerating ? l.t('vpn_gen_keys_loading') : l.t('vpn_gen_keys_btn')),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16)),
        ),
        if (_isGenerating) ...[
          const SizedBox(height: 16),
          const Text(
            '⏳ Génération RSA 2048-bit en cours...\nCela peut prendre 20-30 secondes, ne quittez pas la page.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange, fontSize: 13),
          ),
        ],
      ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Clé publique
        Expanded(child: _glassCard(isDark: isDark, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.vpn_key, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Text(l.t('vpn_my_pub_key'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(
                _myPublicKey ?? '',
                style: const TextStyle(color: Colors.blue, fontFamily: 'monospace', fontSize: 11)),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _myPublicKey ?? ''));
                _showSnack(l.t('vpn_key_copied'), success: true);
              },
              icon: const Icon(Icons.copy, size: 14),
              label: Text(l.t('vpn_copy_key')),
            ),
          ],
        ))),
        const SizedBox(width: 16),
        // Certificat
        Expanded(child: Column(children: [
          _glassCard(isDark: isDark, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  _myCert != null ? Icons.verified_user : Icons.pending,
                  color: _myCert != null ? Colors.green : Colors.orange,
                  size: 18),
                const SizedBox(width: 8),
                Text(l.t('vpn_my_cert'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const SizedBox(height: 12),
              if (_myCert != null) ...[
                _certInfoRow(l.t('vpn_subject'), _myCert!.subject),
                const SizedBox(height: 6),
                _certInfoRow(l.t('vpn_expires'), _myCert!.notAfter.toString()),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(l.t('vpn_cert_active'),
                      style: const TextStyle(color: Colors.green, fontSize: 13)),
                  ]),
                ),
              ] else
                Text(l.t('vpn_cert_pending'),
                  style: const TextStyle(color: Colors.white54)),
            ],
          )),
        ])),
      ]),
    );
  }

  // ─── Onglet Tests & Révocation ────────────────────────────────────────────

  Widget _buildTestsTab(bool isDark, AppL10n l) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Révocation
        Expanded(child: _glassCard(isDark: isDark, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.block, color: Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Text(l.t('vpn_revoke_title'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 4),
            Text(l.t('vpn_revoke_subtitle'),
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(controller: _revokeEmailCtrl,
              decoration: _fieldDeco(l.t('vpn_user_email'), isDark, Icons.person)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _isRevoking ? null : () => _revokeByEmail(l),
                icon: _isRevoking
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.gpp_bad, size: 16),
                label: Text(_isRevoking ? l.t('vpn_revoking') : l.t('vpn_revoke_btn')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              )),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isRevokingSelf ? null : () => _revokeSelf(l),
                icon: const Icon(Icons.person_off, size: 16),
                label: Text(l.t('vpn_revoke_self')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              ),
            ]),
          ],
        ))),
        const SizedBox(width: 16),
        // CRL
        Expanded(child: _glassCard(isDark: isDark, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const Icon(Icons.list_alt, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text(l.t('vpn_crl_title'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              IconButton(
                icon: _crlLoading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, color: Colors.white54),
                onPressed: _crlLoading ? null : () => _loadCrl(l),
              ),
            ]),
            const SizedBox(height: 8),
            if (_crl.isEmpty)
              Text(l.t('vpn_crl_hint'),
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
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
                Expanded(child: Text(serial,
                  style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12))),
              ]),
            )),
            if (_crl.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.t('vpn_crl_count').replaceFirst('{count}', _crl.length.toString()),
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
        ))),
      ]),
      const SizedBox(height: 16),
      // Architecture info
      _glassCard(isDark: isDark, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline, color: Colors.blue, size: 18),
            const SizedBox(width: 8),
            Text(l.t('vpn_arch_title'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 16),
          _infoRow(Icons.lock,         l.t('vpn_arch_encrypt'),    l.t('vpn_arch_encrypt_val')),
          _infoRow(Icons.draw,         l.t('vpn_arch_sign'),       l.t('vpn_arch_sign_val')),
          _infoRow(Icons.verified_user,l.t('vpn_arch_certs'),      l.t('vpn_arch_certs_val')),
          _infoRow(Icons.block,        l.t('vpn_arch_revoke'),     l.t('vpn_arch_revoke_val')),
          _infoRow(Icons.storage,      l.t('vpn_arch_transport'),  l.t('vpn_arch_transport_val')),
        ],
      )),
    ]),
  );

  // ─── Helpers ──────────────────────────────────────────────────────────────

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

  Widget _certInfoRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 100,
        child: Text('$label :', style: const TextStyle(color: Colors.white54, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
    ],
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, color: Colors.white38, size: 16),
      const SizedBox(width: 10),
      SizedBox(width: 120,
        child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
    ]),
  );
}
