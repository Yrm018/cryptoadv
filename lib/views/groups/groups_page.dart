import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'groups_desktop.dart';
import 'groups_mobile.dart';

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile:  GroupsMobile(),
      desktop: GroupsDesktop(),
    );
  }
}
