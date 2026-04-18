class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String role; // 'admin' or 'customer'

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    required this.role,
  });

  String get displayName {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final localPart = email.split('@').first.trim();
    return localPart.isEmpty ? email : localPart;
  }

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] as String?,
      role: data['role'] ?? 'customer',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name ?? '',
      'role': role,
    };
  }
}
