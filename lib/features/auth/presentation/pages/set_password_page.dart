import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../../../injection_container.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';

/// Landing page for invite / recovery links — employee sets their password.
class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key});

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ensureSession();
  }

  Future<void> _ensureSession() async {
    // Invite / recovery links hydrate the session from the URL hash.
    final existing = Supabase.instance.client.auth.currentSession;
    if (existing != null) {
      if (!mounted) return;
      setState(() => _ready = true);
      return;
    }

    final sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.session != null) {
        setState(() {
          _ready = true;
          _error = null;
        });
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await sub.cancel();
    if (!mounted) return;
    if (Supabase.instance.client.auth.currentSession == null) {
      setState(() {
        _ready = false;
        _error =
            'This invite link is invalid or expired. Ask an admin to resend the invite.';
      });
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pwdError = Validators.password(_password.text);
    if (pwdError != null) {
      setState(() => _error = pwdError);
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      final profile = await sl<AuthRemoteDataSource>().restoreSession();
      if (profile != null) {
        await sl<AuthSession>().setUser(profile);
      }
      if (!mounted) return;
      context.go(AppRoutes.hrms);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Set your password',
                    style: textTheme.headlineMedium?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a password for your Sayge account. Use at least 6 characters.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppPasswordField(
                    controller: _password,
                    label: 'New password',
                    enabled: _ready && !_saving,
                  ),
                  const SizedBox(height: 12),
                  AppPasswordField(
                    controller: _confirm,
                    label: 'Confirm password',
                    enabled: _ready && !_saving,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const Spacer(),
                  AppButton(
                    label: _saving ? 'Saving…' : 'Save password & continue',
                    isLoading: _saving,
                    enabled: _ready && !_saving,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => context.go(AppRoutes.login),
                    child: const Text('Back to login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
