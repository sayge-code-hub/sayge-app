import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dms/presentation/pages/dms_page.dart';
import '../../features/hrms/domain/entities/employee.dart';
import '../../features/hrms/presentation/bloc/employees/employees_bloc.dart';
import '../../features/hrms/presentation/pages/add_employee_page.dart';
import '../../features/hrms/presentation/pages/compensation_breakup_page.dart';
import '../../features/hrms/presentation/pages/employee_detail_page.dart';
import '../../features/hrms/presentation/pages/employees_page.dart';
import '../../features/hrms/presentation/pages/hrms_overview_page.dart';
import '../../features/modules/presentation/pages/home_shell.dart';
import '../../features/payroll/presentation/pages/payroll_page.dart';
import '../../features/settings/presentation/pages/add_clients_page.dart';
import '../../features/settings/presentation/pages/manage_clients_page.dart';
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

GoRouter createAppRouter(AuthSession authSession) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authSession,
    redirect: (context, state) {
      final loggedIn = authSession.isAuthenticated;
      final loggingIn = state.matchedLocation == AppRoutes.login;
      final atRoot = state.matchedLocation == AppRoutes.root;

      if (!loggedIn && !loggingIn) return AppRoutes.login;
      if (loggedIn && (loggingIn || atRoot)) return AppRoutes.hrms;
      if (state.matchedLocation == AppRoutes.settings) {
        return AppRoutes.clients;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
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
            builder: (context, state) => const HrmsOverviewPage(),
          ),
          GoRoute(
            path: AppRoutes.employees,
            builder: (context, state) {
              final user = authSession.user!;
              return EmployeesPage(
                user: user,
                embedded: true,
                onEmployeeSelected: (employee) {
                  context.go(AppRoutes.employeeDetail(employee.employeeId));
                },
              );
            },
          ),
          GoRoute(
            path: AppRoutes.employeesAdd,
            builder: (context, state) => AddEmployeePage(
              embedded: true,
              onCompleted: () {
                context.read<EmployeesBloc>().add(const EmployeesRequested());
                context.go(AppRoutes.employees);
              },
              onCancel: () => _goBack(context, AppRoutes.employees),
            ),
          ),
          GoRoute(
            path: '/hrms/employees/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return _EmployeeRoutePage(
                employeeId: id,
                builder: (employee) => EmployeeDetailPage(
                  employee: employee,
                  embedded: true,
                  onBack: () => _goBack(context, AppRoutes.employees),
                  onEdit: () => context.go(AppRoutes.employeeEdit(id)),
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _EmployeeRoutePage(
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
                  );
                },
              ),
              GoRoute(
                path: 'compensation',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _EmployeeRoutePage(
                    employeeId: id,
                    builder: (employee) => CompensationBreakupPage(
                      employee: employee,
                      embedded: true,
                      onBack: () =>
                          _goBack(context, AppRoutes.employeeDetail(id)),
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.dms,
            builder: (context, state) => const DmsPage(),
          ),
          GoRoute(
            path: AppRoutes.payroll,
            builder: (context, state) => const PayrollPage(),
          ),
          GoRoute(
            path: AppRoutes.clients,
            builder: (context, state) => ManageClientsPage(
              embedded: true,
              onBack: () => _goBack(context, AppRoutes.hrms),
              onAddClient: () => context.go(AppRoutes.clientsAdd),
            ),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => AddClientsPage(
                  embedded: true,
                  onCompleted: () => context.go(AppRoutes.clients),
                  onCancel: () => _goBack(context, AppRoutes.clients),
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
