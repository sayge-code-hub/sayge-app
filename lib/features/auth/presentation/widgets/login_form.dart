import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../bloc/login_bloc.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  late final TapGestureRecognizer _emailTapRecognizer;
  bool _resetting = false;

  static final _supportEmailUri = Uri(
    scheme: 'mailto',
    path: 'humans@sayge.in',
  );

  @override
  void initState() {
    super.initState();
    _emailTapRecognizer = TapGestureRecognizer()..onTap = _openSupportEmail;
  }

  @override
  void dispose() {
    _emailTapRecognizer.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openSupportEmail() async {
    final launched = await launchUrl(_supportEmailUri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email app'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _forgotPassword() async {
    if (_resetting) return;

    final email = _emailController.text.trim().toLowerCase();
    final emailError = Validators.email(email);
    if (emailError != null) {
      context.read<LoginBloc>().add(LoginEmailChanged(email));
      await showAppMessageDialog(
        context,
        title: 'Forgot password',
        message: 'Enter your full email address first, then try again.',
      );
      return;
    }

    setState(() => _resetting = true);
    final result = await sl<ResetPasswordUseCase>()(email);
    if (!mounted) return;
    setState(() => _resetting = false);

    await result.fold(
      (failure) => showAppMessageDialog(
        context,
        title: 'Forgot password',
        message: failure.message,
      ),
      (_) => showAppMessageDialog(
        context,
        title: 'Check your email',
        message:
            'If an account exists for $email, we sent a reset link. '
            'Open it to choose a new password.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          height: 1.45,
          color: AppColors.textLight,
        );

    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) {
        final isLoading = state.status == LoginStatus.loading || _resetting;

        return AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _emailController,
                label: 'Email',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !isLoading,
                errorText: state.emailError,
                autofillHints: const [AutofillHints.email],
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                onChanged: (value) =>
                    context.read<LoginBloc>().add(LoginEmailChanged(value)),
                onSubmitted: (_) => _passwordFocusNode.requestFocus(),
              ),
              const SizedBox(height: 14),
              AppPasswordField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                enabled: !isLoading,
                errorText: state.passwordError,
                onChanged: (value) =>
                    context.read<LoginBloc>().add(LoginPasswordChanged(value)),
                onSubmitted: (_) =>
                    context.read<LoginBloc>().add(const LoginSubmitted()),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : _forgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.text,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _resetting ? 'Sending…' : 'Forgot password?',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: state.errorMessage!),
              ],
              const SizedBox(height: 16),
              AppButton(
                label: 'Sign in',
                isLoading: state.status == LoginStatus.loading,
                onPressed: isLoading
                    ? null
                    : () =>
                        context.read<LoginBloc>().add(const LoginSubmitted()),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    isLoading ? null : () => context.go(AppRoutes.signup),
                child: const Text('New to Saasify? Create a workspace'),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: bodyStyle,
                  children: [
                    const TextSpan(
                      text:
                          'Use Forgot password? to receive a reset link, or email ',
                    ),
                    TextSpan(
                      text: 'humans@sayge.in',
                      style: bodyStyle?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.text,
                      ),
                      recognizer: _emailTapRecognizer,
                    ),
                    const TextSpan(text: ' for help.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
