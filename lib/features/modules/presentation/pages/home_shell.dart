import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/layout/app_destination.dart';
import '../../../../core/layout/app_shell.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_accent.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/usecases/sign_out_usecase.dart';
import '../../../hrms/presentation/bloc/employees/employees_bloc.dart';
import '../../../pos/presentation/widgets/cafe_pos_chrome.dart';
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
  late final EmployeesBloc _employeesBloc = sl<EmployeesBloc>()
    ..add(const EmployeesRequested());
  ClientsBloc? _clientsBloc;
  bool _loggingOut = false;

  bool get _isStaff => AppAccess.isStaff(widget.user);

  bool get _isCafeRole => AppAccess.isCafeRole(widget.user);

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
            AppNavItem(label: 'All Employees', icon: Icons.people_outline),
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
            AppNavItem(label: 'Payroll', icon: Icons.payments_outlined),
            AppNavItem(
              label: 'Profitability',
              icon: Icons.trending_up_outlined,
            ),
            AppNavItem(label: 'Proposals', icon: Icons.request_quote_outlined),
            AppNavItem(label: 'Invoices', icon: Icons.receipt_long_outlined),
            AppNavItem(
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

    if (_isCafeRole) {
      return const [
        AppNavSection(
          label: 'POS',
          icon: Icons.storefront_outlined,
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
        AppRoutes.profitability,
        AppRoutes.proposals,
        AppRoutes.invoices,
        AppRoutes.expenses,
        AppRoutes.pos,
        AppRoutes.settings,
      ];
    }

    if (_isCafeRole) {
      return const [AppRoutes.pos];
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

    if (_isCafeRole) {
      return 0;
    }

    if (!_isStaff) {
      if (location.startsWith(AppRoutes.expenses)) return 3;
      if (location.contains('/compensation')) return 2;
      if (location.contains('section=slips')) return 1;
      return 0;
    }

    if (location.startsWith(AppRoutes.settings)) return 10;
    if (location.startsWith(AppRoutes.pos)) return 9;
    if (location.startsWith(AppRoutes.expenses)) return 8;
    if (location.startsWith(AppRoutes.invoices)) return 7;
    if (location.startsWith(AppRoutes.proposals)) return 6;
    if (location.startsWith(AppRoutes.profitability)) return 5;
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
    if (path == AppRoutes.manageInvites) return 'Manage invites';
    if (path == AppRoutes.companyDetails) return 'Company Details';
    if (path == AppRoutes.roles) return 'Roles';
    if (path == AppRoutes.ledger) return 'Activity ledger';
    if (path == AppRoutes.theme) return 'Theme';
    if (path == AppRoutes.categories) return 'Categories';
    if (path == AppRoutes.settings) return 'Settings';
    // Cafe POS: no chrome title — page headers live in the body; brand is the tab title.
    if (path.startsWith(AppRoutes.pos)) return '';
    if (path.startsWith(AppRoutes.expenses)) return 'Expense';
    if (path.startsWith(AppRoutes.invoices)) return 'Invoices';
    if (path.startsWith(AppRoutes.proposals)) return 'Proposals';
    if (path.endsWith('/projections') && path.startsWith('/profitability/')) {
      return 'Projections';
    }
    if (RegExp(r'^/profitability/[^/]+$').hasMatch(path)) {
      return 'Client profitability';
    }
    if (path.startsWith(AppRoutes.profitability)) return 'Profitability';
    if (path.startsWith(AppRoutes.payroll)) return 'Payroll';
    if (path.startsWith(AppRoutes.dms)) return 'DMS';
    if (path == AppRoutes.employees) return 'All employees';
    return 'HRMS';
  }

  VoidCallback? get _onBack {
    final location = widget.location;
    final path = Uri.tryParse(location)?.path ?? location;

    VoidCallback confirming(VoidCallback leave) {
      return () {
        leaveFormIfConfirmed(context, leave);
      };
    }

    if (_isCafeRole) {
      final clientId = AppAccess.cafeIdOf(widget.user);
      if (clientId == null) return null;
      final cafeHome = AppRoutes.posCafe(clientId);
      if (path == cafeHome) return null;
      if (path.startsWith('${AppRoutes.pos}/$clientId/')) {
        void leave() => _posBack(path, clientId);
        if (path.endsWith('/menu/add') ||
            (path.contains('/menu/') && path.endsWith('/edit'))) {
          return confirming(leave);
        }
        return leave;
      }
      return null;
    }

    if (!_isStaff) {
      if (path.endsWith('/compensation')) {
        return () => _goBack(AppRoutes.dashboard);
      }
      return null;
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
        path == AppRoutes.ledger ||
        path == AppRoutes.theme ||
        path == AppRoutes.categories ||
        path == AppRoutes.manageInvites) {
      return () => _goBack(AppRoutes.settings);
    }
    if (path == AppRoutes.inviteEmployee) {
      return confirming(() => _goBack(AppRoutes.settings));
    }
    if (path.endsWith('/projections') && path.startsWith('/profitability/')) {
      final segments = Uri.parse(path).pathSegments;
      if (segments.length >= 2) {
        return () => _goBack(AppRoutes.profitabilityClient(segments[1]));
      }
    }
    if (RegExp(r'^/profitability/[^/]+$').hasMatch(path)) {
      return () => _goBack(AppRoutes.profitability);
    }
    if (path.startsWith('${AppRoutes.pos}/')) {
      final segments = Uri.parse(path).pathSegments;
      // pathSegments: ['pos', cafeId, ...]
      if (segments.length >= 2) {
        final cafeId = segments[1];
        if (segments.length == 2) {
          return () => _goBack(AppRoutes.pos);
        }
        void leave() => _posBack(path, cafeId);
        if (path.endsWith('/menu/add') ||
            (path.contains('/menu/') && path.endsWith('/edit'))) {
          return confirming(leave);
        }
        return leave;
      }
    }
    if (path == AppRoutes.pos) return null;
    return null;
  }

  /// Nested POS screens: pop when possible, else go to the logical parent.
  void _posBack(String path, String cafeId) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (path.endsWith('/settings/coupons') ||
        path.endsWith('/settings/tax') ||
        path.endsWith('/settings/floor') ||
        path.endsWith('/settings/qr')) {
      context.go(AppRoutes.posSettings(cafeId));
      return;
    }
    if (path.endsWith('/menu/add') ||
        (path.contains('/menu/') && path.endsWith('/edit'))) {
      context.go(AppRoutes.posMenu(cafeId));
      return;
    }
    if (path.endsWith('/menu/categories')) {
      context.go(AppRoutes.posCafe(cafeId));
      return;
    }
    context.go(AppRoutes.posCafe(cafeId));
  }

  void _goBack(String fallback) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallback);
    }
  }

  void _selectDestination(int index) {
    if (_isCafeRole) {
      final home = AppAccess.homeRoute(widget.user);
      if (home != widget.location) {
        context.go(home);
      }
      return;
    }
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

  List<Widget>? get _shellActions {
    final path = Uri.tryParse(widget.location)?.path ?? widget.location;
    if (path.contains('/terminal')) {
      return [
        IconButton(
          tooltip: 'Clear all tables',
          onPressed: CafePosTerminalChrome.requestClearTables,
          icon: const Icon(Icons.delete_outline_rounded, size: 22),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: CafePosTerminalChrome.requestNewTable,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New table'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.text,
              minimumSize: const Size(48, 44),
            ),
          ),
        ),
      ];
    }
    if (path.contains('/orders') || path.contains('/reports')) {
      return [
        IconButton(
          tooltip: 'Refresh',
          onPressed: CafePosListChrome.requestRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 22),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            tooltip: 'Delete all',
            onPressed: CafePosListChrome.requestDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
          ),
        ),
      ];
    }
    if (path.contains('/kitchen')) {
      return [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            tooltip: 'Refresh',
            onPressed: CafePosListChrome.requestRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 22),
          ),
        ),
      ];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppAccent.of(context);
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
        actions: _shellActions,
        body: KeyedSubtree(
          key: ValueKey<int>(accent.color.toARGB32()),
          child: widget.child,
        ),
      ),
    );
  }
}
