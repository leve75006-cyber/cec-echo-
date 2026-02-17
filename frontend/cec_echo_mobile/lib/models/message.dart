import 'package:cec_echo_mobile/models/user.dart';

User? _userFromDynamic(dynamic value) {
  if (value is Map<String, dynamic>) {
    return User.fromJson(value);
  }
  if (value is String) {
    return User(
      id: value,
      username: 'user',
      email: '',
      firstName: 'User',
      lastName: '',
      role: 'student',
      isActive: true,
    );
  }
  return null;
}

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
    final group = json['groupId'];
    return Message(
      id: json['_id'] ?? json['id'],
      sender: _userFromDynamic(json['sender']),
      receiver: _userFromDynamic(json['receiver']),
      groupId: group is Map<String, dynamic> ? (group['_id'] ?? group['id'])?.toString() : group?.toString(),
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
    final creatorRaw = json['creator'];
    return Group(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      description: json['description'],
      creator: creatorRaw is Map<String, dynamic>
          ? User.fromJson(creatorRaw)
          : User(
              id: creatorRaw?.toString() ?? '',
              username: 'creator',
              email: '',
              firstName: 'Creator',
              lastName: '',
              role: 'student',
              isActive: true,
            ),
      members: json['members'] != null
          ? List<GroupMember>.from(json['members'].map((member) => GroupMember.fromJson(member)))
          : [],
      admins: List<String>.from(json['admins'] ?? []),
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
    final userRaw = json['user'];
    return GroupMember(
      user: userRaw is Map<String, dynamic>
          ? User.fromJson(userRaw)
          : User(
              id: userRaw?.toString() ?? '',
              username: 'member',
              email: '',
              firstName: 'Member',
              lastName: '',
              role: 'student',
              isActive: true,
            ),
      role: json['role'] ?? 'member',
      joinedAt: DateTime.tryParse((json['joinedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
