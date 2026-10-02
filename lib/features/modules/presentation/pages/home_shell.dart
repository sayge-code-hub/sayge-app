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
      iconAsset: 'assets/images/icon_hrms.png',
      selectable: true,
      items: [
        AppNavItem(
          label: 'All Employees',
          iconAsset: 'assets/images/icon_all_employees.png',
        ),
        AppNavItem(
          label: 'Add Employee',
          iconAsset: 'assets/images/icon_add_employee.png',
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
      label: 'Payroll',
      icon: Icons.payments_outlined,
      selectable: true,
      items: [],
    ),
    AppNavSection(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectable: true,
      items: [
        AppNavItem(
          label: 'Manage clients',
          icon: Icons.apartment_outlined,
        ),
      ],
    ),
  ];

  static const _paths = [
    AppRoutes.hrms, // 0
    AppRoutes.employees, // 1
    AppRoutes.employeesAdd, // 2
    AppRoutes.dms, // 3
    AppRoutes.payroll, // 4
    AppRoutes.clients, // 5 Settings → clients
    AppRoutes.clients, // 6 Manage clients
  ];

  @override
  void dispose() {
    _employeesBloc.close();
    _clientsBloc.close();
    super.dispose();
  }

  int get _selectedIndex {
    final location = widget.location;
    if (location.startsWith(AppRoutes.clients)) return 6;
    if (location.startsWith(AppRoutes.settings)) return 6;
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
      // Nav already labels "Add Employee" — skip redundant page header.
      return '';
    }
    if (location.endsWith('/edit')) return 'Edit employee';
    if (location.endsWith('/compensation')) return 'Compensation breakup';
    if (RegExp(r'^/hrms/employees/[^/]+$').hasMatch(location)) {
      return 'Employee details';
    }
    if (location == AppRoutes.clientsAdd) return 'Add client';
    if (location.startsWith(AppRoutes.clients)) return 'Manage clients';
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
    if (location == AppRoutes.clients) {
      // Manage clients sits under Settings; Settings itself redirects here,
      // so Back leaves the settings area to the HRMS home.
      return () => _goBack(AppRoutes.hrms);
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
