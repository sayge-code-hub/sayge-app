import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/app_access.dart';
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
import '../../../pos/domain/entities/cafe_entities.dart';
import '../../../pos/domain/usecases/cafe_pos_usecases.dart';
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
  String? _cafeId;
  List<Employee> _employees = const [];
  List<Cafe> _cafes = const [];
  bool _loadingEmployees = true;
  bool _loadingCafes = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadCafes();
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

  Future<void> _loadCafes() async {
    final result = await sl<GetCafes>()();
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _cafes = const [];
        _loadingCafes = false;
      }),
      (list) => setState(() {
        _cafes = list.where((c) => c.isActive).toList();
        _loadingCafes = false;
      }),
    );
  }

  String? _roleCode(List<AppRole> roles, [String? roleId]) {
    final id = (roleId ?? _roleId)?.trim() ?? '';
    for (final role in roles) {
      if (role.id == id) return role.code.trim().toLowerCase();
    }
    return null;
  }

  bool _roleNeedsCafe(List<AppRole> roles, [String? roleId]) {
    final code = _roleCode(roles, roleId);
    return code != null && AppAccess.cafeRoleCodes.contains(code);
  }

  @override
  void dispose() {
    _localPart.dispose();
    _fullName.dispose();
    super.dispose();
  }

  bool _roleNeedsEmployeeLink(List<AppRole> roles, [String? roleId]) {
    final id = (roleId ?? _roleId)?.trim() ?? '';
    if (id.isEmpty) return true;
    for (final role in roles) {
      if (role.id != id) continue;
      final code = role.code.trim().toLowerCase();
      if (AppAccess.staffRoleCodes.contains(code)) return false;
      if (AppAccess.cafeRoleCodes.contains(code)) return false;
      return true;
    }
    // Unknown id — treat as employee-style invite.
    return id == 'role_employee' || id.contains('employee');
  }

  List<AppRole> _activeRoles(RolesState state) {
    final roles =
        state.roles.where((r) => r.isActive).toList(growable: false);
    if (roles.isNotEmpty) return roles;
    return const <AppRole>[
      AppRole(
        id: 'role_employee',
        code: 'employee',
        label: 'Employee',
        description: '',
        sortOrder: 50,
        isActive: true,
      ),
    ];
  }

  Future<void> _submit(List<AppRole> roles) async {
    final localError = Validators.emailLocalPart(_localPart.text);
    if (localError != null) {
      setState(() => _error = localError);
      return;
    }

    final needsLink = _roleNeedsEmployeeLink(roles);
    final needsCafe = _roleNeedsCafe(roles);
    if (needsLink &&
        (_employeeId == null || _employeeId!.trim().isEmpty)) {
      setState(() => _error = 'Select the HRMS employee to link');
      return;
    }
    if (needsCafe &&
        (_cafeId == null || _cafeId!.trim().isEmpty)) {
      setState(() => _error = 'Select the cafe for this POS role');
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
        employeeId: needsLink ? (_employeeId ?? '') : '',
        cafeId: needsCafe ? (_cafeId ?? '') : '',
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
        _cafeId = null;
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

    return BlocBuilder<RolesBloc, RolesState>(
      builder: (context, rolesState) {
        final roles = _activeRoles(rolesState);
        final roleValue = roles.any((r) => r.id == _roleId)
            ? _roleId!
            : roles.first.id;
        final needsLink = _roleNeedsEmployeeLink(roles, roleValue);
        final needsCafe = _roleNeedsCafe(roles, roleValue);
        final cafeIds = _cafes.map((c) => c.id).toList();

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
                children: [
                  Text(
                    needsCafe
                        ? 'Send an invite to a @${Validators.allowedEmailDomain} address. '
                            'Cafe POS roles must be bound to one cafe. '
                            'They set their own password from the email.'
                        : needsLink
                            ? 'Send an invite to a @${Validators.allowedEmailDomain} address. '
                                'Link an existing HRMS employee so their dashboard shows '
                                'details and salary slips. They set their own password.'
                            : 'Send an invite to a @${Validators.allowedEmailDomain} address. '
                                'Owners and admins do not need an HRMS employee link. '
                                'They set their own password from the email.',
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
                  AppDropdown<String>(
                    label: 'Role',
                    value: roleValue,
                    items: roles.map((r) => r.id).toList(),
                    itemLabel: (id) {
                      final match = roles.where((r) => r.id == id);
                      return match.isEmpty ? id : match.first.label;
                    },
                    enabled: !_sending,
                    onChanged: (id) {
                      setState(() {
                        _roleId = id;
                        if (!_roleNeedsEmployeeLink(roles, id)) {
                          _employeeId = null;
                        }
                        if (!_roleNeedsCafe(roles, id)) {
                          _cafeId = null;
                        }
                        _error = null;
                      });
                    },
                  ),
                  if (needsCafe) ...[
                    const SizedBox(height: 12),
                    if (_loadingCafes)
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
                        label: 'Cafe',
                        value: cafeIds.contains(_cafeId) ? _cafeId : null,
                        items: cafeIds,
                        itemLabel: (id) {
                          final match = _cafes.where((c) => c.id == id);
                          return match.isEmpty ? id : match.first.name;
                        },
                        enabled: !_sending && cafeIds.isNotEmpty,
                        onChanged: (id) {
                          setState(() => _cafeId = id);
                        },
                      ),
                  ],
                  if (needsLink) ...[
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
                        value: employeeIds.contains(_employeeId)
                            ? _employeeId
                            : null,
                        items: employeeIds,
                        itemLabel: (id) {
                          final match =
                              _employees.where((e) => e.employeeId == id);
                          if (match.isEmpty) return id;
                          final e = match.first;
                          final draft = e.isDraft ? ' · Draft' : '';
                          return '${e.employeeName} ($id)$draft';
                        },
                        enabled: !_sending && employeeIds.isNotEmpty,
                        onChanged: (id) {
                          setState(() {
                            _employeeId = id;
                            if (_fullName.text.trim().isEmpty && id != null) {
                              final match = _employees
                                  .where((e) => e.employeeId == id);
                              if (match.isNotEmpty) {
                                _fullName.text = match.first.employeeName;
                              }
                            }
                          });
                        },
                      ),
                  ],
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
                  onPressed: () => _submit(roles),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
