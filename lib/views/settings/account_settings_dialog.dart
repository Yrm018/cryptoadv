import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/localization/app_l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/user_avatar.dart';

void showAccountSettings(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const AccountSettingsDialog(),
  );
}

class AccountSettingsDialog extends StatefulWidget {
  const AccountSettingsDialog({super.key});

  @override
  State<AccountSettingsDialog> createState() => _AccountSettingsDialogState();
}

class _AccountSettingsDialogState extends State<AccountSettingsDialog> {
  // ── Username ──────────────────────────────────────────────────────────────
  final _usernameCtrl = TextEditingController();
  bool _usernameExpanded = false;
  bool _usernameLoading  = false;
  String _usernameError   = '';
  String _usernameSuccess = '';

  // ── Mot de passe ──────────────────────────────────────────────────────────
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl     = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _passExpanded    = false;
  bool _passLoading     = false;
  String _passError     = '';
  String _passSuccess   = '';
  bool _showCurrentPass = false;
  bool _showNewPass     = false;
  bool _showConfirmPass = false;

  bool get _hasLength  => _newPassCtrl.text.length >= 8;
  bool get _hasUpper   => _newPassCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLower   => _newPassCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit   => _newPassCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => _newPassCtrl.text.contains(RegExp(r'[!@#$%^&*()\-_=+\[\]{};:,.<>?/\\|~]'));

  // ── Profil ────────────────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  bool _profileExpanded = false;
  bool _profileLoading  = false;
  String _profileError   = '';
  String _profileSuccess = '';

  // ── Photo ─────────────────────────────────────────────────────────────────
  bool _photoLoading  = false;
  String _photoError   = '';
  String _photoSuccess = '';

  // ── Langue ────────────────────────────────────────────────────────────────
  bool _langExpanded = false;

