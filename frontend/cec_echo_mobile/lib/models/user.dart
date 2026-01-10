class User {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? department;
  final String? registrationNumber;
  final bool isActive;
  final String? profilePicture;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.department,
    this.registrationNumber,
    required this.isActive,
    this.profilePicture,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      username: json['username'],
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      role: json['role'],
      department: json['department'],
      registrationNumber: json['registrationNumber'],
      isActive: json['isActive'] ?? true,
      profilePicture: json['profilePicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'department': department,
      'registrationNumber': registrationNumber,
      'isActive': isActive,
      'profilePicture': profilePicture,
    };
  }
}