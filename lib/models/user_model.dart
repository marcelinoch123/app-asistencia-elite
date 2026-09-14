class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String department;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.department = 'General',
    this.phone,
    this.isActive = true,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      fullName: map['full_name'] ?? map['name'] ?? 'Usuario',
      role: map['role'] ?? 'employee',
      department: map['department'] ?? 'General',
      phone: map['phone'],
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'name': fullName,
      'role': role,
      'department': department,
      'phone': phone,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';
  
  String get roleDisplay {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'employee':
        return 'Empleado';
      default:
        return role;
    }
  }
}