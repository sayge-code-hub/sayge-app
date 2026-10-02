import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_version_label.dart';
import '../../../../injection_container.dart';
import '../bloc/login_bloc.dart';
import '../widgets/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LoginBloc>(),
      child: const LoginView(),
    );
  }
}

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginBloc, LoginState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == LoginStatus.success && state.user != null) {
          sl<AuthSession>().setUser(state.user!);
          context.go(AppRoutes.hrms);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              scrollbars: false,
                              overscroll: false,
                            ),
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _LoginHeader(),
                                      SizedBox(height: 40),
                                      LoginForm(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const AppVersionLabel(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/sayge_logo.webp',
          height: 44,
          fit: BoxFit.contain,
          semanticLabel: 'Sayge',
        ),
        const SizedBox(height: 28),
        Text(
          'Welcome back. Sign in to continue.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15),
        ),
      ],
    );
  }
}
