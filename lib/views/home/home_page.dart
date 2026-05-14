import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'home_desktop.dart';
import 'home_mobile.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: HomeMobile(),
      desktop: HomeDesktop(),
    );
  }
}
