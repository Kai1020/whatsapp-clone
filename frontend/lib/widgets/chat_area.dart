import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';

class ChatArea extends StatefulWidget {
  final bool isMobile;
  const ChatArea({super.key, this.isMobile = false});

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.sendMessage(_messageController.text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null || isoTime.length < 16) return 'Now';
    // Extracts HH:mm from 2026-03-15T13:05:04.123
    return isoTime.substring(11, 16);
  }

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (chatService.selectedUserId == null) {
      return const Center(
        child: Text('Select a conversation to start chatting', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    final messages = chatService.getMessagesFor(chatService.selectedUserId!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Column(
      children: [
        // Top Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
             border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: SafeArea(
            bottom: false,
            top: widget.isMobile,
            child: Row(
              children: [
                if (widget.isMobile) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => chatService.selectUser(-1, ''), 
                  ),
                  const SizedBox(width: 8),
                ],
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.primaries[chatService.selectedUserId! % Colors.primaries.length],
                      child: Text(chatService.selectedUsername![0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chatService.selectedUsername!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Text('Active now', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
                IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () {}),
              ],
            ),
          ),
        ),
        
        // Chat History
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isMe = msg['sender_id'] == authService.userId;
              final timeStr = _formatTime(msg['timestamp']);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.primaries[msg['sender_id'] % Colors.primaries.length],
                        child: Text(chatService.selectedUsername![0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF007AFF) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              msg['content'],
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.done_all, size: 14, color: Colors.blue),
                              ]
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Input Area
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                const Icon(Icons.sentiment_satisfied_alt, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.attach_file, color: Colors.grey),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF007AFF)),
                  onPressed: _sendMessage,
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
