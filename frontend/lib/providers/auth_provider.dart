import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  String? _userToken;
  bool _isLoading = true;

  String? get userToken => _userToken;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userToken = prefs.getString('userToken');
    } catch (e) {
      debugPrint('Failed to load auth token: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String token) async {
    _userToken = token;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userToken', token);
    } catch (e) {
      debugPrint('Failed to save auth token: $e');
    }
  }

  Future<void> logout() async {
    _userToken = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userToken');
    } catch (e) {
      debugPrint('Failed to remove auth token: $e');
    }
  }
}
