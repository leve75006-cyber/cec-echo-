import 'package:cec_echo_mobile/models/user.dart';

class Message {
  final String id;
  final User? sender;
  final User? receiver;
  final String? groupId;
  final String content;
  final String messageType;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final bool isRead;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
    this.sender,
    this.receiver,
    this.groupId,
    required this.content,
    this.messageType = 'text',
    this.fileUrl,
    this.fileName,
    this.fileSize,
    required this.isRead,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? json['id'],
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      receiver: json['receiver'] != null ? User.fromJson(json['receiver']) : null,
      groupId: json['groupId'],
      content: json['content'],
      messageType: json['messageType'] ?? 'text',
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      isRead: json['isRead'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class Group {
  final String id;
  final String name;
  final String? description;
  final User creator;
  final List<GroupMember> members;
  final List<String> admins;
  final bool isPrivate;
  final String? avatar;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.creator,
    required this.members,
    required this.admins,
    required this.isPrivate,
    this.avatar,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      description: json['description'],
      creator: User.fromJson(json['creator']),
      members: json['members'] != null
          ? List<GroupMember>.from(json['members'].map((member) => GroupMember.fromJson(member)))
          : [],
      admins: List<String>.from(json['admins']),
      isPrivate: json['isPrivate'] ?? false,
      avatar: json['avatar'],
    );
  }
}

class GroupMember {
  final User user;
  final String role;
  final DateTime joinedAt;

  GroupMember({
    required this.user,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      user: User.fromJson(json['user']),
      role: json['role'] ?? 'member',
      joinedAt: DateTime.parse(json['joinedAt']),
    );
  }
}
