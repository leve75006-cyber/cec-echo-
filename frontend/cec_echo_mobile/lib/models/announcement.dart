import 'package:cec_echo_mobile/models/user.dart';

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
    return Announcement(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      content: json['content'],
      author: User.fromJson(json['author']),
      category: json['category'],
      priority: json['priority'],
      targetAudience: List<String>.from(json['targetAudience']),
      department: json['department'],
      attachments: json['attachments'],
      isPublished: json['isPublished'],
      publishedAt: json['publishedAt'] != null ? DateTime.parse(json['publishedAt']) : null,
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      viewers: json['viewers'] != null
          ? List<User>.from(json['viewers'].map((user) => User.fromJson(user)))
          : [],
      likes: json['likes'] != null
          ? List<User>.from(json['likes'].map((user) => User.fromJson(user)))
          : [],
      comments: json['comments'] != null
          ? List<Comment>.from(json['comments'].map((comment) => Comment.fromJson(comment)))
          : [],
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
    return Comment(
      id: json['_id'] ?? json['id'],
      user: User.fromJson(json['user']),
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}