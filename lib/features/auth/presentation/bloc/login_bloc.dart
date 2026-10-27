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
    final email = event.email.trim().toLowerCase();
    final emailError = Validators.email(email);

    emit(
      state.copyWith(
        email: email,
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
    final email = state.email.trim().toLowerCase();
    final emailError = Validators.email(email);
    final passwordError = Validators.password(state.password);

    if (emailError != null || passwordError != null) {
      emit(
        state.copyWith(
          email: email,
          emailError: emailError,
          passwordError: passwordError,
          clearEmailError: emailError == null,
          clearPasswordError: passwordError == null,
          status: LoginStatus.failure,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        email: email,
        status: LoginStatus.loading,
        clearErrorMessage: true,
      ),
    );

    final result = await loginUseCase(
      LoginParams(email: email, password: state.password),
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
