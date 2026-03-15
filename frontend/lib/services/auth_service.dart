import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  String? _token;
  int? _userId;
  String? _username;

  String? get token => _token;
  int? get userId => _userId;
  String? get username => _username;

  bool get isAuthenticated => _token != null;

  Future<void> initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    _userId = prefs.getInt('user_id');
    _username = prefs.getString('username');
    notifyListeners();
  }

  Future<bool> login(String baseApiUrl, String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseApiUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _userId = data['user_id'];
        this._username = data['username'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _token!);
        await prefs.setInt('user_id', _userId!);
        await prefs.setString('username', this._username!);

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> register(String baseApiUrl, String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseApiUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
