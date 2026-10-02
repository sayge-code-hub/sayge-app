import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.roleId,
    required super.roleCode,
    required super.roleLabel,
    super.name,
    super.employeeId,
  });

  factory UserModel.fromProfileRow(Map<String, dynamic> json) {
    final role = json['roles'];
    final roleMap = role is Map<String, dynamic> ? role : <String, dynamic>{};

    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: (json['full_name'] as String?)?.trim().isNotEmpty == true
          ? (json['full_name'] as String).trim()
          : null,
      roleId: json['role_id'] as String,
      roleCode: (roleMap['code'] as String?) ?? 'employee',
      roleLabel: (roleMap['label'] as String?) ?? 'Employee',
      employeeId: json['employee_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': name,
      'role_id': roleId,
      'role_code': roleCode,
      'role_label': roleLabel,
      'employee_id': employeeId,
    };
  }
}
