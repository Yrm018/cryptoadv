import 'package:flutter/material.dart';
import '../../widgets/common/responsive.dart';
import 'chat_desktop.dart';
import 'chat_mobile.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: ChatMobile(),
      desktop: ChatDesktop(),
    );
  }
}
