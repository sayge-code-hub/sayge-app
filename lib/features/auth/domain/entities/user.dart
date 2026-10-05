import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.roleId,
    required this.roleCode,
    required this.roleLabel,
    this.name,
    this.employeeId,
    this.avatarPath,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String roleId;
  final String roleCode;
  final String roleLabel;
  final String? name;
  final String? employeeId;

  /// Storage object path in the `user-avatars` bucket.
  final String? avatarPath;

  /// Resolved public URL for [avatarPath], when available.
  final String? avatarUrl;

  bool get hasAvatar {
    final url = avatarUrl?.trim() ?? '';
    final path = avatarPath?.trim() ?? '';
    return url.isNotEmpty || path.isNotEmpty;
  }

  User copyWith({
    String? id,
    String? email,
    String? roleId,
    String? roleCode,
    String? roleLabel,
    String? name,
    String? employeeId,
    String? avatarPath,
    String? avatarUrl,
    bool clearAvatar = false,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      roleId: roleId ?? this.roleId,
      roleCode: roleCode ?? this.roleCode,
      roleLabel: roleLabel ?? this.roleLabel,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        roleId,
        roleCode,
        roleLabel,
        name,
        employeeId,
        avatarPath,
        avatarUrl,
      ];
}
