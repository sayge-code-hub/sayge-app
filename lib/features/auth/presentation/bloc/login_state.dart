part of 'login_bloc.dart';

enum LoginStatus { initial, loading, success, failure }

class LoginState extends Equatable {
  const LoginState({
    this.email = '',
    this.password = '',
    this.status = LoginStatus.initial,
    this.errorMessage,
    this.emailError,
    this.passwordError,
    this.user,
  });

  final String email;
  final String password;
  final LoginStatus status;
  final String? errorMessage;
  final String? emailError;
  final String? passwordError;
  final User? user;

  bool get isValid =>
      emailError == null &&
      passwordError == null &&
      email.isNotEmpty &&
      password.isNotEmpty;

  LoginState copyWith({
    String? email,
    String? password,
    LoginStatus? status,
    String? errorMessage,
    String? emailError,
    String? passwordError,
    User? user,
    bool clearErrorMessage = false,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearUser = false,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      status: status ?? this.status,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      emailError: clearEmailError ? null : (emailError ?? this.emailError),
      passwordError:
          clearPasswordError ? null : (passwordError ?? this.passwordError),
      user: clearUser ? null : (user ?? this.user),
    );
  }

  @override
  List<Object?> get props => [
        email,
        password,
        status,
        errorMessage,
        emailError,
        passwordError,
        user,
      ];
}
