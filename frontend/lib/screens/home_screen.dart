import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/chat_area.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) => ChatService(auth.token!, auth.userId!),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            bool isWide = constraints.maxWidth > 750;
            return isWide ? _buildSplitView() : _buildMobileView();
          },
        ),
      ),
    );
  }

  Widget _buildSplitView() {
    return const Row(
      children: [
        SizedBox(
          width: 340,
          child: Sidebar(),
        ),
        VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: ChatArea(),
        ),
      ],
    );
  }

  Widget _buildMobileView() {
    return Consumer<ChatService>(
      builder: (context, chatService, child) {
        if (chatService.selectedUserId != null) {
          return const ChatArea(isMobile: true);
        }
        return const SafeArea(child: Sidebar());
      },
    );
  }
}
