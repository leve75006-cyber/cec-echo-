import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _configuredHost = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String _normalizeHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  static String get _host {
    if (_configuredHost.trim().isNotEmpty) {
      return _normalizeHost(_configuredHost);
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5000';
      default:
        return 'http://127.0.0.1:5000';
    }
  }

  static String get baseUrl => '${_normalizeHost(_host)}/api';
  static String get wsUrl =>
      _host.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');

  // Get JWT token from shared preferences
  static Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Generic method to make authenticated requests
  static Future<Map<String, String>> getAuthHeaders() async {
    String? token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Authentication APIs
  static Future<http.Response> register(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userData),
    );
    return response;
  }

  static Future<http.Response> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return response;
  }

  static Future<http.Response> logout() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/auth/logout'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> getMe() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> updateMe(Map<String, dynamic> payload) async {
    final headers = await getAuthHeaders();
    return http.put(
      Uri.parse('$baseUrl/auth/me'),
      headers: headers,
      body: jsonEncode(payload),
    );
  }

  static Future<http.Response> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = await getAuthHeaders();
    return http.put(
      Uri.parse('$baseUrl/auth/password'),
      headers: headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
  }

  // User APIs
  static Future<http.Response> getUsers() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> getUser(String userId) async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: headers,
    );
    return response;
  }

  // Announcement APIs
  static Future<http.Response> getAnnouncements() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/announcements'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> getAnnouncement(String announcementId) async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/announcements/$announcementId'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> createAnnouncement(
    Map<String, dynamic> announcementData,
  ) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/announcements'),
      headers: headers,
      body: jsonEncode(announcementData),
    );
    return response;
  }

  static Future<http.Response> likeAnnouncement(String announcementId) async {
    final headers = await getAuthHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/announcements/like/$announcementId'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> addComment(
    String announcementId,
    String content,
  ) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/announcements/comment/$announcementId'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );
    return response;
  }

  // Chat APIs
  static Future<http.Response> getMessages() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/messages'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> getDirectMessages(String userId) async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/messages/$userId'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> getGroupMessages(String groupId) async {
    final headers = await getAuthHeaders();
    return http.get(
      Uri.parse('$baseUrl/chat/messages/group/$groupId'),
      headers: headers,
    );
  }

  static Future<http.Response> sendMessage(
    Map<String, dynamic> messageData,
  ) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/messages'),
      headers: headers,
      body: jsonEncode(messageData),
    );
    return response;
  }

  static Future<http.Response> getGroups() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/groups'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> createGroup(
    Map<String, dynamic> groupData,
  ) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/groups'),
      headers: headers,
      body: jsonEncode(groupData),
    );
    return response;
  }

  static Future<http.Response> addGroupMember(
    String groupId,
    Map<String, dynamic> payload,
  ) async {
    final headers = await getAuthHeaders();
    return http.put(
      Uri.parse('$baseUrl/chat/groups/add-member/$groupId'),
      headers: headers,
      body: jsonEncode(payload),
    );
  }

  // Student APIs
  static Future<http.Response> getStudentAnnouncements() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/student/announcements'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> getStudentDashboard() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/student/dashboard'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> getStudentProfile() async {
    final headers = await getAuthHeaders();
    return http.get(
      Uri.parse('$baseUrl/student/profile'),
      headers: headers,
    );
  }

  static Future<http.Response> getStudentUsers() async {
    final headers = await getAuthHeaders();
    return http.get(
      Uri.parse('$baseUrl/student/users'),
      headers: headers,
    );
  }

  static Future<http.Response> getUnreadMessagesCount() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/student/unread-count'),
      headers: headers,
    );
    return response;
  }

  static Future<http.Response> getStudyMaterials(String courseCode) async {
    final headers = await getAuthHeaders();
    return http.get(
      Uri.parse('$baseUrl/student/study-materials/$courseCode'),
      headers: headers,
    );
  }

  static Future<http.Response> createStudyMaterial(
    Map<String, dynamic> payload,
  ) async {
    final headers = await getAuthHeaders();
    return http.post(
      Uri.parse('$baseUrl/student/study-materials'),
      headers: headers,
      body: jsonEncode(payload),
    );
  }

  // Chatbot APIs
  static Future<http.Response> getChatbotResponse(String query) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chatbot/query'),
      headers: headers,
      body: jsonEncode({'query': query}),
    );
    return response;
  }

  static Future<http.Response> getAdvancedChatbotResponse(String query) async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chatbot/advanced-query'),
      headers: headers,
      body: jsonEncode({'query': query}),
    );
    return response;
  }

  static Future<http.Response> getExamTopics(String subject) async {
    final headers = await getAuthHeaders();
    return http.post(
      Uri.parse('$baseUrl/chatbot/exam-topics'),
      headers: headers,
      body: jsonEncode({'subject': subject}),
    );
  }

  // Admin APIs
  static Future<http.Response> getAdminDashboard() async {
    final headers = await getAuthHeaders();
    return http.get(
      Uri.parse('$baseUrl/admin/dashboard'),
      headers: headers,
    );
  }

  static Future<http.Response> getAdminUsers() async {
    final headers = await getAuthHeaders();
    return http.get(
      Uri.parse('$baseUrl/admin/users?limit=200&page=1'),
      headers: headers,
    );
  }

  static Future<http.Response> createFaculty(Map<String, dynamic> payload) async {
    final headers = await getAuthHeaders();
    return http.post(
      Uri.parse('$baseUrl/admin/faculty'),
      headers: headers,
      body: jsonEncode(payload),
    );
  }

  static Future<http.Response> deleteFaculty(String userId) async {
    final headers = await getAuthHeaders();
    return http.delete(
      Uri.parse('$baseUrl/admin/faculty/$userId'),
      headers: headers,
    );
  }

  static Future<http.Response> deleteStudentByRegNo(String registrationNumber) async {
    final headers = await getAuthHeaders();
    return http.delete(
      Uri.parse('$baseUrl/admin/students/by-reg/$registrationNumber'),
      headers: headers,
    );
  }

  static Future<http.Response> cleanupExpiredCecAssembleStudents() async {
    final headers = await getAuthHeaders();
    return http.post(
      Uri.parse('$baseUrl/admin/groups/cec-assemble/cleanup'),
      headers: headers,
    );
  }
}
