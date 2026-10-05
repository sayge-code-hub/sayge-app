import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/layout/app_destination.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_message_dialog.dart';
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

  bool get _employeeLinked {
    final id = widget.user.employeeId?.trim();
    return id != null && id.isNotEmpty;
  }

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
            const AppNavItem(
              label: 'Expense',
              icon: Icons.account_balance_outlined,
              iconAsset: 'assets/images/nav_expense.png',
            ),
          ],
        ),
        AppNavSection(
          label: 'POS',
          icon: Icons.storefront_outlined,
          selectable: true,
          items: [],
        ),
        AppNavSection(
          label: 'Settings',
          icon: Icons.settings_outlined,
          selectable: true,
          items: [],
        ),
      ];
    }

    final linked = _employeeLinked;
    return [
      const AppNavSection(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectable: true,
        items: [],
      ),
      AppNavSection(
        label: 'Salary Slips',
        icon: Icons.payments_outlined,
        selectable: linked,
        enabled: linked,
        items: const [],
      ),
      AppNavSection(
        label: 'Pay & Compliance',
        icon: Icons.account_balance_wallet_outlined,
        selectable: linked,
        enabled: linked,
        items: const [],
      ),
      AppNavSection(
        label: 'Expense',
        icon: Icons.account_balance_outlined,
        iconAsset: 'assets/images/nav_expense.png',
        selectable: linked,
        enabled: linked,
        items: const [],
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
        AppRoutes.pos,
        AppRoutes.settings,
      ];
    }

    final id = widget.user.employeeId?.trim();
    if (id == null || id.isEmpty) {
      return const [AppRoutes.dashboard];
    }
    return [
      AppRoutes.dashboard,
      AppRoutes.dashboardSlips,
      AppRoutes.employeeCompensation(id),
      AppRoutes.expenses,
    ];
  }

  int get _selectedIndex {
    final location = widget.location;
    final paths = _paths;

    if (!_isStaff) {
      if (location.startsWith(AppRoutes.expenses)) return 3;
      if (location.contains('/compensation')) return 2;
      if (location.contains('section=slips')) return 1;
      return 0;
    }

    if (location.startsWith(AppRoutes.settings)) return 9;
    if (location.startsWith(AppRoutes.pos)) return 8;
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
    final path = Uri.tryParse(location)?.path ?? location;
    if (path == AppRoutes.dashboard) {
      if (location.contains('section=slips')) return 'Salary Slips';
      return 'Dashboard';
    }
    if (path == AppRoutes.myDetails) return 'Dashboard';
    if (path == AppRoutes.employeesAdd) return 'Add employee';
    if (path.endsWith('/edit') && path.startsWith('/hrms/employees/')) {
      return 'Edit employee';
    }
    if (path.endsWith('/compensation')) {
      return _isStaff ? 'Compensation breakup' : 'Pay & Compliance';
    }
    if (RegExp(r'^/hrms/employees/[^/]+$').hasMatch(path)) {
      return 'Employee details';
    }
    if (path == AppRoutes.clientsAdd) return 'Add client';
    if (RegExp(r'^/settings/clients/[^/]+/edit$').hasMatch(path)) {
      return 'Edit client';
    }
    if (RegExp(r'^/settings/clients/[^/]+$').hasMatch(path)) {
      return 'Client details';
    }
    if (path.startsWith(AppRoutes.clients)) return 'Manage clients';
    if (path == AppRoutes.inviteEmployee) return 'Invite employee';
    if (path == AppRoutes.companyDetails) return 'Company Details';
    if (path == AppRoutes.roles) return 'Roles';
    if (path == AppRoutes.ledger) return 'Activity ledger';
    if (path == AppRoutes.settings) return 'Settings';
    if (path.startsWith(AppRoutes.pos)) {
      if (path.endsWith('/edit') && path.contains('/brands/')) {
        return 'Edit brand';
      }
      if (path == AppRoutes.posBrandAdd) return 'Add brand';
      if (path.contains('/products/add')) return 'New product';
      if (path.endsWith('/edit') && path.contains('/products/')) {
        return 'Edit product';
      }
      if (path.endsWith('/products')) return 'All products';
      if (path.contains('/products/')) return 'Product';
      if (path.endsWith('/inventory')) return 'Manage inventory';
      if (path.endsWith('/terminal')) return 'POS';
      if (path.endsWith('/analytics')) return 'Analytics';
      if (RegExp(r'^/pos/[^/]+$').hasMatch(path)) return 'Brand';
      return 'POS';
    }
    if (path.startsWith(AppRoutes.expenses)) return 'Expense';
    if (path.startsWith(AppRoutes.invoices)) return 'Invoices';
    if (path.startsWith(AppRoutes.proposals)) return 'Proposals';
    if (path.startsWith(AppRoutes.payroll)) return 'Payroll';
    if (path.startsWith(AppRoutes.dms)) return 'DMS';
    if (path == AppRoutes.employees) return 'All employees';
    return 'HRMS';
  }

  VoidCallback? get _onBack {
    final location = widget.location;
    final path = Uri.tryParse(location)?.path ?? location;

    if (!_isStaff) {
      if (path.endsWith('/compensation')) {
        return () => _goBack(AppRoutes.dashboard);
      }
      return null;
    }

    VoidCallback confirming(VoidCallback leave) {
      return () {
        leaveFormIfConfirmed(context, leave);
      };
    }

    if (path.endsWith('/edit')) {
      final segments = Uri.parse(path).pathSegments;
      if (segments.length >= 4 && segments[2] != 'add') {
        // Employee edit form.
        if (path.startsWith('/hrms/employees/')) {
          return confirming(
            () => _goBack(AppRoutes.employeeDetail(segments[2])),
          );
        }
      }
    }
    if (path == AppRoutes.employeesAdd) {
      return confirming(() => _goBack(AppRoutes.employees));
    }
    if (path.endsWith('/compensation')) {
      final segments = Uri.parse(path).pathSegments;
      if (segments.length >= 4) {
        return () => _goBack(AppRoutes.employeeDetail(segments[2]));
      }
      return null;
    }
    if (RegExp(r'^/hrms/employees/[^/]+$').hasMatch(path) &&
        path != AppRoutes.employeesAdd) {
      return () => _goBack(AppRoutes.employees);
    }
    if (path == AppRoutes.clientsAdd) {
      return confirming(() => _goBack(AppRoutes.clients));
    }
    if (RegExp(r'^/settings/clients/[^/]+/edit$').hasMatch(path)) {
      final segments = Uri.parse(path).pathSegments;
      final clientId = segments.length >= 3 ? segments[2] : '';
      return confirming(
        () => _goBack(
          clientId.isEmpty
              ? AppRoutes.clients
              : AppRoutes.clientDetail(clientId),
        ),
      );
    }
    if (RegExp(r'^/settings/clients/[^/]+$').hasMatch(path)) {
      return () => _goBack(AppRoutes.clients);
    }
    if (path == AppRoutes.clients ||
        path == AppRoutes.companyDetails ||
        path == AppRoutes.roles ||
        path == AppRoutes.ledger) {
      return () => _goBack(AppRoutes.settings);
    }
    if (path == AppRoutes.inviteEmployee) {
      return confirming(() => _goBack(AppRoutes.settings));
    }
    if (path == AppRoutes.posBrandAdd ||
        (path.endsWith('/edit') && path.contains('/pos/brands/'))) {
      return confirming(() => _goBack(AppRoutes.posHub));
    }
    if (path.contains('/pos/') && path.contains('/products/')) {
      final segments = Uri.parse(path).pathSegments;
      if (segments.length >= 2) {
        final isProductEdit = path.endsWith('/edit') && segments.length >= 5;
        final isProductAdd =
            path.endsWith('/add') || path.contains('/products/add');
        if (isProductEdit) {
          return confirming(
            () => _goBack(
              AppRoutes.posProductDetail(segments[1], segments[3]),
            ),
          );
        }
        if (isProductAdd) {
          return confirming(
            () => _goBack(AppRoutes.posProducts(segments[1])),
          );
        }
        // Product detail (view) — leave without confirm.
        return () => _goBack(AppRoutes.posProducts(segments[1]));
      }
    }
    if (path.contains('/pos/') &&
        (path.endsWith('/products') ||
            path.endsWith('/inventory') ||
            path.endsWith('/terminal') ||
            path.endsWith('/analytics'))) {
      final segments = Uri.parse(path).pathSegments;
      if (segments.length >= 2) {
        return () => _goBack(AppRoutes.posBrand(segments[1]));
      }
    }
    if (RegExp(r'^/pos/[^/]+$').hasMatch(path)) {
      return () => _goBack(AppRoutes.posHub);
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
