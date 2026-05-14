import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'hachage_desktop.dart';
import 'hachage_mobile.dart';

class HachagePage extends StatelessWidget {
  const HachagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: HachageMobile(),
      desktop: HachageDesktop(),
    );
  }
}
