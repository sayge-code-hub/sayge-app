import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/billing/billing_access.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/auth_page_scaffold.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/auth_remote_datasource.dart';

/// Public Saasify self-serve signup (Free plan). Payment gateway not connected.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _companyController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _companyController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final company = _companyController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    final emailErr = Validators.email(email);
    if (company.isEmpty) {
      setState(() => _error = 'Enter your company name.');
      return;
    }
    if (emailErr != null) {
      setState(() => _error = emailErr);
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final authRes = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'saasify_signup': 'true',
          'company_name': company,
          'full_name': name.isEmpty ? email.split('@').first : name,
          'name': name.isEmpty ? email.split('@').first : name,
          'role_code': 'owner',
          'member_role': 'owner',
        },
      );
      if (authRes.user == null) {
        throw Exception('Could not create account.');
      }

      // Provision company + Free subscription (idempotent).
      await client.rpc(
        'saasify_complete_signup',
        params: {
          'p_company_name': company,
          'p_display_name': company,
        },
      );

      final profile = await sl<AuthRemoteDataSource>().restoreSession();
      if (profile == null) {
        throw Exception(
          'Account created, but profile is not ready. Sign in again.',
        );
      }
      await sl<AuthSession>().setUser(profile, needsPasswordSetup: false);
      await sl<BillingAccess>().refresh();
      if (!mounted) return;
      context.go(AppAccess.homeRoute(profile));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);
    return AuthPageScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Saasify',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            'Create your company workspace on the Free plan.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          SizedBox(height: compact ? 24 : 28),
          AppTextField(
            controller: _companyController,
            label: 'Company name',
            hintText: 'Acme Cafe',
            textInputAction: TextInputAction.next,
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _nameController,
            label: 'Your name',
            hintText: 'Optional',
            textInputAction: TextInputAction.next,
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _emailController,
            label: 'Work email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          AppPasswordField(
            controller: _passwordController,
            label: 'Password',
            textInputAction: TextInputAction.done,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: _busy ? 'Creating…' : 'Create workspace',
            onPressed: _busy ? null : _submit,
          ),
          const SizedBox(height: 16),
          Text(
            'Payments are not connected yet — Free plan only. '
            'Upgrade via platform ops / billing later.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _busy ? null : () => context.go(AppRoutes.login),
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    );
  }
}
