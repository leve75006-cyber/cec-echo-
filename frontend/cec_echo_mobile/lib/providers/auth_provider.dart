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
      final jsonData = _decodeResponse(response);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', jsonData['token']);

        _user = User.fromJson(jsonData['user']);

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = jsonData['message'] ?? 'Login failed';
      _isLoading = false;
      notifyListeners();
      return false;
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
      final jsonData = _decodeResponse(response);

      if (response.statusCode == 201 && jsonData['success'] == true) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', jsonData['token']);

        _user = User.fromJson(jsonData['user']);

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = jsonData['message'] ?? 'Registration failed';
      _isLoading = false;
      notifyListeners();
      return false;
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

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');

      _user = null;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> tryAutoLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) {
      return false;
    }

    try {
      return await refreshMe();
    } catch (_) {
      return false;
    }
  }

  Future<bool> refreshMe() async {
    try {
      final response = await ApiService.getMe();
      final jsonData = _decodeResponse(response);
      if (response.statusCode == 200 && jsonData['success'] == true) {
        _user = User.fromJson(jsonData['user']);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    String? department,
    String? profilePicture,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.updateMe({
        'firstName': firstName,
        'lastName': lastName,
        'department': department ?? '',
        'profilePicture': profilePicture ?? '',
      });
      final jsonData = _decodeResponse(response);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        final updated = jsonData['user'];
        if (updated is Map<String, dynamic>) {
          _user = User.fromJson(updated);
        } else {
          await refreshMe();
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = jsonData['message'] ?? 'Could not update profile';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      final jsonData = _decodeResponse(response);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        if (jsonData['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', jsonData['token'].toString());
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = jsonData['message'] ?? 'Could not change password';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'message': 'Unexpected server response'};
    } catch (_) {
      final raw = response.body.trim();
      if (raw.isNotEmpty) {
        return {'message': raw};
      }
      return {'message': 'Server error occurred'};
    }
  }
}
