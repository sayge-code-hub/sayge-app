import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/validators.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required this.loginUseCase}) : super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginSubmitted>(_onSubmitted);
  }

  final LoginUseCase loginUseCase;

  void _onEmailChanged(
    LoginEmailChanged event,
    Emitter<LoginState> emit,
  ) {
    final emailError = Validators.emailLocalPart(event.email);
    final fullEmail = emailError == null
        ? Validators.composeEmail(event.email)
        : event.email;

    emit(
      state.copyWith(
        email: fullEmail,
        emailError: emailError,
        clearEmailError: emailError == null,
        clearErrorMessage: true,
        status: LoginStatus.initial,
      ),
    );
  }

  void _onPasswordChanged(
    LoginPasswordChanged event,
    Emitter<LoginState> emit,
  ) {
    final passwordError = Validators.password(event.password);
    emit(
      state.copyWith(
        password: event.password,
        passwordError: passwordError,
        clearPasswordError: passwordError == null,
        clearErrorMessage: true,
        status: LoginStatus.initial,
      ),
    );
  }

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    final localPart = state.email.contains('@')
        ? state.email.split('@').first
        : state.email;
    final emailError = Validators.emailLocalPart(localPart);
    final passwordError = Validators.password(state.password);

    if (emailError != null || passwordError != null) {
      emit(
        state.copyWith(
          emailError: emailError,
          passwordError: passwordError,
          clearEmailError: emailError == null,
          clearPasswordError: passwordError == null,
          status: LoginStatus.failure,
        ),
      );
      return;
    }

    final fullEmail = Validators.composeEmail(localPart);

    emit(
      state.copyWith(
        email: fullEmail,
        status: LoginStatus.loading,
        clearErrorMessage: true,
      ),
    );

    final result = await loginUseCase(
      LoginParams(email: fullEmail, password: state.password),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LoginStatus.failure,
          errorMessage: failure.message,
          clearUser: true,
        ),
      ),
      (user) => emit(
        state.copyWith(
          status: LoginStatus.success,
          user: user,
        ),
      ),
    );
  }
}
