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
  });

  final String id;
  final String email;
  final String roleId;
  final String roleCode;
  final String roleLabel;
  final String? name;
  final String? employeeId;

  @override
  List<Object?> get props => [
        id,
        email,
        roleId,
        roleCode,
        roleLabel,
        name,
        employeeId,
      ];
}
