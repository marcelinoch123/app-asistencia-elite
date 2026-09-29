class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String department;
  final String? phone;
  final String? address;
  final String? photoUrl;
  final String? clientId;
  final String? service;
  final String employeeType;
  final bool isActive;
  final DateTime createdAt;
  final String? ci;
  final String? contractUrl;
  final String? contractFilename;
  final String status;
  final DateTime? terminationDate;
  final String? terminationReason;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.department = 'General',
    this.phone,
    this.address,
    this.photoUrl,
    this.clientId,
    this.service,
    this.employeeType = 'field',
    this.isActive = true,
    required this.createdAt,
    this.ci,
    this.contractUrl,
    this.contractFilename,
    this.status = 'active',
    this.terminationDate,
    this.terminationReason,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final statusVal = map['status']?.toString() ??
        ((map['is_active'] == false) ? 'inactive' : 'active');

    return UserModel(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? map['name']?.toString() ?? 'Usuario',
      role: map['role']?.toString() ?? 'employee',
      department: map['department']?.toString() ?? 'General',
      phone: map['phone']?.toString(),
      address: map['address']?.toString(),
      photoUrl: map['photo_url']?.toString(),
      clientId: map['client_id']?.toString(),
      service: map['service']?.toString(),
      employeeType: map['employee_type']?.toString() ?? 'field',
      isActive: statusVal == 'active',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      ci: map['ci']?.toString(),
      contractUrl: map['contract_url']?.toString(),
      contractFilename: map['contract_filename']?.toString(),
      status: statusVal,
      terminationDate: map['termination_date'] != null
          ? DateTime.tryParse(map['termination_date'].toString())
          : null,
      terminationReason: map['termination_reason']?.toString(),
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
      'address': address,
      'photo_url': photoUrl,
      'client_id': clientId,
      'service': service,
      'employee_type': employeeType,
      'is_active': status == 'active',
      'created_at': createdAt.toIso8601String(),
      'ci': ci,
      'contract_url': contractUrl,
      'contract_filename': contractFilename,
      'status': status,
      'termination_date': terminationDate?.toIso8601String(),
      'termination_reason': terminationReason,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';
  bool get isField => employeeType == 'field';
  bool get isOffice => employeeType == 'office';

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