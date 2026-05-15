import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/backround.dart';
import '../../components/logo.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class AuthDesktop extends StatefulWidget {
  const AuthDesktop({super.key});

  @override
  State<AuthDesktop> createState() => _AuthDesktopState();
}

class _AuthDesktopState extends State<AuthDesktop> {
  final TextEditingController identifierController      = TextEditingController();
  final TextEditingController firstNameController       = TextEditingController();
  final TextEditingController lastNameController        = TextEditingController();
  final TextEditingController emailController           = TextEditingController();
  final TextEditingController usernameController        = TextEditingController();
  final TextEditingController passwordController        = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLogin = true;
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          const CryptoBackground(),
          Row(
            children: [
              // ── Panneau gauche — Logo ─────────────────────────────────────
              Expanded(
                flex: 4,
                child: Container(
                  color: Colors.black.withOpacity(0.25),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedLogo(size: LogoSize.lg),
                      const SizedBox(height: 24),
                      const Text(
                        'Cryptographie & Sécurité',
                        style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60, height: 2,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF7AA6FF), Color(0xFFD1A7FF)]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Panneau droit — Formulaire ────────────────────────────────
              Expanded(
                flex: 6,
                child: Container(
                  height: size.height,
                  color: const Color(0xFF050D1F).withOpacity(0.75),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: size.height - 64),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLogin ? 'Connexion' : 'Créer un compte',
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isLogin
                              ? 'Connectez-vous pour accéder à CryptoAdv.'
                              : 'Créez un compte pour sauvegarder votre historique.',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          ),
                          const SizedBox(height: 28),

                          // ── Champs ──────────────────────────────────────
                          if (isLogin) ...[
                            _label('Email ou nom d\'utilisateur'),
                            const SizedBox(height: 8),
                            _field(controller: identifierController, hint: 'Email ou @username...', icon: Icons.person_outline),
                          ] else ...[
                            Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _label('Prénom'),
                                const SizedBox(height: 8),
                                _field(controller: firstNameController, hint: 'Prénom...', icon: Icons.badge_outlined),
                              ])),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _label('Nom'),
                                const SizedBox(height: 8),
                                _field(controller: lastNameController, hint: 'Nom...', icon: Icons.badge_outlined),
                              ])),
                            ]),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _label('Email'),
                                const SizedBox(height: 8),
                                _field(controller: emailController, hint: 'Email...', icon: Icons.email_outlined),
                              ])),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _label('Nom d\'utilisateur'),
                                const SizedBox(height: 8),
                                _field(controller: usernameController, hint: '@username...', icon: Icons.alternate_email),
                              ])),
                            ]),
                          ],

                          const SizedBox(height: 14),
                          _label('Mot de passe'),
                          const SizedBox(height: 8),
                          _field(
                            controller: passwordController,
                            hint: 'Mot de passe...',
                            icon: Icons.lock_outline,
                            obscure: !showPassword,
                            suffix: IconButton(
                              onPressed: () => setState(() => showPassword = !showPassword),
                              icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 20),
                            ),
                          ),

                          if (!isLogin) ...[
                            const SizedBox(height: 10),
                            _strengthRow(),
                            const SizedBox(height: 14),
                            _label('Confirmer le mot de passe'),
                            const SizedBox(height: 8),
                            _field(
                              controller: confirmPasswordController,
                              hint: 'Confirmez...',
                              icon: Icons.lock_outline,
                              obscure: !showConfirmPassword,
                              suffix: IconButton(
                                onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                                icon: Icon(showConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 20),
                              ),
                            ),
                          ],

                          if (errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.red.withOpacity(0.15),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                            ),
                          ],

                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0047AB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(isLogin ? 'Se connecter' : 'S\'inscrire',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ),

                          const SizedBox(height: 20),
                          Row(children: [
                            const Expanded(child: Divider(color: Colors.white10)),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text('OU', style: TextStyle(color: Colors.white38, fontSize: 11))),
                            const Expanded(child: Divider(color: Colors.white10)),
                          ]),
                          const SizedBox(height: 16),
                          _socialBtn('Google', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png'),
                          const SizedBox(height: 10),
                          _socialBtn('GitHub', 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/Octicons-mark-github.svg/1200px-Octicons-mark-github.svg.png'),
                          const SizedBox(height: 16),
                          Center(child: TextButton(
                            onPressed: () => setState(() { isLogin = !isLogin; errorMessage = ''; }),
                            child: Text(
                              isLogin ? 'Pas encore de compte ? S\'inscrire' : 'Déjà un compte ? Se connecter',
                              style: const TextStyle(color: Color(0xFFD1A7FF), fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Indicateurs de force en ligne (2 colonnes) ─────────────────────────────
  Widget _strengthRow() => Row(
    children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _criterion(_hasLength,  '8 caractères min.'),
        _criterion(_hasUpper,   '1 majuscule'),
        _criterion(_hasSpecial, '1 caractère spécial'),
      ])),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _criterion(_hasLower,  '1 minuscule'),
        _criterion(_hasDigit, '1 chiffre'),
      ])),
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

  Widget _label(String text) => Text(text,
    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13));

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
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
      prefixIcon: Icon(icon, color: Colors.white54, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
    ),
  );

  Widget _socialBtn(String label, String url) => SizedBox(
    width: double.infinity,
    height: 46,
    child: OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.network(url, height: 20, errorBuilder: (_, __, ___) => const Icon(Icons.language, color: Colors.white54)),
        const SizedBox(width: 12),
        Text('Continuer avec $label', style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    ),
  );
}
