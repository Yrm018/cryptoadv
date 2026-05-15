import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'auth_desktop.dart';
import 'auth_mobile.dart';

class AuthPage extends StatelessWidget {
  /// Si true, ouvre directement l'onglet inscription.
  final bool initialSignup;
  const AuthPage({super.key, this.initialSignup = false});

  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: AuthMobile(initialSignup: initialSignup),
      desktop: AuthDesktop(initialSignup: initialSignup),
    );
  }
}
