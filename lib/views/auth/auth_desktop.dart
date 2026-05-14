import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../components/backround.dart';
import '../../components/logo.dart';
import '../../services/auth_service.dart';
import '../home/home_page.dart';

class AuthDesktop extends StatefulWidget {
  const AuthDesktop({super.key});

  @override
  State<AuthDesktop> createState() => _AuthDesktopState();
}

class _AuthDesktopState extends State<AuthDesktop> {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool showPassword = false;
  String errorMessage = '';

  @override
  void dispose() {
    emailController.dispose(); passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) { setState(() => errorMessage = 'Veuillez remplir tous les champs.'); return; }
    setState(() { isLoading = true; errorMessage = ''; });
    try {
      if (isLogin) { await _authService.signIn(email: email, password: password); }
      else { await _authService.signUp(email: email, password: password); }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = _mapFirebaseError(e));
    } catch (e) {
      setState(() => errorMessage = 'Une erreur est survenue : $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found': return 'Aucun utilisateur trouvé.';
      case 'wrong-password': return 'Mot de passe incorrect.';
      case 'invalid-credential': return 'Email ou mot de passe invalide.';
      default: return e.message ?? 'Erreur inconnue.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const CryptoBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    AnimatedLogo(size: LogoSize.lg),
                    const SizedBox(height: 30),
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isLogin ? 'Connexion' : 'Créer un compte', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text(isLogin ? 'Connectez-vous pour accéder à CryptoAdv.' : 'Créez un compte pour sauvegarder votre historique.', style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 15)),
                          const SizedBox(height: 28),
                          _label('Email'),
                          const SizedBox(height: 12),
                          TextField(controller: emailController, style: const TextStyle(color: Colors.white), decoration: _fieldDeco(hint: 'Email...', icon: Icons.email_outlined)),
                          const SizedBox(height: 20),
                          _label('Mot de passe'),
                          const SizedBox(height: 12),
                          TextField(controller: passwordController, obscureText: !showPassword, style: const TextStyle(color: Colors.white), decoration: _fieldDeco(hint: 'Mot de passe...', icon: Icons.lock_outline, suffix: IconButton(onPressed: () => setState(() => showPassword = !showPassword), icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70)))),
                          if (errorMessage.isNotEmpty) _errorBox(errorMessage),
                          const SizedBox(height: 24),
                          _submitButton(),
                          const SizedBox(height: 20),
                          _divider(),
                          const SizedBox(height: 20),
                          _socialLogin(),
                          const SizedBox(height: 18),
                          Center(child: TextButton(onPressed: () => setState(() { isLogin = !isLogin; errorMessage = ''; }), child: Text(isLogin ? 'Pas encore de compte ? S’inscrire' : 'Déjà un compte ? Se connecter', style: const TextStyle(color: Color(0xFFD1A7FF), fontWeight: FontWeight.w600)))),
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
    );
  }

  Widget _glassCard({required Widget child}) => Container(width: 480, padding: const EdgeInsets.all(28), decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), color: const Color(0xFF0047AB).withOpacity(0.22), border: Border.all(color: Colors.white.withOpacity(0.1))), child: child);
  Widget _label(String text) => Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16));
  InputDecoration _fieldDeco({required String hint, IconData? icon, Widget? suffix}) => InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)), prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null, suffixIcon: suffix, filled: true, fillColor: Colors.white.withOpacity(0.07), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))));
  Widget _errorBox(String msg) => Container(margin: const EdgeInsets.only(top: 18), width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.red.withOpacity(0.14), border: Border.all(color: Colors.red.withOpacity(0.25))), child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14)));
  Widget _submitButton() => SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isLoading ? null : submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0047AB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isLogin ? 'Se connecter' : 'S’inscrire', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));
  Widget _divider() => Row(children: [Expanded(child: Divider(color: Colors.white10)), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OU', style: TextStyle(color: Colors.white38, fontSize: 12))), Expanded(child: Divider(color: Colors.white10))]);
  Widget _socialLogin() => Column(children: [
    _socialBtn('Google', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png'),
    const SizedBox(height: 12),
    _socialBtn('GitHub', 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/Octicons-mark-github.svg/1200px-Octicons-mark-github.svg.png'),
  ]);
  Widget _socialBtn(String label, String url) => SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Image.network(url, height: 22, errorBuilder: (_, __, ___) => const Icon(Icons.language)), const SizedBox(width: 12), Text("Continuer avec $label", style: const TextStyle(color: Colors.white))])));
}
