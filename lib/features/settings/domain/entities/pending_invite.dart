import 'package:equatable/equatable.dart';

class PendingInvite extends Equatable {
  const PendingInvite({
    required this.id,
    required this.email,
    this.fullName = '',
    this.invitedAt,
  });

  final String id;
  final String email;
  final String fullName;
  final DateTime? invitedAt;

  @override
  List<Object?> get props => [id, email, fullName, invitedAt];
}
