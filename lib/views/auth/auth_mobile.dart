import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/backround.dart';
import '../../components/logo.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class AuthMobile extends StatefulWidget {
  final bool initialSignup;
  const AuthMobile({super.key, this.initialSignup = false});

  @override
  State<AuthMobile> createState() => _AuthMobileState();
}

class _AuthMobileState extends State<AuthMobile> {
  // Connexion
  final TextEditingController identifierController      = TextEditingController();
  // Inscription
  final TextEditingController firstNameController       = TextEditingController();
  final TextEditingController lastNameController        = TextEditingController();
  final TextEditingController emailController           = TextEditingController();
  final TextEditingController usernameController        = TextEditingController();
  // Commun
  final TextEditingController passwordController        = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  late bool isLogin;
  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  String errorMessage = '';

  bool get _hasLength  => passwordController.text.length >= 8;
  bool get _hasUpper   => passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLower   => passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit   => passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => passwordController.text.contains(RegExp(r'[!@#$%^&*()\-_=+\[\]{};:,.<>?/\\|~]'));

  @override
  void initState() {
    super.initState();
    isLogin = !widget.initialSignup;
    passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    identifierController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final password = passwordController.text.trim();
    setState(() { isLoading = true; errorMessage = ''; });

    try {
      final auth = context.read<AuthProvider>();
      if (isLogin) {
        final identifier = identifierController.text.trim();
        if (identifier.isEmpty || password.isEmpty) {
          setState(() { errorMessage = 'Veuillez remplir tous les champs.'; isLoading = false; });
          return;
        }
        await auth.signIn(identifier: identifier, password: password);
      } else {
        final email     = emailController.text.trim();
        final username  = usernameController.text.trim();
        final firstName = firstNameController.text.trim();
        final lastName  = lastNameController.text.trim();
        final confirm   = confirmPasswordController.text.trim();

        if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || username.isEmpty || password.isEmpty || confirm.isEmpty) {
          setState(() { errorMessage = 'Veuillez remplir tous les champs.'; isLoading = false; });
          return;
        }
        if (password != confirm) {
          setState(() { errorMessage = 'Les mots de passe ne correspondent pas.'; isLoading = false; });
          return;
        }
        await auth.signUp(
          email: email, password: password, username: username,
          firstName: firstName, lastName: lastName,
        );
      }
      // Retour à la HomePage (landing → dashboard)
      if (mounted) Navigator.pop(context);
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
            child: Column(
              children: [
                // ── Bouton retour ───────────────────────────────────────────
                Align(
                  alignment: Alignment.topLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white54),
                    label: const Text('Retour',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                Expanded(
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
                          Text(isLogin ? 'Connexion' : 'Créer un compte',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(isLogin ? 'Accédez à votre espace sécurisé.' : 'Rejoignez CryptoAdv dès maintenant.',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 24),

                          if (isLogin) ...[
                            _field(controller: identifierController, hint: 'Email ou @username', icon: Icons.person_outline),
                          ] else ...[
                            Row(children: [
                              Expanded(child: _field(controller: firstNameController, hint: 'Prénom', icon: Icons.badge_outlined)),
                              const SizedBox(width: 12),
                              Expanded(child: _field(controller: lastNameController, hint: 'Nom', icon: Icons.badge_outlined)),
                            ]),
                            const SizedBox(height: 14),
                            _field(controller: emailController, hint: 'Email', icon: Icons.email_outlined),
                            const SizedBox(height: 14),
                            _field(controller: usernameController, hint: '@username', icon: Icons.alternate_email),
                          ],

                          const SizedBox(height: 14),
                          _field(
                            controller: passwordController,
                            hint: 'Mot de passe',
                            icon: Icons.lock_outline,
                            obscure: !showPassword,
                            suffix: IconButton(
                              icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
                              onPressed: () => setState(() => showPassword = !showPassword),
                            ),
                          ),

                          if (!isLogin) ...[
                            const SizedBox(height: 10),
                            _passwordStrength(),
                            const SizedBox(height: 14),
                            _field(
                              controller: confirmPasswordController,
                              hint: 'Confirmer le mot de passe',
                              icon: Icons.lock_outline,
                              obscure: !showConfirmPassword,
                              suffix: IconButton(
                                icon: Icon(showConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
                                onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                              ),
                            ),
                          ],

                          if (errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                          const SizedBox(height: 22),
                          _submitBtn(),
                          const SizedBox(height: 18),
                          _socialSection(),
                          const SizedBox(height: 14),
                          Center(child: TextButton(
                            onPressed: () => setState(() { isLogin = !isLogin; errorMessage = ''; }),
                            child: Text(
                              isLogin ? 'Créer un compte' : 'Déjà un compte ?',
                              style: const TextStyle(color: Color(0xFFD1A7FF), fontSize: 14),
                            ),
                          )),
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

  Widget _passwordStrength() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _criterion(_hasLength,  '8 caractères minimum'),
      _criterion(_hasUpper,   '1 majuscule'),
      _criterion(_hasLower,   '1 minuscule'),
      _criterion(_hasDigit,   '1 chiffre'),
      _criterion(_hasSpecial, '1 caractère spécial'),
    ],
  );

  Widget _criterion(bool ok, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 13, color: ok ? Colors.greenAccent : Colors.white38),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: ok ? Colors.greenAccent : Colors.white38, fontSize: 11)),
    ]),
  );

  Widget _glassCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: const Color(0xFF0047AB).withOpacity(0.15),
      border: Border.all(color: Colors.white10),
    ),
    child: child,
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) => TextField(
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
      contentPadding: const EdgeInsets.all(14),
    ),
  );

  Widget _submitBtn() => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: isLoading ? null : submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0047AB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: isLoading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(isLogin ? 'Se connecter' : 'S\'inscrire',
            style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );

  Widget _socialSection() => Column(children: [
    Row(children: [
      const Expanded(child: Divider(color: Colors.white10)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text("OU", style: TextStyle(color: Colors.white24, fontSize: 10))),
      const Expanded(child: Divider(color: Colors.white10)),
    ]),
    const SizedBox(height: 14),
    _socialBtn('Google', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png'),
  ]);

  Widget _socialBtn(String name, String url) => OutlinedButton(
    onPressed: () {},
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Image.network(url, height: 18, errorBuilder: (_, __, ___) => const Icon(Icons.language)),
      const SizedBox(width: 12),
      Text("Continuer avec $name", style: const TextStyle(color: Colors.white, fontSize: 13)),
    ]),
  );
}
