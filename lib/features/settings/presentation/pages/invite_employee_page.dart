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
import '../../../hrms/domain/entities/employee.dart';
import '../../../hrms/domain/usecases/get_employees.dart';
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
  String? _employeeId;
  List<Employee> _employees = const [];
  bool _loadingEmployees = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final result = await sl<GetEmployeesUseCase>()();
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _employees = const [];
        _loadingEmployees = false;
      }),
      (list) => setState(() {
        _employees = list;
        _loadingEmployees = false;
      }),
    );
  }

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
    if (_employeeId == null || _employeeId!.trim().isEmpty) {
      setState(() => _error = 'Select the HRMS employee to link');
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
        employeeId: _employeeId!,
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
      setState(() {
        _roleId = 'role_employee';
        _employeeId = null;
      });
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
    final employeeIds = _employees.map((e) => e.employeeId).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
            children: [
              Text(
                'Send an invite to a @${Validators.allowedEmailDomain} address. '
                'Link an existing HRMS employee so their dashboard shows '
                'details and salary slips. They set their own password.',
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
              if (_loadingEmployees)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                )
              else
                AppDropdown<String>(
                  label: 'Link HRMS employee',
                  value: employeeIds.contains(_employeeId) ? _employeeId : null,
                  items: employeeIds,
                  itemLabel: (id) {
                    final match = _employees.where((e) => e.employeeId == id);
                    if (match.isEmpty) return id;
                    final e = match.first;
                    return '${e.employeeName} ($id)';
                  },
                  enabled: !_sending && employeeIds.isNotEmpty,
                  onChanged: (id) {
                    setState(() {
                      _employeeId = id;
                      if (_fullName.text.trim().isEmpty && id != null) {
                        final match =
                            _employees.where((e) => e.employeeId == id);
                        if (match.isNotEmpty) {
                          _fullName.text = match.first.employeeName;
                        }
                      }
                    });
                  },
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
              onPressed: _sending
                  ? null
                  : () => leaveFormIfConfirmed(
                        context,
                        () => widget.onBack?.call(),
                      ),
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
