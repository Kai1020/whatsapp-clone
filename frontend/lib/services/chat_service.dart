import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';

class ChatService with ChangeNotifier {
  IO.Socket? _socket;
  final String _token;
  final int _currentUserId;

  List<dynamic> _users = [];
  List<dynamic> get users => _users;

  int? _selectedUserId;
  int? get selectedUserId => _selectedUserId;
  String? _selectedUsername;
  String? get selectedUsername => _selectedUsername;

  final Map<int, List<dynamic>> _messages = {};
  
  List<dynamic> _friendRequests = [];
  List<dynamic> get friendRequests => _friendRequests;

  ChatService(this._token, this._currentUserId) {
    _initSocket();
    fetchUsers();
  }

  List<dynamic> getMessagesFor(int userId) {
    return _messages[userId] ?? [];
  }

  void selectUser(int? id, String username) {
    if (id == null || id == -1) {
      _selectedUserId = null;
      _selectedUsername = null;
    } else {
      _selectedUserId = id;
      _selectedUsername = username;
      if (!_messages.containsKey(id)) {
        fetchMessages(id);
      }
    }
    notifyListeners();
  }

  void _initSocket() {
    _socket = IO.io(Config.serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket?.onConnect((_) {
      print('Connected to Socket.IO');
      _socket?.emit('authenticate', {'user_id': _currentUserId});
    });

    _socket?.on('receive_message', (data) {
      _handleNewMessage(data);
    });

    _socket?.on('message_sent', (data) {
      _handleNewMessage(data);
    });
  }

  void _handleNewMessage(dynamic msg) {
    int senderId = msg['sender_id'];
    int receiverId = msg['receiver_id'];
    
    int otherUserId = senderId == _currentUserId ? receiverId : senderId;
    
    if (!_messages.containsKey(otherUserId)) {
      _messages[otherUserId] = [];
    }
    
    if (!(_messages[otherUserId]!.any((m) => m['id'] == msg['id']))) {
      _messages[otherUserId]!.add(msg);
      notifyListeners();
    }
  }

  Future<void> fetchUsers() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiUrl}/users'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        _users = jsonDecode(response.body);
        notifyListeners();
      }
      
      // Also fetch pending requests
      fetchFriendRequests();
    } catch (e) {
      print('Fetch users error: $e');
    }
  }

  Future<void> fetchFriendRequests() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiUrl}/friends/requests'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        _friendRequests = jsonDecode(response.body);
        notifyListeners();
      }
    } catch (e) {
      print('Fetch requests error: $e');
    }
  }

  Future<bool> sendFriendRequest(int targetUserId) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.apiUrl}/friends/request'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'target_user_id': targetUserId}),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Send request error: $e');
      return false;
    }
  }

  Future<bool> acceptFriendRequest(int requestId) async {
    try {
      final response = await http.post(
        Uri.parse('${Config.apiUrl}/friends/accept'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'request_id': requestId}),
      );
      if (response.statusCode == 200) {
        // Refresh users (friends list) and requests
        fetchUsers();
        return true;
      }
      return false;
    } catch (e) {
      print('Accept request error: $e');
      return false;
    }
  }

  Future<void> fetchMessages(int otherUserId) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiUrl}/messages/$otherUserId'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        _messages[otherUserId] = jsonDecode(response.body);
        notifyListeners();
      }
    } catch (e) {
      print('Fetch messages error: $e');
    }
  }

  void sendMessage(String content) {
    if (_selectedUserId == null || content.trim().isEmpty) return;

    _socket?.emit('send_message', {
      'sender_id': _currentUserId,
      'receiver_id': _selectedUserId,
      'content': content.trim(),
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
