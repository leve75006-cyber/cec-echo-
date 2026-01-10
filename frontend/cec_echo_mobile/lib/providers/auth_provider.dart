import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.login(email, password);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['success']) {
          // Save token to shared preferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', jsonData['token']);

          // Set user data
          _user = User.fromJson(jsonData['user']);

          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage = jsonData['message'] ?? 'Login failed';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        _errorMessage = 'Server error occurred';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.register(userData);

      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['success']) {
          // Save token to shared preferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', jsonData['token']);

          // Set user data
          _user = User.fromJson(jsonData['user']);

          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage = jsonData['message'] ?? 'Registration failed';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        _errorMessage = 'Server error occurred';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.logout();

      // Clear token from shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');

      _user = null;
      notifyListeners();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  Future<bool> tryAutoLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) {
      return false;
    }

    try {
      final response = await ApiService.getMe();

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['success']) {
          _user = User.fromJson(jsonData['user']);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Auto login error: $e');
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
