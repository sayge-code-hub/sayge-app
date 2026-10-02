part of 'roles_bloc.dart';

enum RolesStatus { initial, loading, ready, failure }

class RolesState extends Equatable {
  const RolesState({
    this.status = RolesStatus.initial,
    this.roles = const [],
    this.errorMessage,
  });

  final RolesStatus status;
  final List<AppRole> roles;
  final String? errorMessage;

  RolesState copyWith({
    RolesStatus? status,
    List<AppRole>? roles,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RolesState(
      status: status ?? this.status,
      roles: roles ?? this.roles,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, roles, errorMessage];
}
