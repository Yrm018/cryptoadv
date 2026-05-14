import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'documentation_desktop.dart';
import 'documentation_mobile.dart';

class DocumentationPage extends StatelessWidget {
  const DocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: DocumentationMobile(),
      desktop: DocumentationDesktop(),
    );
  }
}
