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
    super.avatarPath,
    super.avatarUrl,
  });

  factory UserModel.fromProfileRow(
    Map<String, dynamic> json, {
    String? avatarUrl,
  }) {
    final role = json['roles'];
    final roleMap = role is Map<String, dynamic> ? role : <String, dynamic>{};
    final path = (json['avatar_path'] ?? '').toString().trim();

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
      avatarPath: path.isEmpty ? null : path,
      avatarUrl: avatarUrl?.trim().isNotEmpty == true ? avatarUrl!.trim() : null,
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
      'avatar_path': avatarPath,
      'avatar_url': avatarUrl,
    };
  }

  Map<String, dynamic> toStorageJson() => toJson();

  factory UserModel.fromStorage(Map<String, dynamic> json) {
    final path = (json['avatar_path'] ?? '').toString().trim();
    final url = (json['avatar_url'] ?? '').toString().trim();
    return UserModel(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['full_name'] as String?)?.trim().isNotEmpty == true
          ? (json['full_name'] as String).trim()
          : null,
      roleId: (json['role_id'] ?? '').toString(),
      roleCode: (json['role_code'] as String?) ?? 'employee',
      roleLabel: (json['role_label'] as String?) ?? 'Employee',
      employeeId: json['employee_id'] as String?,
      avatarPath: path.isEmpty ? null : path,
      avatarUrl: url.isEmpty ? null : url,
    );
  }

  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      roleId: user.roleId,
      roleCode: user.roleCode,
      roleLabel: user.roleLabel,
      name: user.name,
      employeeId: user.employeeId,
      avatarPath: user.avatarPath,
      avatarUrl: user.avatarUrl,
    );
  }
}
