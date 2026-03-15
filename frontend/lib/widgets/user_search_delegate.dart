import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class UserSearchDelegate extends SearchDelegate {
  final String token;
  final Function(int) onSendRequest;

  UserSearchDelegate({required this.token, required this.onSendRequest});

  Future<List<dynamic>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response = await http.get(
        Uri.parse('${Config.apiUrl}/users/search?q=$query'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Search error: $e');
    }
    return [];
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) {
      return const Center(child: Text('Type at least 2 characters to search'));
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<dynamic>>(
      future: searchUsers(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return const Center(child: Text('Error searching developers'));
        }
        
        final users = snapshot.data ?? [];
        
        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }
        
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final status = user['status']; // 'none', 'friends', 'request_sent'
            
            Widget trailing;
            if (status == 'friends') {
              trailing = const Icon(Icons.check_circle, color: Colors.green);
            } else if (status == 'request_sent') {
              trailing = const Text('Pending', style: TextStyle(color: Colors.grey));
            } else {
              trailing = IconButton(
                icon: const Icon(Icons.person_add, color: Colors.blue),
                onPressed: () {
                  onSendRequest(user['id']);
                  close(context, null);
                  // Allow the actual sendRequest to show a snackbar in the caller
                },
              );
            }
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.primaries[user['id'] % Colors.primaries.length],
                child: Text(user['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
              title: Text(user['username']),
              trailing: trailing,
            );
          },
        );
      },
    );
  }
}
