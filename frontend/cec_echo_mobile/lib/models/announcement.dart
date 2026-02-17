import 'package:cec_echo_mobile/models/user.dart';

User _fallbackUser(String id) {
  return User(
    id: id,
    username: 'user',
    email: '',
    firstName: 'User',
    lastName: '',
    role: 'student',
    isActive: true,
  );
}

class Announcement {
  final String id;
  final String title;
  final String content;
  final User author;
  final String category;
  final String priority;
  final List<String> targetAudience;
  final String? department;
  final List<dynamic>? attachments;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final List<User> viewers;
  final List<User> likes;
  final List<Comment> comments;
  final DateTime createdAt;
  final DateTime updatedAt;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.category,
    required this.priority,
    required this.targetAudience,
    this.department,
    this.attachments,
    required this.isPublished,
    this.publishedAt,
    this.expiresAt,
    required this.viewers,
    required this.likes,
    required this.comments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final authorRaw = json['author'];
    final viewerRaw = json['viewers'] as List<dynamic>? ?? [];
    final likesRaw = json['likes'] as List<dynamic>? ?? [];
    final commentsRaw = json['comments'] as List<dynamic>? ?? [];

    return Announcement(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      content: json['content'],
      author: authorRaw is Map<String, dynamic>
          ? User.fromJson(authorRaw)
          : _fallbackUser(authorRaw?.toString() ?? ''),
      category: (json['category'] ?? 'general').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      targetAudience: List<String>.from(json['targetAudience'] ?? const ['all']),
      department: json['department'],
      attachments: json['attachments'],
      isPublished: json['isPublished'] ?? true,
      publishedAt: json['publishedAt'] != null ? DateTime.parse(json['publishedAt']) : null,
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      viewers: viewerRaw
          .map((user) => user is Map<String, dynamic> ? User.fromJson(user) : _fallbackUser(user.toString()))
          .toList(),
      likes: likesRaw
          .map((user) => user is Map<String, dynamic> ? User.fromJson(user) : _fallbackUser(user.toString()))
          .toList(),
      comments: commentsRaw
          .whereType<Map<String, dynamic>>()
          .map(Comment.fromJson)
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class Comment {
  final String id;
  final User user;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.user,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    return Comment(
      id: json['_id'] ?? json['id'],
      user: userRaw is Map<String, dynamic>
          ? User.fromJson(userRaw)
          : _fallbackUser(userRaw?.toString() ?? ''),
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
