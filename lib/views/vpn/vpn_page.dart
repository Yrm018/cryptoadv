import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'vpn_desktop.dart';
import 'vpn_mobile.dart';

class VpnPage extends StatelessWidget {
  const VpnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: VpnMobile(),
      desktop: VpnDesktop(),
    );
  }
}
