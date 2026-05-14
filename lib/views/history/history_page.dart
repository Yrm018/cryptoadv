import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'history_desktop.dart';
import 'history_mobile.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: HistoryMobile(),
      desktop: HistoryDesktop(),
    );
  }
}
