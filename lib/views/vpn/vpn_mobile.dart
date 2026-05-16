import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/backround.dart';
import '../../core/localization/app_l10n.dart';
import '../../models/certificate_model.dart';
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

  final _revokeEmailCtrl = TextEditingController();
  bool _isRevoking = false;
  bool _isRevokingSelf = false;
  List<String> _crl = [];
  bool _crlLoading = false;

  /// Onglet actif : 0 = Clés, 1 = Révocation
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() => _tab = _tabController.index);
    });
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
    setState(() => _isGenerating = true);
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
        title: Text(l.t('vpn_revoke_confirm_title'),
          style: const TextStyle(color: Colors.white)),
        content: Text(l.t('vpn_revoke_confirm_desc'),
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text(l.t('vpn_cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.t('vpn_revoke_btn'),
              style: const TextStyle(color: Colors.redAccent))),
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
      drawer: const AppDrawer(currentPage: 'vpn'),
      appBar: AppBar(
        title: Text(l.t('vpn_title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          onTap: (i) => setState(() => _tab = i),
          tabs: [
            Tab(icon: const Icon(Icons.key, size: 16),      text: l.t('vpn_tab_keys_mobile')),
            Tab(icon: const Icon(Icons.security, size: 16), text: l.t('vpn_tab_tests')),
          ],
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: IndexedStack(
              index: _tab,
              children: [
                _buildPkiTab(isDark, l),
                _buildTestsTab(isDark, l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Onglet Clés & Certificats ────────────────────────────────────────────

  Widget _buildPkiTab(bool isDark, AppL10n l) {
    if (_isGenerating) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(l.t('vpn_gen_keys_loading'),
          style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            '⏳ Génération RSA 2048-bit...\nCela peut prendre 20-30 secondes,\nne quittez pas la page.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ),
      ]));
    }
    if (!_hasKeys) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(l.t('vpn_no_keys_title_mobile'),
            style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l.t('vpn_no_keys_sub'),
            style: const TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _generateKeys(l),
            icon: const Icon(Icons.vpn_key),
            label: Text(l.t('vpn_gen_keys_btn')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
          ),
        ]),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Clé publique
        _card(isDark, l.t('vpn_my_pub_key'), Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(_myPublicKey ?? '',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.blue)),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _myPublicKey ?? ''));
                _showSnack(l.t('vpn_key_copied'), success: true);
              },
              icon: const Icon(Icons.copy, size: 14),
              label: Text(l.t('vpn_copy_key_mobile'),
                style: const TextStyle(fontSize: 12)),
            ),
          ],
        )),
        // Certificat
        if (_myCert != null) _card(isDark, l.t('vpn_my_cert'), Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _certRow(Icons.person,   l.t('vpn_subject'), _myCert!.subject),
            const SizedBox(height: 6),
            _certRow(Icons.schedule, l.t('vpn_expires'), _myCert!.notAfter.toString()),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Text(l.t('vpn_cert_active'),
                  style: const TextStyle(color: Colors.green, fontSize: 12)),
              ]),
            ),
          ],
        )),
        if (_myCert == null && _myPublicKey != null)
          _card(isDark, l.t('vpn_my_cert'), Row(children: [
            const Icon(Icons.pending, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Text(l.t('vpn_cert_pending_mobile'),
              style: const TextStyle(color: Colors.orange, fontSize: 12)),
          ])),
      ]),
    );
  }

  // ─── Onglet Révocation ────────────────────────────────────────────────────

  Widget _buildTestsTab(bool isDark, AppL10n l) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      // Révoquer un utilisateur
      _card(isDark, l.t('vpn_revoke_title'), Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('vpn_revoke_subtitle'),
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 12),
          TextField(controller: _revokeEmailCtrl,
            decoration: _fieldDeco(l.t('vpn_user_email'), isDark, Icons.person)),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _isRevoking ? null : () => _revokeByEmail(l),
            icon: _isRevoking
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.gpp_bad, size: 16),
            label: Text(_isRevoking ? l.t('vpn_revoking') : l.t('vpn_revoke_btn')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _isRevokingSelf ? null : () => _revokeSelf(l),
            icon: const Icon(Icons.person_off, size: 16),
            label: Text(l.t('vpn_revoke_self')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
          )),
        ],
      )),
      // CRL
      _card(isDark, l.t('vpn_crl_title'), Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: _crlLoading ? null : () => _loadCrl(l),
              icon: _crlLoading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 14),
              label: Text(l.t('vpn_crl_refresh') ?? 'Actualiser',
                style: const TextStyle(fontSize: 12)),
            ),
          ]),
          if (_crl.isEmpty)
            Text(l.t('vpn_crl_hint'),
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ..._crl.map((serial) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.cancel, color: Colors.redAccent, size: 12),
              const SizedBox(width: 6),
              Expanded(child: Text(serial,
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 11))),
            ]),
          )),
          if (_crl.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.t('vpn_crl_count').replaceFirst('{count}', _crl.length.toString()),
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
      )),
    ]),
  );

  // ─── Helpers ──────────────────────────────────────────────────────────────

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

  Widget _certRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: Colors.white38),
      const SizedBox(width: 6),
      Expanded(child: RichText(text: TextSpan(children: [
        TextSpan(text: '$label : ',
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
        TextSpan(text: value,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]))),
    ],
  );
}
