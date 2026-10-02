import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_sticky_actions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/invite_employee_remote_datasource.dart';
import '../../domain/entities/settings_entities.dart';
import '../bloc/roles/roles_bloc.dart';

class InviteEmployeePage extends StatelessWidget {
  const InviteEmployeePage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RolesBloc>()..add(const RolesStarted()),
      child: _InviteEmployeeBody(onBack: onBack),
    );
  }
}

class _InviteEmployeeBody extends StatefulWidget {
  const _InviteEmployeeBody({this.onBack});

  final VoidCallback? onBack;

  @override
  State<_InviteEmployeeBody> createState() => _InviteEmployeeBodyState();
}

class _InviteEmployeeBodyState extends State<_InviteEmployeeBody> {
  final _localPart = TextEditingController();
  final _fullName = TextEditingController();
  String? _roleId = 'role_employee';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _localPart.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final localError = Validators.emailLocalPart(_localPart.text);
    if (localError != null) {
      setState(() => _error = localError);
      return;
    }
    final email = Validators.composeEmail(_localPart.text);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await sl<InviteEmployeeRemoteDataSource>().invite(
        email: email,
        fullName: _fullName.text.trim(),
        roleId: _roleId ?? 'role_employee',
      );
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        message:
            'Invite sent to $email. They will set their own password from the email link.',
      );
      if (!mounted) return;
      _localPart.clear();
      _fullName.clear();
      setState(() => _roleId = 'role_employee');
    } catch (e) {
      final raw = e.toString();
      setState(() {
        _error = raw
            .replaceFirst('Exception: ', '')
            .replaceFirst('ServerException: ', '')
            .replaceFirst('NetworkException: ', '');
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
            children: [
              Text(
                'Send an invite to a @${Validators.allowedEmailDomain} address. '
                'They choose their own password from the email link — you never set it.',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: AppColors.textLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Email',
                controller: _localPart,
                enabled: !_sending,
                prefixIcon: Icons.mail_outline_rounded,
                hintText: 'first.last',
                suffix: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    '@${Validators.allowedEmailDomain}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                      fontSize: 13,
                    ),
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Full name',
                controller: _fullName,
                enabled: !_sending,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              BlocBuilder<RolesBloc, RolesState>(
                builder: (context, state) {
                  final roles = state.roles
                      .where((r) => r.isActive)
                      .toList(growable: false);
                  final items = roles.isEmpty
                      ? const <AppRole>[
                          AppRole(
                            id: 'role_employee',
                            code: 'employee',
                            label: 'Employee',
                            description: '',
                            sortOrder: 50,
                            isActive: true,
                          ),
                        ]
                      : roles;
                  final value = items.any((r) => r.id == _roleId)
                      ? _roleId
                      : items.first.id;
                  return AppDropdown<String>(
                    label: 'Role',
                    value: value,
                    items: items.map((r) => r.id).toList(),
                    itemLabel: (id) {
                      final match = items.where((r) => r.id == id);
                      return match.isEmpty ? id : match.first.label;
                    },
                    enabled: !_sending,
                    onChanged: (id) => setState(() => _roleId = id),
                  );
                },
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
            ],
          ),
        ),
        AppStickyActions(
          children: [
            OutlinedButton(
              onPressed: _sending ? null : widget.onBack,
              child: const Text('Back'),
            ),
            AppButton(
              label: _sending ? 'Sending…' : 'Send invite',
              expand: true,
              isLoading: _sending,
              enabled: !_sending,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
