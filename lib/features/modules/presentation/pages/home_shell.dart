import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/layout/app_destination.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/usecases/sign_out_usecase.dart';
import '../../../hrms/presentation/bloc/employees/employees_bloc.dart';
import '../../../settings/presentation/bloc/clients/clients_bloc.dart';

/// Post-login shell: persistent sidebar + routed body from go_router.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.user,
    required this.location,
    required this.child,
  });

  final User user;
  final String location;
  final Widget child;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final EmployeesBloc _employeesBloc =
      sl<EmployeesBloc>()..add(const EmployeesRequested());
  ClientsBloc? _clientsBloc;
  bool _loggingOut = false;

  bool get _isStaff => AppAccess.isStaff(widget.user);

  @override
  void initState() {
    super.initState();
    if (_isStaff) {
      _clientsBloc = sl<ClientsBloc>()..add(const ClientsRequested());
    }
  }

  @override
  void dispose() {
    _employeesBloc.close();
    _clientsBloc?.close();
    super.dispose();
  }

  List<AppNavSection> get _sections {
    if (_isStaff) {
      return const [
        AppNavSection(
          label: 'HRMS',
          icon: Icons.groups_outlined,
          selectable: true,
          items: [
            AppNavItem(
              label: 'All Employees',
              icon: Icons.people_outline,
            ),
            AppNavItem(
              label: 'Add Employee',
              icon: Icons.person_add_alt_1_outlined,
            ),
          ],
        ),
        AppNavSection(
          label: 'DMS',
          icon: Icons.folder_outlined,
          selectable: true,
          items: [],
        ),
        AppNavSection(
          label: 'Finances',
          icon: Icons.account_balance_wallet_outlined,
          selectable: false,
          items: [
            AppNavItem(
              label: 'Payroll',
              icon: Icons.payments_outlined,
            ),
            AppNavItem(
              label: 'Proposals',
              icon: Icons.request_quote_outlined,
            ),
            AppNavItem(
              label: 'Invoices',
              icon: Icons.receipt_long_outlined,
            ),
            AppNavItem(
              label: 'Expense',
              icon: Icons.monetization_on_outlined,
            ),
          ],
        ),
        AppNavSection(
          label: 'Settings',
          icon: Icons.settings_outlined,
          selectable: true,
          items: [],
        ),
      ];
    }

    return const [
      AppNavSection(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectable: true,
        items: [],
      ),
    ];
  }

  List<String> get _paths {
    if (_isStaff) {
      return const [
        AppRoutes.hrms,
        AppRoutes.employees,
        AppRoutes.employeesAdd,
        AppRoutes.dms,
        AppRoutes.payroll,
        AppRoutes.proposals,
        AppRoutes.invoices,
        AppRoutes.expenses,
        AppRoutes.settings,
      ];
    }

    return const [AppRoutes.dashboard];
  }

  int get _selectedIndex {
    final location = widget.location;
    final paths = _paths;

    if (!_isStaff) {
      return 0;
    }

    if (location.startsWith(AppRoutes.settings)) return 8;
    if (location.startsWith(AppRoutes.expenses)) return 7;
    if (location.startsWith(AppRoutes.invoices)) return 6;
    if (location.startsWith(AppRoutes.proposals)) return 5;
    if (location.startsWith(AppRoutes.payroll)) return 4;
    if (location.startsWith(AppRoutes.dms)) return 3;
    if (location.startsWith(AppRoutes.employeesAdd)) return 2;
    if (location.startsWith('${AppRoutes.employees}/')) return 1;
    if (location == AppRoutes.employees) return 1;
    if (location.startsWith(AppRoutes.hrms)) return 0;

    final exact = paths.indexOf(location);
    return exact >= 0 ? exact : 0;
  }

  String get _title {
    final location = widget.location;
    if (location == AppRoutes.dashboard) return 'Dashboard';
    if (location == AppRoutes.myDetails) return 'Dashboard';
    if (location == AppRoutes.employeesAdd) return 'Add employee';
    if (location.endsWith('/edit')) return 'Edit employee';
    if (location.endsWith('/compensation')) return 'Compensation breakup';
    if (RegExp(r'^/hrms/employees/[^/]+$').hasMatch(location)) {
      return 'Employee details';
    }
    if (location == AppRoutes.clientsAdd) return 'Add client';
    if (location.startsWith(AppRoutes.clients)) return 'Manage clients';
    if (location == AppRoutes.inviteEmployee) return 'Invite employee';
    if (location == AppRoutes.companyDetails) return 'Company Details';
    if (location == AppRoutes.roles) return 'Roles';
    if (location == AppRoutes.ledger) return 'Activity ledger';
    if (location == AppRoutes.settings) return 'Settings';
    if (location.startsWith(AppRoutes.expenses)) return 'Expense';
    if (location.startsWith(AppRoutes.invoices)) return 'Invoices';
    if (location.startsWith(AppRoutes.proposals)) return 'Proposals';
    if (location.startsWith(AppRoutes.payroll)) return 'Payroll';
    if (location.startsWith(AppRoutes.dms)) return 'DMS';
    if (location == AppRoutes.employees) return 'All employees';
    return 'HRMS';
  }

  VoidCallback? get _onBack {
    final location = widget.location;

    if (!_isStaff) {
      if (location.endsWith('/compensation')) {
        return () => _goBack(AppRoutes.dashboard);
      }
      return null;
    }

    if (location.endsWith('/edit')) {
      final segments = Uri.parse(location).pathSegments;
      if (segments.length >= 4 && segments[2] != 'add') {
        return () => _goBack(AppRoutes.employeeDetail(segments[2]));
      }
      return null;
    }
    if (location.endsWith('/compensation')) {
      final segments = Uri.parse(location).pathSegments;
      if (segments.length >= 4) {
        return () => _goBack(AppRoutes.employeeDetail(segments[2]));
      }
      return null;
    }
    if (RegExp(r'^/hrms/employees/[^/]+$').hasMatch(location) &&
        location != AppRoutes.employeesAdd) {
      return () => _goBack(AppRoutes.employees);
    }
    if (location == AppRoutes.clientsAdd) {
      return () => _goBack(AppRoutes.clients);
    }
    if (location == AppRoutes.clients ||
        location == AppRoutes.companyDetails ||
        location == AppRoutes.roles ||
        location == AppRoutes.ledger ||
        location == AppRoutes.inviteEmployee) {
      return () => _goBack(AppRoutes.settings);
    }
    return null;
  }

  void _goBack(String fallback) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallback);
    }
  }

  void _selectDestination(int index) {
    final paths = _paths;
    if (index < 0 || index >= paths.length) return;
    final path = paths[index];
    if (path != widget.location) {
      context.go(path);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    await sl<SignOutUseCase>()();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _employeesBloc),
        if (_clientsBloc != null) BlocProvider.value(value: _clientsBloc!),
      ],
      child: AppShell(
        user: widget.user,
        title: _title,
        sections: _sections,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
        onBack: _onBack,
        onLogout: _loggingOut ? null : _logout,
        body: widget.child,
      ),
    );
  }
}
