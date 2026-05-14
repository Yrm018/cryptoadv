import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'mdp_desktop.dart';
import 'mdp_mobile.dart';

class MdpPage extends StatelessWidget {
  const MdpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: MdpMobile(),
      desktop: MdpDesktop(),
    );
  }
}
