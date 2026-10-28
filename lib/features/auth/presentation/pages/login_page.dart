import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/password_setup.dart';
import '../../../../core/billing/billing_access.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_version_label.dart';
import '../../../../core/widgets/auth_page_scaffold.dart';
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
      listener: (context, state) async {
        if (state.status == LoginStatus.success && state.user != null) {
          final needsSetup = PasswordSetup.currentUserRequiresSetup();
          await sl<AuthSession>().setUser(
            state.user!,
            needsPasswordSetup: needsSetup,
          );
          await sl<BillingAccess>().refresh();
          if (!context.mounted) return;
          context.go(
            needsSetup
                ? AppRoutes.setPassword
                : AppAccess.homeRoute(state.user!),
          );
        }
      },
      child: AuthPageScaffold(
        footer: const AppVersionLabel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LoginHeader(),
            SizedBox(height: Breakpoints.isCompact(context) ? 24 : 28),
            const LoginForm(),
          ],
        ),
      ),
    );
  }
}

class _LoginHeader extends StatefulWidget {
  const _LoginHeader();

  @override
  State<_LoginHeader> createState() => _LoginHeaderState();
}

class _LoginHeaderState extends State<_LoginHeader> {
  DateTime? _lastTap;

  void _onLogoTap() {
    final now = DateTime.now();
    final prev = _lastTap;
    _lastTap = now;
    if (prev != null &&
        now.difference(prev) <= const Duration(milliseconds: 450)) {
      _lastTap = null;
      context.go(AppRoutes.platformOpsGate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);

    return Column(
      children: [
        GestureDetector(
          onTap: _onLogoTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              'assets/images/saasify_logo.png',
              height: compact ? 40 : 48,
              fit: BoxFit.contain,
              semanticLabel: 'Saasify',
            ),
          ),
        ),
        SizedBox(height: compact ? 12 : 14),
        Text(
          'Welcome back. Sign in to continue.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}
