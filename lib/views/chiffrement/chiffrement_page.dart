import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'chiffrement_desktop.dart';
import 'chiffrement_mobile.dart';

class ChiffrementPage extends StatelessWidget {
  const ChiffrementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: ChiffrementMobile(),
      desktop: ChiffrementDesktop(),
    );
  }
}
