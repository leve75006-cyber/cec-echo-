import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'http://10.0.2.2:5000/api'; // Use 10.0.2.2 for Android emulator to reach localhost
  static const String wsUrl =
      'ws://10.0.2.2:5000'; // WebSocket URL for Socket.IO

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

  static Future<http.Response> getUnreadMessagesCount() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/student/unread-count'),
      headers: headers,
    );
    return response;
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
}