  @override
  void initState() {
    super.initState();
    _newPassCtrl.addListener(() => setState(() {}));
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _usernameCtrl.text  = user.username;
      _firstNameCtrl.text = user.firstName;
      _lastNameCtrl.text  = user.lastName;
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _saveUsername(AppL10n l) async {
    setState(() { _usernameLoading = true; _usernameError = ''; _usernameSuccess = ''; });
    try {
      await context.read<AuthProvider>().updateUsername(_usernameCtrl.text.trim());
      if (mounted) setState(() => _usernameSuccess = l.t('username_updated'));
    } on AuthException catch (e) {
      if (mounted) setState(() => _usernameError = translateAuthError(e.code, l));
    } catch (e) {
      if (mounted) setState(() => _usernameError = '${l.t('error_prefix')} : $e');
    } finally {
      if (mounted) setState(() => _usernameLoading = false);
    }
  }

  Future<void> _savePassword(AppL10n l) async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() => _passError = l.t('pass_no_match'));
      return;
    }
    setState(() { _passLoading = true; _passError = ''; _passSuccess = ''; });
    try {
      await context.read<AuthProvider>().updatePassword(
        currentPassword: _currentPassCtrl.text.trim(),
        newPassword: _newPassCtrl.text.trim(),
      );
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (mounted) setState(() => _passSuccess = l.t('password_updated'));
    } on AuthException catch (e) {
      if (mounted) setState(() => _passError = translateAuthError(e.code, l));
    } catch (e) {
      if (mounted) setState(() => _passError = '${l.t('error_prefix')} : $e');
    } finally {
      if (mounted) setState(() => _passLoading = false);
    }
  }

  Future<void> _pickPhoto(AppL10n l) async {
    setState(() { _photoLoading = true; _photoError = ''; _photoSuccess = ''; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _photoLoading = false);
        return;
      }
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() { _photoLoading = false; _photoError = l.t('error_prefix'); });
        return;
      }
      final base64Str = base64Encode(bytes);
      await context.read<AuthProvider>().updatePhoto(base64Str);
      if (mounted) setState(() => _photoSuccess = l.t('photo_updated'));
    } catch (e) {
      if (mounted) setState(() => _photoError = '${l.t('error_prefix')} : $e');
    } finally {
      if (mounted) setState(() => _photoLoading = false);
    }
  }

  Future<void> _removePhoto(AppL10n l) async {
    setState(() { _photoLoading = true; _photoError = ''; _photoSuccess = ''; });
    try {
      await context.read<AuthProvider>().updatePhoto(null);
      if (mounted) setState(() => _photoSuccess = l.t('photo_removed'));
    } catch (e) {
      if (mounted) setState(() => _photoError = '${l.t('error_prefix')} : $e');
    } finally {
      if (mounted) setState(() => _photoLoading = false);
    }
  }

  Future<void> _saveProfile(AppL10n l) async {
    setState(() { _profileLoading = true; _profileError = ''; _profileSuccess = ''; });
    try {
      await context.read<AuthProvider>().updateProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName:  _lastNameCtrl.text.trim(),
      );
      if (mounted) setState(() => _profileSuccess = l.t('profile_updated'));
    } on AuthException catch (e) {
      if (mounted) setState(() => _profileError = translateAuthError(e.code, l));
    } catch (e) {
      if (mounted) setState(() => _profileError = '${l.t('error_prefix')} : $e');
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l      = AppL10n.of(context);
    final user   = context.watch<AuthProvider>().currentUser;
    final locale = context.watch<LocaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 740),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0047AB), Color(0xFF7AA6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                // ── Avatar cliquable ────────────────────────────────────────
                Stack(children: [
                  UserAvatar(
                    photoBase64:     user?.photoBase64,
                    initial:         user?.username ?? '?',
                    radius:          28,
                    backgroundColor: Colors.white.withOpacity(0.25),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: _photoLoading ? null : () => _pickPhoto(l),
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0047AB), width: 1.5),
                        ),
                        child: _photoLoading
                          ? const Padding(
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF0047AB)))
                          : const Icon(Icons.camera_alt_rounded, size: 12, color: Color(0xFF0047AB)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.displayName ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('@${user?.username ?? ''}',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                  Text(user?.email ?? '',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  if (_photoSuccess.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_photoSuccess,
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                  ],
                  if (_photoError.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_photoError,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ],
                ])),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  if (user?.photoBase64 != null)
                    IconButton(
                      tooltip: l.t('remove_photo'),
                      onPressed: _photoLoading ? null : () => _removePhoto(l),
                      icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 18),
                    ),
                ]),
              ]),
            ),

            // ── Contenu ─────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [

                  // ── Langue ────────────────────────────────────────────────
                  _section(
                    isDark: isDark,
                    icon: Icons.language,
                    title: l.t('choose_language'),
                    expanded: _langExpanded,
                    onToggle: () => setState(() => _langExpanded = !_langExpanded),
                    content: Column(children: [
                      const SizedBox(height: 4),
                      _langTile(context, locale, '🇫🇷', 'fr', l.t('french'),  isDark),
                      _langTile(context, locale, '🇬🇧', 'en', l.t('english'), isDark),
                      _langTile(context, locale, '🇸🇦', 'ar', l.t('arabic'),  isDark),
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // ── Username ──────────────────────────────────────────────
                  _section(
                    isDark: isDark,
                    icon: Icons.alternate_email,
                    title: l.t('edit_username'),
                    expanded: _usernameExpanded,
                    onToggle: () => setState(() {
                      _usernameExpanded = !_usernameExpanded;
                      _usernameError = _usernameSuccess = '';
                    }),
                    content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _field(isDark: isDark, ctrl: _usernameCtrl,
                          hint: l.t('username_hint'), icon: Icons.alternate_email),
                      if (_usernameError.isNotEmpty)   _errText(_usernameError),
                      if (_usernameSuccess.isNotEmpty) _okText(_usernameSuccess),
                      const SizedBox(height: 12),
                      _btn(label: l.t('save'), loading: _usernameLoading, onTap: () => _saveUsername(l)),
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // ── Mot de passe ──────────────────────────────────────────
                  _section(
                    isDark: isDark,
                    icon: Icons.lock_outline,
                    title: l.t('edit_password'),
                    expanded: _passExpanded,
                    onToggle: () => setState(() {
                      _passExpanded = !_passExpanded;
                      _passError = _passSuccess = '';
                    }),
                    content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _field(isDark: isDark, ctrl: _currentPassCtrl,
                          hint: l.t('current_password'), icon: Icons.lock_outline,
                          obscure: !_showCurrentPass,
                          suffix: _eye(_showCurrentPass, () => setState(() => _showCurrentPass = !_showCurrentPass))),
                      const SizedBox(height: 10),
                      _field(isDark: isDark, ctrl: _newPassCtrl,
                          hint: l.t('new_password'), icon: Icons.lock_reset,
                          obscure: !_showNewPass,
                          suffix: _eye(_showNewPass, () => setState(() => _showNewPass = !_showNewPass))),
                      const SizedBox(height: 8),
                      _strengthGrid(l),
                      const SizedBox(height: 10),
                      _field(isDark: isDark, ctrl: _confirmPassCtrl,
                          hint: l.t('confirm_new_password'), icon: Icons.lock_reset,
                          obscure: !_showConfirmPass,
                          suffix: _eye(_showConfirmPass, () => setState(() => _showConfirmPass = !_showConfirmPass))),
                      if (_passError.isNotEmpty)   _errText(_passError),
                      if (_passSuccess.isNotEmpty) _okText(_passSuccess),
                      const SizedBox(height: 12),
                      _btn(label: l.t('change_password_btn'), loading: _passLoading, onTap: () => _savePassword(l)),
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // ── Profil ────────────────────────────────────────────────
                  _section(
                    isDark: isDark,
                    icon: Icons.person_outline,
                    title: l.t('edit_profile'),
                    expanded: _profileExpanded,
                    onToggle: () => setState(() {
                      _profileExpanded = !_profileExpanded;
                      _profileError = _profileSuccess = '';
                    }),
                    content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: _field(isDark: isDark, ctrl: _firstNameCtrl,
                            hint: l.t('first_name'), icon: Icons.badge_outlined)),
                        const SizedBox(width: 10),
                        Expanded(child: _field(isDark: isDark, ctrl: _lastNameCtrl,
                            hint: l.t('last_name'), icon: Icons.badge_outlined)),
                      ]),
                      if (_profileError.isNotEmpty)   _errText(_profileError),
                      if (_profileSuccess.isNotEmpty) _okText(_profileSuccess),
                      const SizedBox(height: 12),
                      _btn(label: l.t('update_btn'), loading: _profileLoading, onTap: () => _saveProfile(l)),
                    ]),
                  ),

                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets helpers ───────────────────────────────────────────────────────

  Widget _section({
    required bool isDark,
    required IconData icon,
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget content,
  }) =>
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Column(children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(icon, size: 18,
                    color: isDark ? const Color(0xFF7AA6FF) : const Color(0xFF0047AB)),
                const SizedBox(width: 12),
                Expanded(child: Text(title,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600, fontSize: 14))),
                Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: isDark ? Colors.white54 : Colors.black38),
              ]),
            ),
          ),
          if (expanded)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: content),
        ]),
      );

  Widget _langTile(BuildContext context, LocaleProvider locale,
      String flag, String code, String label, bool isDark) {
    final active = locale.languageCode == code;
    return InkWell(
      onTap: () => locale.setLocale(code),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active
              ? const Color(0xFF0047AB).withOpacity(0.15)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100),
          border: Border.all(
              color: active ? const Color(0xFF7AA6FF) : Colors.transparent),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: active
                      ? const Color(0xFF7AA6FF)
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14)),
          const Spacer(),
          if (active)
            const Icon(Icons.check_circle, color: Color(0xFF7AA6FF), size: 18),
        ]),
      ),
    );
  }

  Widget _field({
    required bool isDark,
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black45, size: 18),
          suffixIcon: suffix,
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        ),
      );

  Widget _eye(bool visible, VoidCallback onTap) => IconButton(
      icon: Icon(visible ? Icons.visibility_off : Icons.visibility,
          size: 18, color: Colors.white54),
      onPressed: onTap);

  Widget _btn({required String label, required bool loading, required VoidCallback onTap}) =>
      SizedBox(
        width: double.infinity, height: 42,
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0047AB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      );

  Widget _strengthGrid(AppL10n l) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _crit(_hasLength,  l.t('str_length')),
      _crit(_hasUpper,   l.t('str_upper')),
      _crit(_hasSpecial, l.t('str_special')),
    ])),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _crit(_hasLower, l.t('str_lower')),
      _crit(_hasDigit, l.t('str_digit')),
    ])),
  ]);

  Widget _crit(bool ok, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 13, color: ok ? Colors.greenAccent : Colors.white38),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          color: ok ? Colors.greenAccent : Colors.white38, fontSize: 11)),
    ]),
  );

  Widget _errText(String msg) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(msg, style: const TextStyle(color: Colors.redAccent, fontSize: 12)));

  Widget _okText(String msg) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(msg, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)));
}
