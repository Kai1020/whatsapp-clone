import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'user_search_delegate.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);
    
    // Filter users based on search query
    final users = chatService.users.where((user) {
      if (_searchQuery.isEmpty) return true;
      final username = user['username'].toString().toLowerCase();
      return username.contains(_searchQuery.toLowerCase());
    }).toList();
    
    final selectedId = chatService.selectedUserId;
    final requests = chatService.friendRequests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Messages',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: () {
                      final auth = Provider.of<AuthService>(context, listen: false);
                      final chat = Provider.of<ChatService>(context, listen: false);
                      showSearch(
                        context: context,
                        delegate: UserSearchDelegate(
                          token: auth.token!,
                          onSendRequest: (userId) async {
                            final success = await chat.sendFriendRequest(userId);
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Friend request sent!')),
                              );
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to send request')),
                              );
                            }
                          },
                        ),
                      );
                    },
                    tooltip: 'Find Friends',
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => Provider.of<AuthService>(context, listen: false).logout(),
                    tooltip: 'Logout',
                  ),
                ],
              )
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: Colors.grey),
                hintText: 'Search conversations...',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (requests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text('Friend Requests', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text(req['sender_username'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(req['sender_username']),
                subtitle: const Text('Wants to be friends'),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => chatService.acceptFriendRequest(req['id']),
                ),
              );
            },
          ),
          const Divider(),
        ],
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty 
                        ? 'No users found' 
                        : 'No users matching "$_searchQuery"',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = user['id'] == selectedId;
                    
                    return InkWell(
                      onTap: () => chatService.selectUser(user['id'], user['username']),
                      child: Container(
                        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.primaries[user['id'] % Colors.primaries.length],
                                  child: Text(user['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        user['username'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const Text('1m', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Tap to chat...',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
