import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/backround.dart';
import '../../components/logo.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class AuthMobile extends StatefulWidget {
  const AuthMobile({super.key});

  @override
  State<AuthMobile> createState() => _AuthMobileState();
}

class _AuthMobileState extends State<AuthMobile> {
  // AuthProvider gère la navigation automatiquement via AppRoot
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool showPassword = false;
  String errorMessage = '';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Veuillez remplir tous les champs.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final auth = context.read<AuthProvider>();
      if (isLogin) {
        await auth.signIn(email: email, password: password);
      } else {
        await auth.signUp(email: email, password: password);
      }
      // AppRoot écoute AuthProvider → navigue vers HomePage automatiquement
    } on AuthException catch (e) {
      setState(() => errorMessage = e.message);
    } catch (e) {
      setState(() => errorMessage = 'Une erreur est survenue : $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    AnimatedLogo(size: LogoSize.md),
                    const SizedBox(height: 24),
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isLogin ? 'Connexion' : 'Créer un compte', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(isLogin ? 'Accédez à votre espace sécurisé.' : 'Rejoignez CryptoAdv dès maintenant.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 24),
                          _inputField(controller: emailController, hint: 'Email', icon: Icons.email_outlined),
                          const SizedBox(height: 16),
                          _inputField(
                            controller: passwordController,
                            hint: 'Mot de passe',
                            icon: Icons.lock_outline,
                            obscure: !showPassword,
                            suffix: IconButton(
                              icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
                              onPressed: () => setState(() => showPassword = !showPassword),
                            ),
                          ),
                          if (errorMessage.isNotEmpty) _errorMsg(errorMessage),
                          const SizedBox(height: 24),
                          _submitBtn(),
                          const SizedBox(height: 20),
                          _socialSection(),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() { isLogin = !isLogin; errorMessage = ''; }),
                              child: Text(isLogin ? 'Créer un compte' : 'Déjà un compte ?', style: const TextStyle(color: Color(0xFFD1A7FF), fontSize: 14)),
                            ),
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
    );
  }

  Widget _glassCard({required Widget child}) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFF0047AB).withOpacity(0.15), border: Border.all(color: Colors.white10)), child: child);

  Widget _inputField({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, Widget? suffix}) => TextField(
    controller: controller,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: Colors.white38, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(16),
    ),
  );

  Widget _errorMsg(String msg) => Padding(padding: const EdgeInsets.only(top: 16), child: Text(msg, style: const TextStyle(color: Colors.redAccent, fontSize: 12)));

  Widget _submitBtn() => SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isLoading ? null : submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0047AB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isLogin ? 'Se connecter' : 'S’inscrire', style: const TextStyle(fontWeight: FontWeight.bold))));

  Widget _socialSection() => Column(children: [
    Row(children: [const Expanded(child: Divider(color: Colors.white10)), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text("OU", style: TextStyle(color: Colors.white24, fontSize: 10))), const Expanded(child: Divider(color: Colors.white10))]),
    const SizedBox(height: 16),
    _socialBtn('Google', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png'),
  ]);

  Widget _socialBtn(String name, String url) => OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Image.network(url, height: 18), const SizedBox(width: 12), Text("Continuer avec $name", style: const TextStyle(color: Colors.white, fontSize: 13))]));
}
