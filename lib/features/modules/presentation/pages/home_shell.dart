import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/app_destination.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/user.dart';
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
  late final ClientsBloc _clientsBloc =
      sl<ClientsBloc>()..add(const ClientsRequested());

  static const _sections = [
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
          icon: Icons.account_balance_outlined,
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

  static const _paths = [
    AppRoutes.hrms, // 0
    AppRoutes.employees, // 1
    AppRoutes.employeesAdd, // 2
    AppRoutes.dms, // 3
    AppRoutes.payroll, // 4 Finances → Payroll
    AppRoutes.proposals, // 5 Finances → Proposals
    AppRoutes.invoices, // 6 Finances → Invoices
    AppRoutes.expenses, // 7 Finances → Expense
    AppRoutes.settings, // 8 Settings hub
  ];

  @override
  void dispose() {
    _employeesBloc.close();
    _clientsBloc.close();
    super.dispose();
  }

  int get _selectedIndex {
    final location = widget.location;
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
    return 0;
  }

  String get _title {
    final location = widget.location;
    if (location == AppRoutes.employeesAdd) {
      return '';
    }
    if (location.endsWith('/edit')) return 'Edit employee';
    if (location.endsWith('/compensation')) return 'Compensation breakup';
    if (RegExp(r'^/hrms/employees/[^/]+$').hasMatch(location)) {
      return 'Employee details';
    }
    if (location == AppRoutes.clientsAdd) return 'Add client';
    if (location.startsWith(AppRoutes.clients)) return 'Manage clients';
    if (location == AppRoutes.companyDetails) return 'GST & company';
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

  /// Parent destination for nested shell routes (header / system Back).
  VoidCallback? get _onBack {
    final location = widget.location;
    if (location.endsWith('/edit')) {
      final segments = Uri.parse(location).pathSegments;
      // /hrms/employees/:id/edit
      if (segments.length >= 4 && segments[2] != 'add') {
        return () => _goBack(AppRoutes.employeeDetail(segments[2]));
      }
      return null;
    }
    if (location.endsWith('/compensation')) {
      final segments = Uri.parse(location).pathSegments;
      // /hrms/employees/:id/compensation
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
        location == AppRoutes.ledger) {
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
    final path = _paths[index];
    if (path != widget.location) {
      context.go(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _employeesBloc),
        BlocProvider.value(value: _clientsBloc),
      ],
      child: AppShell(
        user: widget.user,
        title: _title,
        sections: _sections,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
        onBack: _onBack,
        body: widget.child,
      ),
    );
  }
}
