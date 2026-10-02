import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/set_password_page.dart';
import '../../features/dms/presentation/pages/dms_page.dart';
import '../../features/hrms/domain/entities/employee.dart';
import '../../features/hrms/presentation/bloc/employees/employees_bloc.dart';
import '../../features/hrms/presentation/pages/add_employee_page.dart';
import '../../features/hrms/presentation/pages/compensation_breakup_page.dart';
import '../../features/hrms/presentation/pages/employee_detail_page.dart';
import '../../features/hrms/presentation/pages/employees_page.dart';
import '../../features/hrms/presentation/pages/hrms_overview_page.dart';
import '../../features/modules/presentation/pages/home_shell.dart';
import '../../features/expenses/presentation/pages/expenses_page.dart';
import '../../features/invoices/presentation/pages/invoices_page.dart';
import '../../features/payroll/presentation/pages/payroll_page.dart';
import '../../features/proposals/presentation/pages/proposals_page.dart';
import '../../features/settings/presentation/pages/add_clients_page.dart';
import '../../features/settings/presentation/pages/company_details_page.dart';
import '../../features/settings/presentation/pages/invite_employee_page.dart';
import '../../features/settings/presentation/pages/ledger_page.dart';
import '../../features/settings/presentation/pages/manage_clients_page.dart';
import '../../features/settings/presentation/pages/roles_page.dart';
import '../../features/settings/presentation/pages/settings_hub_page.dart';
import '../auth/auth_session.dart';
import '../theme/app_colors.dart';
import 'app_routes.dart';

void _goBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Instant route swap — no fade/slide (avoids perceived navigation lag).
Page<void> _page(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: child,
  );
}

GoRouter createAppRouter(AuthSession authSession) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authSession,
    redirect: (context, state) {
      final loggedIn = authSession.isAuthenticated;
      final loggingIn = state.matchedLocation == AppRoutes.login;
      final settingPassword = state.matchedLocation == AppRoutes.setPassword;
      final atRoot = state.matchedLocation == AppRoutes.root;

      if (!loggedIn && !loggingIn && !settingPassword) return AppRoutes.login;
      if (loggedIn && (loggingIn || atRoot)) return AppRoutes.hrms;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _page(state, const LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.setPassword,
        pageBuilder: (context, state) =>
            _page(state, const SetPasswordPage()),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final user = authSession.user;
          if (user == null) {
            return const SizedBox.shrink();
          }
          return HomeShell(
            user: user,
            location: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.hrms,
            pageBuilder: (context, state) =>
                _page(state, const HrmsOverviewPage()),
          ),
          GoRoute(
            path: AppRoutes.employees,
            pageBuilder: (context, state) {
              final user = authSession.user!;
              return _page(
                state,
                EmployeesPage(
                  user: user,
                  embedded: true,
                  onEmployeeSelected: (employee) {
                    context.go(AppRoutes.employeeDetail(employee.employeeId));
                  },
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.employeesAdd,
            pageBuilder: (context, state) => _page(
              state,
              AddEmployeePage(
                embedded: true,
                onCompleted: () {
                  context.read<EmployeesBloc>().add(const EmployeesRequested());
                  context.go(AppRoutes.employees);
                },
                onCancel: () => _goBack(context, AppRoutes.employees),
              ),
            ),
          ),
          GoRoute(
            path: '/hrms/employees/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return _page(
                state,
                _EmployeeRoutePage(
                  employeeId: id,
                  builder: (employee) => EmployeeDetailPage(
                    employee: employee,
                    embedded: true,
                    onBack: () => _goBack(context, AppRoutes.employees),
                    onEdit: () => context.go(AppRoutes.employeeEdit(id)),
                  ),
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'edit',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _page(
                    state,
                    _EmployeeRoutePage(
                      employeeId: id,
                      builder: (employee) => AddEmployeePage(
                        embedded: true,
                        employee: employee,
                        onCompleted: () {
                          context
                              .read<EmployeesBloc>()
                              .add(const EmployeesRequested());
                          context.go(AppRoutes.employeeDetail(id));
                        },
                        onCancel: () =>
                            _goBack(context, AppRoutes.employeeDetail(id)),
                      ),
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'compensation',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _page(
                    state,
                    _EmployeeRoutePage(
                      employeeId: id,
                      builder: (employee) => CompensationBreakupPage(
                        employee: employee,
                        embedded: true,
                        onBack: () =>
                            _goBack(context, AppRoutes.employeeDetail(id)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.dms,
            pageBuilder: (context, state) => _page(state, const DmsPage()),
          ),
          GoRoute(
            path: AppRoutes.payroll,
            pageBuilder: (context, state) => _page(state, const PayrollPage()),
          ),
          GoRoute(
            path: AppRoutes.proposals,
            pageBuilder: (context, state) =>
                _page(state, const ProposalsPage()),
          ),
          GoRoute(
            path: AppRoutes.invoices,
            pageBuilder: (context, state) =>
                _page(state, const InvoicesPage()),
          ),
          GoRoute(
            path: AppRoutes.expenses,
            pageBuilder: (context, state) =>
                _page(state, const ExpensesPage()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) =>
                _page(state, const SettingsHubPage()),
            routes: [
              GoRoute(
                path: 'clients',
                pageBuilder: (context, state) => _page(
                  state,
                  ManageClientsPage(
                    embedded: true,
                    onBack: () => _goBack(context, AppRoutes.settings),
                    onAddClient: () => context.go(AppRoutes.clientsAdd),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'add',
                    pageBuilder: (context, state) => _page(
                      state,
                      AddClientsPage(
                        embedded: true,
                        onCompleted: () => context.go(AppRoutes.clients),
                        onCancel: () => _goBack(context, AppRoutes.clients),
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'company',
                pageBuilder: (context, state) => _page(
                  state,
                  CompanyDetailsPage(
                    onBack: () => _goBack(context, AppRoutes.settings),
                  ),
                ),
              ),
              GoRoute(
                path: 'roles',
                pageBuilder: (context, state) => _page(
                  state,
                  RolesPage(
                    onBack: () => _goBack(context, AppRoutes.settings),
                  ),
                ),
              ),
              GoRoute(
                path: 'ledger',
                pageBuilder: (context, state) => _page(
                  state,
                  LedgerPage(
                    onBack: () => _goBack(context, AppRoutes.settings),
                  ),
                ),
              ),
              GoRoute(
                path: 'invite',
                pageBuilder: (context, state) => _page(
                  state,
                  InviteEmployeePage(
                    onBack: () => _goBack(context, AppRoutes.settings),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _EmployeeRoutePage extends StatelessWidget {
  const _EmployeeRoutePage({
    required this.employeeId,
    required this.builder,
  });

  final String employeeId;
  final Widget Function(Employee employee) builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, state) {
        if (state.status == EmployeesStatus.loading ||
            state.status == EmployeesStatus.initial) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        Employee? match;
        for (final employee in state.employees) {
          if (employee.employeeId == employeeId) {
            match = employee;
            break;
          }
        }

        if (match == null) {
          return Center(
            child: Text(
              'Employee not found',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        return builder(match);
      },
    );
  }
}
