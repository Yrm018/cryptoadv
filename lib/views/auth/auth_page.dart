import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'auth_desktop.dart';
import 'auth_mobile.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: AuthMobile(),
      desktop: AuthDesktop(),
    );
  }
}
